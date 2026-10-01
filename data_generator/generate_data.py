"""Generate 500 synthetic Barangay 33-D household profiles."""
from __future__ import annotations
import argparse, json, random
from pathlib import Path

def generate_households(count: int = 500, seed: int = 2026) -> list[dict]:
    rng = random.Random(seed)
    result = []
    for number in range(1, count + 1):
        flags = {
            "pwd": rng.random() < 0.08,
            "senior": rng.random() < 0.15,
            "pregnant": rng.random() < 0.05,
        }
        result.append({
            "household_id": f"HH-{number:04d}",
            "family_head_name": f"Resident {number:04d}",
            "address_purok": rng.randint(1, 6),
            "dependent_count": max(0, rng.poisson(4) if hasattr(rng, "poisson") else _poisson(rng, 4)),
            "vulnerability_flags": flags,
            "qr_token": f"33D-{seed}-{number:04d}",
        })
    return result

def _poisson(rng: random.Random, lam: float) -> int:
    threshold, product, count = pow(2.718281828, -lam), 1.0, 0
    while product > threshold:
        count += 1
        product *= rng.random()
    return count - 1

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-n", "--count", type=int, default=500)
    parser.add_argument("-o", "--output", type=Path, default=Path("households.json"))
    parser.add_argument("--seed", type=int, default=2026)
    args = parser.parse_args()
    if args.count < 1:
        parser.error("count must be positive")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(generate_households(args.count, args.seed), indent=2), encoding="utf-8")
    print(f"Wrote {args.count} households to {args.output}")

if __name__ == "__main__":
    main()
