// LigtasLink Dual-Sync Daemon
// Bridges offline mobile batches to Firebase (raw logs) and the LigtasLinkAudit
// contract on a local Hardhat node (Merkle root anchoring / tamper rejection).
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const express = require("express");
const { ethers } = require("ethers");
const { TX_FIELDS, merkleRootHex } = require("./merkle");

const config = {
  port: Number(process.env.PORT || 8080),
  rpcUrl: process.env.RPC_URL || "http://127.0.0.1:8545",
  deploymentFile: process.env.DEPLOYMENT_FILE
    || path.join(__dirname, "..", "blockchain", "deployments", "localhost.json"),
  contractAddress: process.env.CONTRACT_ADDRESS || null,
  signerPrivateKey: process.env.SIGNER_PRIVATE_KEY || null,
  dataDir: process.env.DATA_DIR || path.join(__dirname, "data"),
  firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || null,
  maxBatchSize: Number(process.env.MAX_BATCH_SIZE || 5000),
};

const HEX32 = /^0x[0-9a-fA-F]{64}$/;
const HEX64 = /^0x[0-9a-fA-F]{128}$/;
const ED25519_SPKI_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

// ---------------------------------------------------------------------------
// Worker registry: trust-on-first-use Ed25519 public keys, persisted to disk.
// ---------------------------------------------------------------------------
class WorkerRegistry {
  constructor(file) {
    this.file = file;
    this.workers = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
  }

  get(workerId) {
    return this.workers[workerId] || null;
  }

  register(workerId, publicKey) {
    const existing = this.workers[workerId];
    if (existing && existing.publicKey.toLowerCase() !== publicKey.toLowerCase()) {
      return { ok: false, reason: "Worker ID is already bound to a different public key." };
    }
    if (!existing) {
      this.workers[workerId] = { publicKey: publicKey.toLowerCase(), registeredAt: new Date().toISOString() };
      fs.mkdirSync(path.dirname(this.file), { recursive: true });
      fs.writeFileSync(this.file, JSON.stringify(this.workers, null, 2));
    }
    return { ok: true, created: !existing };
  }
}

function verifyEd25519(publicKeyHex, messageBytes, signatureHex) {
  try {
    const key = crypto.createPublicKey({
      key: Buffer.concat([ED25519_SPKI_PREFIX, Buffer.from(publicKeyHex.slice(2), "hex")]),
      format: "der",
      type: "spki",
    });
    return crypto.verify(null, messageBytes, key, Buffer.from(signatureHex.slice(2), "hex"));
  } catch (_) {
    return false; // Malformed key material is treated as a failed verification.
  }
}

// ---------------------------------------------------------------------------
// Local ledger: append-only record of every sync attempt (feeds /api/batches).
// ---------------------------------------------------------------------------
class Ledger {
  constructor(file) {
    this.file = file;
    this.entries = fs.existsSync(file)
      ? fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line))
      : [];
  }

  append(entry) {
    this.entries.push(entry);
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.appendFileSync(this.file, `${JSON.stringify(entry)}\n`);
  }

  recent(limit = 50) {
    return this.entries.slice(-limit).reverse();
  }
}

// ---------------------------------------------------------------------------
// Hardhat / EVM anchoring.
// ---------------------------------------------------------------------------
class ChainAnchor {
  constructor({ rpcUrl, deploymentFile, contractAddress, signerPrivateKey }) {
    this.rpcUrl = rpcUrl;
    this.deploymentFile = deploymentFile;
    this.contractAddress = contractAddress;
    this.signerPrivateKey = signerPrivateKey;
    this.provider = new ethers.JsonRpcProvider(rpcUrl, undefined, { staticNetwork: true });
    this.contract = null;
    this.queue = Promise.resolve();
  }

  async connect() {
    if (this.contract) return this.contract;
    if (!fs.existsSync(this.deploymentFile)) {
      throw new Error(`Deployment manifest not found at ${this.deploymentFile}. Run "npm run deploy" in blockchain/.`);
    }
    const manifest = JSON.parse(fs.readFileSync(this.deploymentFile, "utf8"));
    const network = await this.provider.getNetwork();
    if (network.chainId !== 31337n) throw new Error(`Expected chainId 31337, RPC reports ${network.chainId}`);
    const address = this.contractAddress || manifest.address;
    if ((await this.provider.getCode(address)) === "0x") {
      throw new Error(`No contract code at ${address}. Redeploy after restarting the Hardhat node.`);
    }
    const signer = this.signerPrivateKey
      ? new ethers.Wallet(this.signerPrivateKey, this.provider)
      : await this.provider.getSigner(0);
    this.contract = new ethers.Contract(address, manifest.abi, signer);
    return this.contract;
  }

  async status() {
    try {
      const contract = await this.connect();
      return { connected: true, chainId: 31337, contract: await contract.getAddress() };
    } catch (error) {
      this.contract = null;
      return { connected: false, error: error.message };
    }
  }

