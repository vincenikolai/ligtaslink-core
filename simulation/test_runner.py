"""Scenario A/B local tamper simulation with 1,000 latency trials."""
import hashlib, random, statistics, time

def root(values):
    level = [hashlib.sha256(v.encode()).hexdigest() for v in values]
    while len(level) > 1:
        level = [hashlib.sha256((level[i] + (level[i + 1] if i + 1 < len(level) else level[i])).encode()).hexdigest()
                 for i in range(0, len(level), 2)]
    return level[0] if level else hashlib.sha256(b"").hexdigest()

def rank_sum(sample_a, sample_b):
    combined = sorted([(v, 0) for v in sample_a] + [(v, 1) for v in sample_b])
    rank_b = sum(i + 1 for i, (_, group) in enumerate(combined) if group == 1)
    n1, n2 = len(sample_a), len(sample_b)
    u = rank_b - n2 * (n2 + 1) / 2
    return u

def main():
    records = [f"transaction-{i}" for i in range(32)]
    clean_latency, tampered_latency = [], []
    rng = random.Random(33)
    for _ in range(1000):
        started = time.perf_counter_ns(); baseline = root(records); clean_latency.append(time.perf_counter_ns() - started)
        altered = records.copy(); altered[rng.randrange(len(altered))] += "-tampered"
        started = time.perf_counter_ns(); rejected = root(altered) != baseline; tampered_latency.append(time.perf_counter_ns() - started)
        assert rejected
    u = rank_sum(clean_latency, tampered_latency)
    print(f"Scenario A/B passed: 1000 trials, U={u:.0f}, median_ns={statistics.median(clean_latency):.0f}")

if __name__ == "__main__":
    main()
