import json
from pathlib import Path

# Snakemake-provided objects
input_files = snakemake.input
output = snakemake.output
wildcards = snakemake.wildcards

totals = {
    "total_reads": 0,
    "mapped_reads": 0,
    "merged_removed": 0,
    "forward_removed": 0,
    "reverse_removed": 0,
    "total_removed": 0,
}

for f in input_files:
    with open(f) as fh:
        data = json.load(fh)["metrics"]
    for k in totals:
        totals[k] += int(data[k])

# recompute derived metrics
dup_rate = (
    totals["total_removed"] / totals["mapped_reads"]
    if totals["mapped_reads"] > 0 else 0
)

clusterfactor = (
    totals["total_reads"] /
    (totals["total_reads"] - totals["total_removed"])
    if totals["total_reads"] > totals["total_removed"] else 0
)

merged = {
    "metadata": {
        "tool_name": "DeDup",
        "version": "0.12.9",
        "sample_name": f"{wildcards.individual}_{wildcards.reference}",
    },
    "metrics": {
        **totals,
        "dup_rate": f"{dup_rate:.4f}",
        "clusterfactor": f"{clusterfactor:.4f}",
    },
}

Path(output.json).parent.mkdir(parents=True, exist_ok=True)
with open(output.json, "w") as out:
    json.dump(merged, out, indent=2)
