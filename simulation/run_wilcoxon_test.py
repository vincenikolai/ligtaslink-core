"""Chapter 3 statistical validation for LigtasLink.

1. Latency: 1,000 scan iterations each for
     Baseline   - indexed QR lookup + SQLite INSERT (no Merkle tree)
     LigtasLink - indexed QR lookup + SQLite INSERT of log + frozen leaf
                  + recursive SHA-256 Merkle root update + Ed25519 signature of R_offline
   compared with the Wilcoxon rank-sum (Mann-Whitney U) test.
2. Tamper simulation: modifies, deletes or injects records in the offline SQLite
   ledger after R_offline was signed and checks that the daemon-side recomputation
   yields R_cloud != R_offline (Tamper Detection Rate), plus an untampered control.

The Merkle construction is byte-identical to backend_daemon/merkle.js and
mobile_app/lib/crypto/merkle_engine.dart (verified against test_vectors/).
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import random
import sqlite3
import statistics
import tempfile
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np
from scipy.stats import mannwhitneyu

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
except ImportError:  # pragma: no cover - reported in the output
    Ed25519PrivateKey = None

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
HOUSEHOLDS = REPO / "data_generator" / "barangay_33d_households.json"
VECTORS = REPO / "test_vectors" / "merkle_vectors.json"
RESULTS_DIR = ROOT / "results"
THRESHOLD_MS = 100.0
ALPHA = 0.05


# --------------------------------------------------------------------------- Merkle engine
def canonical_string(tx: dict) -> str:
    return f"{tx['transaction_id']}{tx['household_id']}{tx['items_received']}{tx['timestamp']}{tx['worker_id']}"


def leaf_hash(tx: dict) -> bytes:
    return hashlib.sha256(canonical_string(tx).encode("utf-8")).digest()


def root_from_leaves(leaves: list[bytes]) -> bytes:
    if not leaves:
        raise ValueError("Cannot build a Merkle tree from an empty batch")
    layer = leaves
    while len(layer) > 1:
        layer = [
            hashlib.sha256(layer[i] + (layer[i + 1] if i + 1 < len(layer) else layer[i])).digest()
            for i in range(0, len(layer), 2)
        ]
    return layer[0]


def merkle_root(transactions: list[dict]) -> bytes:
    return root_from_leaves([leaf_hash(tx) for tx in transactions])


def hex0x(b: bytes) -> str:
    return "0x" + b.hex()


def verify_vectors() -> int:
    vectors = json.loads(VECTORS.read_text(encoding="utf-8"))
    for case in vectors["cases"]:
        got = hex0x(merkle_root(case["transactions"]))
        if got != case["expectedRoot"]:
            raise AssertionError(f"Merkle vector mismatch for size {case['size']}: {got} != {case['expectedRoot']}")
    return len(vectors["cases"])


# --------------------------------------------------------------------------- SQLite ledger
SCHEMA = """
CREATE TABLE residents (
  household_id TEXT PRIMARY KEY, family_head_name TEXT NOT NULL, address_purok INTEGER NOT NULL,
  dependent_count INTEGER NOT NULL, vulnerability_flags TEXT NOT NULL, qr_token TEXT NOT NULL UNIQUE);
CREATE UNIQUE INDEX idx_residents_qr_token ON residents(qr_token);
CREATE TABLE distribution_logs (
  transaction_id TEXT PRIMARY KEY, household_id TEXT NOT NULL REFERENCES residents(household_id),
  items_received INTEGER NOT NULL, timestamp TEXT NOT NULL, worker_id TEXT NOT NULL,
  synced_status INTEGER NOT NULL DEFAULT 0);
CREATE INDEX idx_logs_household_time ON distribution_logs(household_id, timestamp);
CREATE TABLE merkle_leaves (
  seq INTEGER PRIMARY KEY AUTOINCREMENT, transaction_id TEXT NOT NULL UNIQUE,
  leaf_hash BLOB NOT NULL, state INTEGER NOT NULL DEFAULT 0);
