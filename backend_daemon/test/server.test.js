const test = require("node:test");
const assert = require("node:assert");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { createApp, WorkerRegistry, Ledger } = require("../server");
const { merkleRootHex } = require("../merkle");
const vectors = require("../../test_vectors/merkle_vectors.json");

// In-memory stand-in that mirrors LigtasLinkAudit.anchorBatchState semantics.
class FakeChain {
  constructor() { this.anchors = new Set(); }
  async status() { return { connected: true, chainId: 31337, contract: "0xfake" }; }
  async anchor(claimed, recomputed) {
    if (claimed.toLowerCase() !== recomputed.toLowerCase()) return { outcome: "TAMPER_REJECTED", txHash: "0x1", blockNumber: 1 };
    if (this.anchors.has(claimed.toLowerCase())) return { outcome: "ALREADY_ANCHORED", txHash: null, blockNumber: null };
    this.anchors.add(claimed.toLowerCase());
    return { outcome: "ANCHORED", txHash: "0x2", blockNumber: 2, anchoredAt: new Date().toISOString() };
  }
}

function workerKeys() {
  const { publicKey, privateKey } = crypto.generateKeyPairSync("ed25519");
  const raw = publicKey.export({ format: "der", type: "spki" }).subarray(-32);
  return { publicKeyHex: `0x${raw.toString("hex")}`, sign: (rootHex) => `0x${crypto.sign(null, Buffer.from(rootHex.slice(2), "hex"), privateKey).toString("hex")}` };
}

async function withServer(fn) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "ligtas-"));
  const app = createApp({
    chain: new FakeChain(),
    cloud: { enabled: false, reason: "test" },
    registry: new WorkerRegistry(path.join(dir, "workers.json")),
    ledger: new Ledger(path.join(dir, "ledger.jsonl")),
  });
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = async (url, body) => {
    const res = await fetch(base + url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
    return { status: res.status, body: await res.json() };
  };
  try { await fn(post); } finally { server.close(); fs.rmSync(dir, { recursive: true, force: true }); }
}

test("merkle engine matches shared cross-implementation vectors", () => {
  for (const c of vectors.cases) assert.strictEqual(merkleRootHex(c.transactions), c.expectedRoot, `size ${c.size}`);
});

test("verified batch is anchored, replay is idempotent, tamper is rejected", async () => {
  await withServer(async (post) => {
    const keys = workerKeys();
    assert.strictEqual((await post("/api/workers/register", { workerId: "W-01", publicKey: keys.publicKeyHex })).status, 201);
    assert.strictEqual((await post("/api/workers/register", { workerId: "W-01", publicKey: workerKeys().publicKeyHex })).status, 409);

    const txs = vectors.cases.find((c) => c.size === 7).transactions;
    const offlineRoot = merkleRootHex(txs);
    const ok = await post("/api/sync-batch", { rawTransactions: txs, offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(ok.status, 200);
    assert.strictEqual(ok.body.status, "ANCHORED");
    assert.strictEqual(ok.body.verified, true);

    const replay = await post("/api/sync-batch", { rawTransactions: txs, offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(replay.body.status, "ALREADY_ANCHORED");
    assert.strictEqual(replay.body.synced, true);

    const tampered = txs.map((tx, i) => (i === 3 ? { ...tx, items_received: tx.items_received + 5 } : tx));
    const bad = await post("/api/sync-batch", { rawTransactions: tampered, offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(bad.status, 409);
    assert.strictEqual(bad.body.status, "TAMPER_REJECTED");
    assert.notStrictEqual(bad.body.recomputedRoot, offlineRoot);
  });
});

test("rejects forged signatures, unknown workers and malformed payloads", async () => {
  await withServer(async (post) => {
    const keys = workerKeys();
    const txs = vectors.cases.find((c) => c.size === 3).transactions;
    const offlineRoot = merkleRootHex(txs);
    const unknown = await post("/api/sync-batch", { rawTransactions: txs, offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(unknown.status, 403);

    await post("/api/workers/register", { workerId: "W-01", publicKey: keys.publicKeyHex });
    const forged = await post("/api/sync-batch", { rawTransactions: txs, offlineRoot, signature: workerKeys().sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(forged.status, 401);
    assert.strictEqual(forged.body.status, "SIGNATURE_INVALID");

    assert.strictEqual((await post("/api/sync-batch", { rawTransactions: [], offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" })).status, 400);
    assert.strictEqual((await post("/api/sync-batch", { rawTransactions: txs, offlineRoot: "0x1234", signature: keys.sign(offlineRoot), workerId: "W-01" })).status, 400);
    // A rewritten worker_id is part of the signed leaf, so it surfaces as a root mismatch.
    const wrongWorker = txs.map((tx) => ({ ...tx, worker_id: "W-99" }));
    const reassigned = await post("/api/sync-batch", { rawTransactions: wrongWorker, offlineRoot, signature: keys.sign(offlineRoot), workerId: "W-01" });
    assert.strictEqual(reassigned.body.status, "TAMPER_REJECTED");
  });
});
