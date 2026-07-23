import os
import math
import logging

input  = snakemake.input
output = snakemake.output
params = snakemake.params

logger.info("Starting contig clustering for deduplication...")

# Read contigs
with open(input.contigs) as f:
    contigs = [line.strip() for line in f if line.strip()]

number_of_contigs = len(contigs)
cores = params.get("cores", 1)

max_contigs_per_cluster = params.get("max_contigs_per_cluster", 500)
min_contigs_per_cluster = params.get("min_contigs_per_cluster", 1)

logger.info(f"Total contigs: {number_of_contigs}")
logger.info(f"Available cores: {cores}")
logger.info(f"Min contigs per cluster: {min_contigs_per_cluster}")
logger.info(f"Max contigs per cluster: {max_contigs_per_cluster}")

# Create output directory
logger.info(f"Creating output directory: {output.cluster_folder}")
os.makedirs(output.cluster_folder, exist_ok=True)

# ----------------------------
# Determine number of clusters
# ----------------------------

# Maximum clusters allowed by minimum contigs constraint
max_clusters_by_min = max(1, number_of_contigs // min_contigs_per_cluster)

# Minimum clusters required by maximum contigs constraint
min_clusters_by_max = math.ceil(number_of_contigs / max_contigs_per_cluster)

# Target clusters: use cores, but respect constraints
num_clusters = min(cores, max_clusters_by_min)
num_clusters = max(num_clusters, min_clusters_by_max)
num_clusters = min(num_clusters, number_of_contigs)  # safety

# Compute balanced cluster size
contigs_per_cluster = math.ceil(number_of_contigs / num_clusters)

logger.info(
    f"Clustering contigs into {num_clusters} clusters "
    f"(~{contigs_per_cluster} contigs per cluster)"
)

# ----------------------------
# Write cluster BED files
# ----------------------------

for i in range(num_clusters):
    start = i * contigs_per_cluster
    end = min((i + 1) * contigs_per_cluster, number_of_contigs)

    if start >= end:
        break

    group_contigs = contigs[start:end]

    # 1-based contig indexing in filename
    group_file = os.path.join(
        output.cluster_folder,
        f"cluster_{start + 1}_{end}.bed"
    )

    logger.info(
        f"Writing contig cluster file: {group_file} "
        f"with contigs {start + 1} to {end}"
    )

    with open(group_file, "w") as out:
        out.write("\n".join(group_contigs) + "\n")

logger.info("Contig clustering completed successfully.")