"""


def open_ledger(path: Path, households: list[dict]) -> sqlite3.Connection:
    conn = sqlite3.connect(path, isolation_level=None)  # explicit transactions, like sqflite
    conn.executescript(SCHEMA)
    conn.execute("BEGIN")
    conn.executemany(
        "INSERT INTO residents VALUES (?, ?, ?, ?, ?, ?)",
        [(h["household_id"], h["family_head_name"], h["address_purok"], h["dependent_count"],
          json.dumps(h["vulnerability_flags"]), h["qr_token"]) for h in households],
    )
    conn.execute("COMMIT")
    return conn


def lookup(conn: sqlite3.Connection, token: str) -> tuple:
    row = conn.execute("SELECT household_id, dependent_count FROM residents WHERE qr_token = ?", (token,)).fetchone()
    if row is None:
        raise KeyError(token)
    return row


def make_tx(household_id: str, dependents: int, clock: datetime, worker_id: str) -> dict:
    return {
        "transaction_id": str(uuid.uuid4()),
        "household_id": household_id,
        "items_received": 1 + dependents // 4,
        "timestamp": clock.isoformat(timespec="microseconds").replace("+00:00", "Z"),
        "worker_id": worker_id,
    }


INSERT_LOG = "INSERT INTO distribution_logs VALUES (:transaction_id, :household_id, :items_received, :timestamp, :worker_id, 0)"


class BaselineApp:
    def __init__(self, conn: sqlite3.Connection, worker_id: str):
        self.conn, self.worker_id = conn, worker_id

    def scan(self, token: str, clock: datetime) -> None:
        household_id, dependents = lookup(self.conn, token)
        tx = make_tx(household_id, dependents, clock, self.worker_id)
        self.conn.execute("BEGIN")
        self.conn.execute(INSERT_LOG, tx)
        self.conn.execute("COMMIT")


class LigtasLinkApp:
    def __init__(self, conn: sqlite3.Connection, worker_id: str, private_key):
        self.conn, self.worker_id, self.key = conn, worker_id, private_key
        self.pending_leaves: list[bytes] = []
        self.offline_root: bytes | None = None
        self.signature: bytes | None = None

    def scan(self, token: str, clock: datetime) -> None:
        household_id, dependents = lookup(self.conn, token)
        tx = make_tx(household_id, dependents, clock, self.worker_id)
        leaf = leaf_hash(tx)
        self.conn.execute("BEGIN")
        self.conn.execute(INSERT_LOG, tx)
        self.conn.execute("INSERT INTO merkle_leaves (transaction_id, leaf_hash) VALUES (?, ?)", (tx["transaction_id"], leaf))
        self.conn.execute("COMMIT")
        self.pending_leaves.append(leaf)
        self.offline_root = root_from_leaves(self.pending_leaves)
        if self.key is not None:
            self.signature = self.key.sign(self.offline_root)

    def raw_batch(self) -> list[dict]:
        """What the device uploads (mirrors AppController.syncNow): raw rows for each
        pending leaf in leaf order, then any unsynced rows that have no leaf at all."""
        rows = self.conn.execute(
            """SELECT l.transaction_id, l.household_id, l.items_received, l.timestamp, l.worker_id
               FROM merkle_leaves m JOIN distribution_logs l ON l.transaction_id = m.transaction_id
               WHERE m.state = 0 ORDER BY m.seq"""
        ).fetchall()
        rows += self.conn.execute(
            """SELECT transaction_id, household_id, items_received, timestamp, worker_id
               FROM distribution_logs WHERE synced_status = 0
                 AND transaction_id NOT IN (SELECT transaction_id FROM merkle_leaves)
               ORDER BY rowid"""
        ).fetchall()
        keys = ("transaction_id", "household_id", "items_received", "timestamp", "worker_id")
        return [dict(zip(keys, r)) for r in rows]


# --------------------------------------------------------------------------- latency experiment
def run_latency(households: list[dict], iterations: int, seed: int, workdir: Path, private_key):
    rng = random.Random(seed)
    tokens = [h["qr_token"] for h in households]
    baseline = BaselineApp(open_ledger(workdir / "baseline.db", households), "W-01")
    ligtas = LigtasLinkApp(open_ledger(workdir / "ligtaslink.db", households), "W-01", private_key)
    clock = datetime(2026, 10, 3, 8, 0, tzinfo=timezone.utc)

    for _ in range(20):  # warm-up (page cache, statement cache), excluded from samples
        baseline.scan(rng.choice(tokens), clock)
    baseline.conn.execute("DELETE FROM distribution_logs")

    base_ms, ligtas_ms = [], []
    for i in range(iterations):
        clock += timedelta(seconds=rng.randint(5, 40))
        token = rng.choice(tokens)
        # Alternate execution order so drift (thermal, cache) affects both arms equally.
        order = [("b", baseline), ("l", ligtas)] if i % 2 == 0 else [("l", ligtas), ("b", baseline)]
        for tag, app in order:
            start = time.perf_counter_ns()
            app.scan(token, clock)
            elapsed = (time.perf_counter_ns() - start) / 1e6
            (base_ms if tag == "b" else ligtas_ms).append(elapsed)
    return base_ms, ligtas_ms, ligtas


def fmt_p(p: float) -> str:
    # Large-sample normal approximation underflows double precision for extreme U.
    return "< 1e-300 (underflow)" if p == 0.0 else f"{p:.3e}"


def describe(sample: list[float]) -> dict:
    arr = np.asarray(sample)
    return {
        "n": int(arr.size),
        "median_ms": float(np.median(arr)),
        "mean_ms": float(arr.mean()),
        "std_ms": float(arr.std(ddof=1)),
        "p95_ms": float(np.percentile(arr, 95)),
        "max_ms": float(arr.max()),
    }


# --------------------------------------------------------------------------- tamper experiment
TAMPER_FIELDS = ("items_received", "household_id", "timestamp", "worker_id")


def run_tamper(app: LigtasLinkApp, households: list[dict], trials: int, seed: int) -> dict:
    rng = random.Random(seed + 1)
    conn = app.conn
    offline_root = app.offline_root
    if app.key is not None:
        app.key.public_key().verify(app.signature, offline_root)  # signature over R_offline is valid

    control_root = merkle_root(app.raw_batch())
    control_ok = control_root == offline_root

    ids = [r[0] for r in conn.execute("SELECT transaction_id FROM merkle_leaves WHERE state = 0 ORDER BY seq")]
    other_households = [h["household_id"] for h in households]
    detected, by_kind = 0, {}
    example = None
    for trial in range(trials):
        kind = rng.choice(("modify", "modify", "modify", "delete", "inject"))
        target = rng.choice(ids)
        conn.execute("SAVEPOINT tamper")
        if kind == "modify":
            field = rng.choice(TAMPER_FIELDS)
            current = conn.execute(f"SELECT {field} FROM distribution_logs WHERE transaction_id = ?", (target,)).fetchone()[0]
            if field == "items_received":
                new = current + rng.randint(1, 5)
            elif field == "household_id":
                new = rng.choice([h for h in other_households if h != current])
            elif field == "timestamp":
                # Backdate the claim past the 72-hour window to enable a double claim.
                shifted = datetime.fromisoformat(current.replace("Z", "+00:00")) - timedelta(hours=73)
                new = shifted.isoformat(timespec="microseconds").replace("+00:00", "Z")
            else:
                new = "W-99"
            conn.execute(f"UPDATE distribution_logs SET {field} = ? WHERE transaction_id = ?", (new, target))
            label = f"modify:{field}"
        elif kind == "delete":
            conn.execute("DELETE FROM distribution_logs WHERE transaction_id = ?", (target,))
            label = "delete"
        else:
            # A forged claim inserted directly into SQLite, bypassing the app (so it has no leaf).
            # The device appends such orphan rows to the upload, so the daemon sees them.
            forged = make_tx(rng.choice(other_households), 4, datetime.now(timezone.utc), app.worker_id)
            conn.execute(INSERT_LOG, forged)
            label = "inject"

        cloud_root = merkle_root(app.raw_batch())
        hit = cloud_root != offline_root
        detected += hit
        stats = by_kind.setdefault(label, [0, 0])
        stats[0] += hit
        stats[1] += 1
        if example is None and kind == "modify":
            example = {"tamper": label, "transaction_id": target, "R_offline": hex0x(offline_root), "R_cloud": hex0x(cloud_root)}
        conn.execute("ROLLBACK TO tamper")
        conn.execute("RELEASE tamper")

    return {
        "batch_size": len(ids),
        "control_untampered_match": control_ok,
        "trials": trials,
        "detected": detected,
        "tdr_percent": 100.0 * detected / trials,
        "by_kind": {k: {"detected": v[0], "trials": v[1]} for k, v in sorted(by_kind.items())},
        "example": example,
    }


# --------------------------------------------------------------------------- main
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--iterations", type=int, default=1000)
    parser.add_argument("--tamper-trials", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=33)
    args = parser.parse_args()

    households = json.loads(HOUSEHOLDS.read_text(encoding="utf-8"))
    vector_count = verify_vectors()
    key = Ed25519PrivateKey.generate() if Ed25519PrivateKey else None

    with tempfile.TemporaryDirectory(prefix="ligtaslink-sim-") as tmp:
        base_ms, ligtas_ms, ligtas_app = run_latency(households, args.iterations, args.seed, Path(tmp), key)
        u_stat, p_two = mannwhitneyu(ligtas_ms, base_ms, alternative="two-sided")
        _, p_greater = mannwhitneyu(ligtas_ms, base_ms, alternative="greater")
        n1, n2 = len(ligtas_ms), len(base_ms)
        rank_biserial = 2 * u_stat / (n1 * n2) - 1
        tamper = run_tamper(ligtas_app, households, args.tamper_trials, args.seed)
        ligtas_app.conn.close()

    base, ligtas = describe(base_ms), describe(ligtas_ms)
    under = ligtas["median_ms"] < THRESHOLD_MS
    results = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "iterations": args.iterations,
        "seed": args.seed,
        "ed25519_signing_included": key is not None,
        "merkle_vectors_verified": vector_count,
        "baseline": base,
        "ligtaslink": ligtas,
        "overhead_median_ms": ligtas["median_ms"] - base["median_ms"],
        "mann_whitney": {"U": float(u_stat), "p_two_sided": float(p_two), "p_one_sided_greater": float(p_greater),
                          "rank_biserial": rank_biserial, "alpha": ALPHA},
        "threshold_ms": THRESHOLD_MS,
        "median_below_threshold": under,
        "p95_below_threshold": ligtas["p95_ms"] < THRESHOLD_MS,
        "tamper": tamper,
    }

    RESULTS_DIR.mkdir(exist_ok=True)
    (RESULTS_DIR / "wilcoxon_results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    with (RESULTS_DIR / "latency_samples.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["iteration", "baseline_ms", "ligtaslink_ms"])
        for i, (b, l) in enumerate(zip(base_ms, ligtas_ms), start=1):
            writer.writerow([i, f"{b:.6f}", f"{l:.6f}"])

    line = "=" * 72
    print(line)
    print("LigtasLink Chapter 3 Validation - Barangay 33-D, Davao City")
    print(line)
    print(f"Merkle cross-implementation vectors verified: {vector_count}")
    print(f"Ed25519 signing in LigtasLink arm: {'yes' if key else 'NO (pip install cryptography)'}")
    print(f"Iterations per arm: {args.iterations}   (final Merkle batch: {tamper['batch_size']} leaves)")
    print()
    print(f"{'':24}{'Baseline':>14}{'LigtasLink':>14}")
    for label, k in (("Median (ms)", "median_ms"), ("Mean (ms)", "mean_ms"), ("Std dev (ms)", "std_ms"),
                     ("95th percentile (ms)", "p95_ms"), ("Max (ms)", "max_ms")):
        print(f"{label:24}{base[k]:>14.4f}{ligtas[k]:>14.4f}")
    print(f"{'Median overhead (ms)':24}{'':>14}{results['overhead_median_ms']:>14.4f}")
    print()
    print("Wilcoxon rank-sum / Mann-Whitney U (LigtasLink vs Baseline)")
    print(f"  U = {u_stat:.1f}")
    print(f"  p (two-sided)        = {fmt_p(p_two)}")
    print(f"  p (one-sided, L > B) = {fmt_p(p_greater)}")
    print(f"  rank-biserial r      = {rank_biserial:.3f}")
    verdict = ("statistically significant difference" if p_two < ALPHA else "no statistically significant difference")
    print(f"  -> {verdict} at alpha = {ALPHA}")
    print()
    print(f"Median LigtasLink latency {ligtas['median_ms']:.4f} ms < {THRESHOLD_MS:.0f} ms: {'PASS' if under else 'FAIL'}")
    print(f"95th percentile {ligtas['p95_ms']:.4f} ms < {THRESHOLD_MS:.0f} ms: {'PASS' if results['p95_below_threshold'] else 'FAIL'}")
    print()
    print("Tamper simulation (offline SQLite edits after R_offline was signed)")
    print(f"  Untampered control: R_cloud == R_offline -> {'PASS' if tamper['control_untampered_match'] else 'FAIL'}")
    for kind, s in tamper["by_kind"].items():
        print(f"  {kind:24} {s['detected']:>5} / {s['trials']:<5} detected")
    print(f"  Tamper Detection Rate: {tamper['detected']} / {tamper['trials']} = {tamper['tdr_percent']:.2f}%")
    if tamper["example"]:
        ex = tamper["example"]
        print(f"  Example ({ex['tamper']}): R_offline {ex['R_offline'][:18]}... vs R_cloud {ex['R_cloud'][:18]}...")
    print()
    print(f"Results written to {RESULTS_DIR / 'wilcoxon_results.json'} and latency_samples.csv")


if __name__ == "__main__":
    main()
