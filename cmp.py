import json

def flatten(d, prefix=''):
    """Recursively flatten a nested dictionary using dot notation."""
    items = {}
    for k, v in d.items():
        full_key = f'{prefix}.{k}' if prefix else k
        if isinstance(v, dict):
            items.update(flatten(v, full_key))
        else:
            items[full_key] = v
    return items

def format_float(x):
    return f'{x:.6f}' if isinstance(x, float) else str(x)

def compare(before, after):
    before_flat = flatten(before)
    after_flat = flatten(after)

    all_keys = sorted(set(before_flat) | set(after_flat))

    print("| Key | Before | After | Δ Abs | Δ % |")
    print("|-----|--------|-------|-------|------|")

    for key in all_keys:
        b = before_flat.get(key, 0)
        a = after_flat.get(key, 0)
        if isinstance(b, (int, float)) and isinstance(a, (int, float)):
            delta = a - b
            delta_pct = (delta / b * 100) if b != 0 else float('inf') if delta != 0 else 0
            print(f"| {key} | {format_float(b)} | {format_float(a)} | {format_float(delta)} | {format_float(delta_pct)}% |")

if __name__ == "__main__":
    with open("stats_before.json") as f:
        before = json.load(f)
    with open("stats_after.json") as f:
        after = json.load(f)
    compare(before, after)
