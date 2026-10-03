"""Generate synthetic household profiles for Barangay 33-D, Davao City.

Produces `barangay_33d_households.json` (500 households across Puroks 1-6) and,
by default, copies it into the Flutter app's asset folder so the mobile client
can seed its offline SQLite database on first launch.
"""
from __future__ import annotations

import argparse
import json
import math
import random
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DEFAULT_OUTPUT = ROOT / "barangay_33d_households.json"
DEFAULT_MOBILE_ASSET = ROOT.parent / "mobile_app" / "assets" / "barangay_33d_households.json"

PUROK_COUNT = 6
DEPENDENT_MEAN = 4.0

FIRST_NAMES_MALE = [
    "Jose", "Juan", "Pedro", "Antonio", "Ramon", "Rodrigo", "Eduardo", "Ernesto",
    "Romeo", "Rogelio", "Danilo", "Arnel", "Jerome", "Mark Anthony", "John Paul",
    "Christian", "Reynaldo", "Alfredo", "Marlon", "Jonathan", "Ricardo", "Noel",
    "Bienvenido", "Teodoro", "Crisanto", "Leonardo", "Rolando", "Efren", "Joel", "Nestor",
]
FIRST_NAMES_FEMALE = [
    "Maria", "Ana", "Rosario", "Luzviminda", "Teresita", "Josefina", "Erlinda",
    "Marites", "Gemma", "Jocelyn", "Maricel", "Rowena", "Lorna", "Divina", "Cristina",
    "Analyn", "Mary Grace", "Jennifer", "Lourdes", "Corazon", "Imelda", "Leticia",
    "Remedios", "Evangeline", "Milagros", "Precious", "Kristine", "Angelica", "Elena", "Norma",
]
MIDDLE_INITIALS = list("ABCDEFGHIJLMNOPRSTV")
SURNAMES = [
    "Dela Cruz", "Santos", "Reyes", "Garcia", "Mendoza", "Bautista", "Villanueva",
    "Ramos", "Aquino", "Castillo", "Fernandez", "Gonzales", "Lopez", "Flores",
    "Navarro", "Torres", "Domingo", "Mercado", "Pascual", "Salazar", "Cabrera",
    "Manalo", "Dimaculangan", "Macaraeg", "Tumampos", "Bacus", "Sarmiento",
    "Lumapas", "Sumagaysay", "Cagas", "Ocampo", "Alvarez", "Saavedra", "Basilio",
    "Abellana", "Cañete", "Lacson", "Magbanua", "Tolentino", "Yap",
]


def poisson(rng: random.Random, lam: float) -> int:
    """Knuth's algorithm; exact for small lambda such as the mean of 4."""
    threshold, product, k = math.exp(-lam), 1.0, 0
    while True:
        product *= rng.random()
        if product <= threshold:
            return k
        k += 1


def family_head_name(rng: random.Random) -> str:
    first = rng.choice(FIRST_NAMES_MALE if rng.random() < 0.55 else FIRST_NAMES_FEMALE)
    return f"{first} {rng.choice(MIDDLE_INITIALS)}. {rng.choice(SURNAMES)}"


def generate_households(count: int = 500, seed: int = 3333) -> list[dict]:
    rng = random.Random(seed)
    households = []
    for index in range(1, count + 1):
        purok = rng.randint(1, PUROK_COUNT)
        households.append({
            "household_id": f"b33d-hh-{index:03d}",
            "family_head_name": family_head_name(rng),
            "address_purok": purok,
            "dependent_count": poisson(rng, DEPENDENT_MEAN),
            "vulnerability_flags": {
                "is_pwd": rng.random() < 0.07,
                "is_senior": rng.random() < 0.18,
                "is_pregnant": rng.random() < 0.06,
            },
            "qr_token": f"TOKEN-B33D-P{purok}-{index:03d}",
        })
    return households


def summarize(households: list[dict]) -> str:
    per_purok = Counter(h["address_purok"] for h in households)
    dependents = [h["dependent_count"] for h in households]
    flags = Counter(k for h in households for k, v in h["vulnerability_flags"].items() if v)
    lines = [
        f"Households: {len(households)}",
        "Per purok: " + ", ".join(f"P{p}={per_purok[p]}" for p in range(1, PUROK_COUNT + 1)),
        f"Dependents: mean={sum(dependents) / len(dependents):.2f}, min={min(dependents)}, max={max(dependents)}",
        "Vulnerability: " + ", ".join(f"{k}={flags[k]}" for k in ("is_pwd", "is_senior", "is_pregnant")),
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-n", "--count", type=int, default=500)
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--seed", type=int, default=3333)
    parser.add_argument("--mobile-asset", type=Path, default=DEFAULT_MOBILE_ASSET,
                        help="Copy for the Flutter app's assets folder")
    parser.add_argument("--no-mobile-asset", action="store_true")
    args = parser.parse_args()
    if not 1 <= args.count <= 999:
        parser.error("count must be between 1 and 999 (household_id uses 3 digits)")

    households = generate_households(args.count, args.seed)
    payload = json.dumps(households, indent=2, ensure_ascii=False)
    targets = [args.output] + ([] if args.no_mobile_asset else [args.mobile_asset])
    for target in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(payload + "\n", encoding="utf-8")
        print(f"Wrote {len(households)} households to {target}")
    print(summarize(households))


if __name__ == "__main__":
    main()