  // Serialises transactions so concurrent requests never race on the signer nonce.
  anchor(offlineRoot, recomputedRoot, workerId, batchSize) {
    const run = this.queue.then(() => this.#anchor(offlineRoot, recomputedRoot, workerId, batchSize));
    this.queue = run.catch(() => {});
    return run;
  }

  async #anchor(offlineRoot, recomputedRoot, workerId, batchSize) {
    let contract;
    try {
      contract = await this.connect();
    } catch (error) {
      this.contract = null;
      throw error;
    }
    if (offlineRoot.toLowerCase() === recomputedRoot.toLowerCase()) {
      const existing = await contract.anchors(offlineRoot);
      if (existing.exists) {
        return {
          outcome: "ALREADY_ANCHORED",
          txHash: null,
          blockNumber: null,
          anchoredAt: new Date(Number(existing.timestamp) * 1000).toISOString(),
        };
      }
    }
    const tx = await contract.anchorBatchState(offlineRoot, recomputedRoot, workerId, batchSize);
    const receipt = await tx.wait();
    for (const log of receipt.logs) {
      let parsed;
      try { parsed = contract.interface.parseLog(log); } catch (_) { continue; }
      if (parsed?.name === "BatchAnchored") {
        return {
          outcome: "ANCHORED",
          txHash: receipt.hash,
          blockNumber: receipt.blockNumber,
          anchoredAt: new Date(Number(parsed.args.timestamp) * 1000).toISOString(),
        };
      }
      if (parsed?.name === "TamperRejected") {
        return { outcome: "TAMPER_REJECTED", txHash: receipt.hash, blockNumber: receipt.blockNumber, reason: parsed.args.reason };
      }
    }
    throw new Error(`Transaction ${receipt.hash} emitted neither BatchAnchored nor TamperRejected`);
  }
}

// ---------------------------------------------------------------------------
// Firebase (Firestore) writer. Disabled unless a service account is supplied.
// ---------------------------------------------------------------------------
class CloudStore {
  constructor(serviceAccountPath) {
    this.enabled = false;
    this.reason = "FIREBASE_SERVICE_ACCOUNT / GOOGLE_APPLICATION_CREDENTIALS not set";
    const credentialPath = serviceAccountPath || process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!credentialPath) return;
    const admin = require("firebase-admin");
    const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, "utf8"));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    this.db = admin.firestore();
    this.FieldValue = admin.firestore.FieldValue;
    this.enabled = true;
    this.reason = null;
  }

  // Idempotent: documents are keyed by Merkle root and transaction_id.
  async writeVerifiedBatch({ root, workerId, rawTransactions, signature, chain }) {
    const batchRef = this.db.collection("sync_batches").doc(root);
    const chunks = [];
    for (let i = 0; i < rawTransactions.length; i += 450) chunks.push(rawTransactions.slice(i, i + 450));
    for (const chunk of chunks) {
      const writer = this.db.batch();
      for (const tx of chunk) {
        writer.set(this.db.collection("distribution_logs").doc(tx.transaction_id), {
          ...tx,
          synced_status: 1,
          merkle_root: root,
          cloud_received_at: this.FieldValue.serverTimestamp(),
        });
      }
      await writer.commit();
    }
    await batchRef.set({
      merkle_root: root,
      worker_id: workerId,
      batch_size: rawTransactions.length,
      signature,
      verified: true,
      chain_tx_hash: chain.txHash,
      chain_block_number: chain.blockNumber,
      anchored_at: chain.anchoredAt,
      transaction_ids: rawTransactions.map((tx) => tx.transaction_id),
      synced_at: this.FieldValue.serverTimestamp(),
    });
  }
}

// ---------------------------------------------------------------------------
// Request validation.
// ---------------------------------------------------------------------------
function validateBatch(body, maxBatchSize) {
  const { rawTransactions, offlineRoot, signature, workerId } = body || {};
  if (typeof workerId !== "string" || !workerId.trim()) return "workerId is required.";
  if (typeof offlineRoot !== "string" || !HEX32.test(offlineRoot)) return "offlineRoot must be a 0x-prefixed 32-byte hex string.";
  if (typeof signature !== "string" || !HEX64.test(signature)) return "signature must be a 0x-prefixed 64-byte Ed25519 signature.";
  if (!Array.isArray(rawTransactions) || rawTransactions.length === 0) return "rawTransactions must be a non-empty array.";
  if (rawTransactions.length > maxBatchSize) return `rawTransactions exceeds the ${maxBatchSize}-record limit.`;
  const seen = new Set();
  for (const [i, tx] of rawTransactions.entries()) {
    for (const field of TX_FIELDS) {
      if (tx?.[field] === undefined || tx[field] === null) return `rawTransactions[${i}].${field} is missing.`;
    }
    if (!Number.isInteger(tx.items_received) || tx.items_received < 0) return `rawTransactions[${i}].items_received must be a non-negative integer.`;
    if (seen.has(tx.transaction_id)) return `Duplicate transaction_id ${tx.transaction_id}.`;
    seen.add(tx.transaction_id);
  }
  return null;
}

function pickTransaction(tx) {
  return Object.fromEntries(TX_FIELDS.map((field) => [field, tx[field]]));
}

