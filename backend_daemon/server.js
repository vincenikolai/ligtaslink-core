const http = require("http");
const crypto = require("crypto");
let ethers;
try { ethers = require("ethers"); } catch (_) { ethers = null; }

const port = Number(process.env.PORT || 8080);
const batches = new Map();
function sha(value) { return crypto.createHash("sha256").update(value).digest("hex"); }
function serialize(value) { return JSON.stringify(value, Object.keys(value).sort()); }
function merkleRoot(transactions) {
  if (!transactions.length) return sha("");
  let level = transactions.map((tx) => sha(serialize(tx)));
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i < level.length; i += 2) next.push(sha(level[i] + (level[i + 1] || level[i])));
    level = next;
  }
  return level[0];
}
async function readJson(req) {
  let body = "";
  for await (const chunk of req) { body += chunk; if (body.length > 5_000_000) throw new Error("payload too large"); }
  return body ? JSON.parse(body) : {};
}
function send(res, status, payload) {
  res.writeHead(status, {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"});
  res.end(JSON.stringify(payload));
}
const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") return send(res, 204, {});
  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    if (req.method === "GET" && url.pathname === "/health") return send(res, 200, { ok: true, batches: batches.size, ethers: Boolean(ethers) });
    if (req.method === "POST" && url.pathname === "/api/sync-batch") {
      const input = await readJson(req);
      if (!Array.isArray(input.rawTransactions) || !input.rawTransactions.length || !input.offlineRoot || !input.workerId)
        return send(res, 400, { error: "rawTransactions, offlineRoot, and workerId are required" });
      const recomputedRoot = merkleRoot(input.rawTransactions);
      const record = { rawTransactions: input.rawTransactions, offlineRoot: input.offlineRoot, recomputedRoot, signature: input.signature || null, workerId: input.workerId, verified: input.offlineRoot === recomputedRoot, syncedAt: new Date().toISOString() };
      const batchId = sha(`${input.workerId}:${input.offlineRoot}:${record.syncedAt}`);
      batches.set(batchId, { batchId, ...record });
      return send(res, 201, { batchId, ...record });
    }
    if (req.method === "GET" && url.pathname === "/api/sync-batch") return send(res, 200, [...batches.values()]);
    return send(res, 404, { error: "not found" });
  } catch (error) { return send(res, 400, { error: error.message }); }
});
if (require.main === module) server.listen(port, () => console.log(`LigtasLink daemon listening on ${port}`));
module.exports = { server, merkleRoot };
