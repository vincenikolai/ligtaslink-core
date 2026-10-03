// Merkle engine shared by the Dual-Sync Daemon. Must stay byte-for-byte identical
// to mobile_app/lib/crypto/merkle_engine.dart and simulation/run_wilcoxon_test.py:
//   S      = transaction_id + household_id + items_received + timestamp + worker_id
//   leaf   = SHA-256(UTF-8(S))
//   parent = SHA-256(left || right)   (raw 32-byte digests; odd layer duplicates last)
const crypto = require("crypto");

const TX_FIELDS = ["transaction_id", "household_id", "items_received", "timestamp", "worker_id"];

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest();
}

function canonicalString(tx) {
  return `${tx.transaction_id}${tx.household_id}${tx.items_received}${tx.timestamp}${tx.worker_id}`;
}

function leafHash(tx) {
  return sha256(Buffer.from(canonicalString(tx), "utf8"));
}

function rootFromLeaves(leaves) {
  if (!leaves.length) throw new Error("Cannot build a Merkle tree from an empty batch");
  let layer = leaves;
  while (layer.length > 1) {
    const next = [];
    for (let i = 0; i < layer.length; i += 2) {
      const left = layer[i];
      const right = i + 1 < layer.length ? layer[i + 1] : layer[i];
      next.push(sha256(Buffer.concat([left, right])));
    }
    layer = next;
  }
  return layer[0];
}

function merkleRoot(transactions) {
  return rootFromLeaves(transactions.map(leafHash));
}

function merkleRootHex(transactions) {
  return `0x${merkleRoot(transactions).toString("hex")}`;
}

module.exports = { TX_FIELDS, canonicalString, leafHash, rootFromLeaves, merkleRoot, merkleRootHex };