// ---------------------------------------------------------------------------
// HTTP API.
// ---------------------------------------------------------------------------
function createApp({ chain, cloud, registry, ledger, maxBatchSize = config.maxBatchSize }) {
  const app = express();
  app.use(express.json({ limit: "5mb" }));
  app.use((req, res, next) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(204);
    return next();
  });

  app.get("/health", async (req, res) => {
    res.json({
      ok: true,
      service: "ligtaslink-dual-sync-daemon",
      chain: await chain.status(),
      firebase: { enabled: cloud.enabled, reason: cloud.reason },
      batchesProcessed: ledger.entries.length,
    });
  });

  app.post("/api/workers/register", (req, res) => {
    const { workerId, publicKey } = req.body || {};
    if (typeof workerId !== "string" || !workerId.trim()) return res.status(400).json({ error: "workerId is required." });
    if (typeof publicKey !== "string" || !HEX32.test(publicKey)) return res.status(400).json({ error: "publicKey must be a 0x-prefixed 32-byte Ed25519 key." });
    const result = registry.register(workerId, publicKey);
    if (!result.ok) return res.status(409).json({ error: result.reason });
    return res.status(result.created ? 201 : 200).json({ workerId, registered: true });
  });

  app.get("/api/batches", (req, res) => {
    const limit = Math.min(Number(req.query.limit) || 50, 500);
    res.json(ledger.recent(limit));
  });

  app.post("/api/sync-batch", async (req, res) => {
    const error = validateBatch(req.body, maxBatchSize);
    if (error) return res.status(400).json({ error });

    const { offlineRoot, signature, workerId } = req.body;
    const rawTransactions = req.body.rawTransactions.map(pickTransaction);
    const batchSize = rawTransactions.length;
    const recomputedRoot = merkleRootHex(rawTransactions);
    const base = { workerId, batchSize, offlineRoot: offlineRoot.toLowerCase(), recomputedRoot, receivedAt: new Date().toISOString() };

    const worker = registry.get(workerId);
    if (!worker) return res.status(403).json({ ...base, status: "UNKNOWN_WORKER", verified: false, synced: false, error: "Worker public key is not registered." });

    if (!verifyEd25519(worker.publicKey, Buffer.from(offlineRoot.slice(2), "hex"), signature)) {
      const entry = { ...base, status: "SIGNATURE_INVALID", verified: false, synced: false };
      ledger.append(entry);
      return res.status(401).json({ ...entry, error: "Ed25519 signature does not match the registered worker key." });
    }

    let anchor;
    try {
      anchor = await chain.anchor(offlineRoot, recomputedRoot, workerId, batchSize);
    } catch (chainError) {
      return res.status(503).json({ ...base, status: "CHAIN_UNAVAILABLE", verified: false, synced: false, error: chainError.message });
    }

    if (anchor.outcome === "TAMPER_REJECTED") {
      const entry = { ...base, status: "TAMPER_REJECTED", verified: false, synced: false, chain: anchor,
        transactionIds: rawTransactions.map((tx) => tx.transaction_id) };
      ledger.append(entry);
      return res.status(409).json(entry);
    }

    let firebase = { written: false, reason: cloud.reason };
    if (cloud.enabled) {
      try {
        await cloud.writeVerifiedBatch({ root: base.offlineRoot, workerId, rawTransactions, signature, chain: anchor });
        firebase = { written: true };
      } catch (cloudError) {
        firebase = { written: false, reason: cloudError.message };
      }
    }
    // The device may mark logs synced once anchored and either written to Firebase
    // or Firebase is intentionally disabled. A failed write is retried idempotently.
    const synced = firebase.written || !cloud.enabled;
    const entry = { ...base, status: anchor.outcome, verified: true, synced, chain: anchor, firebase };
    ledger.append(entry);
    return res.status(synced ? 200 : 502).json(entry);
  });

  app.use((req, res) => res.status(404).json({ error: "Not found." }));
  app.use((err, req, res, next) => {
    if (err.type === "entity.parse.failed") return res.status(400).json({ error: "Malformed JSON body." });
    if (err.type === "entity.too.large") return res.status(413).json({ error: "Payload too large." });
    console.error(err);
    return res.status(500).json({ error: "Internal server error." });
  });
  return app;
}

function start() {
  const registry = new WorkerRegistry(path.join(config.dataDir, "workers.json"));
  const ledger = new Ledger(path.join(config.dataDir, "ledger.jsonl"));
  const chain = new ChainAnchor(config);
  const cloud = new CloudStore(config.firebaseServiceAccount);
  const app = createApp({ chain, cloud, registry, ledger });
  app.listen(config.port, async () => {
    console.log(`LigtasLink Dual-Sync Daemon listening on http://0.0.0.0:${config.port}`);
    const status = await chain.status();
    console.log(status.connected
      ? `Hardhat: connected, LigtasLinkAudit at ${status.contract}`
      : `Hardhat: NOT connected (${status.error})`);
    console.log(cloud.enabled ? "Firebase: enabled" : `Firebase: disabled (${cloud.reason})`);
  });
}

if (require.main === module) start();

module.exports = { createApp, validateBatch, verifyEd25519, WorkerRegistry, Ledger, ChainAnchor, CloudStore };
