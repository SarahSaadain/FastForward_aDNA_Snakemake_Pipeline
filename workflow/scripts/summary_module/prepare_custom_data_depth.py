import csv
from collections import Counter

input_csv = snakemake.input.csv
avg_output = snakemake.output.avg
max_output = snakemake.output.max

# Lists to store rounded depths
avg_depths = []
max_depths = []

# Read CSV
with open(input_csv, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        avg_depths.append(round(float(row["avg_depth"]), 2))
        max_depths.append(round(float(row["max_depth"]), 2))

# Count occurrences
avg_counts = Counter(avg_depths)
max_counts = Counter(max_depths)

# Write avg depth file (no trailing newline)
with open(avg_output, "w") as f:
    depths = sorted(avg_counts.keys())
    for i, depth in enumerate(depths):
        end_char = "\n" if i < len(depths) - 1 else ""
        f.write(f"{depth},{avg_counts[depth]}{end_char}")

# Write max depth file (no trailing newline)
with open(max_output, "w") as f:
    depths = sorted(max_counts.keys())
    for i, depth in enumerate(depths):
        end_char = "\n" if i < len(depths) - 1 else ""
        f.write(f"{depth},{max_counts[depth]}{end_char}")
