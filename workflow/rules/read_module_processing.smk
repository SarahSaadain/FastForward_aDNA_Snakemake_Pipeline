# =================================================================================================
#     Raw Reads Processing Workflow
# =================================================================================================
# This file orchestrates the main steps for processing raw sequencing reads in the pastForward pipeline.
# Each include statement brings in a specific rule or set of rules for a processing or analysis step.

# Prepare raw reads for processing
include: "read_module/processing/prepare_raw_reads.smk"

# Remove sequencing adapters from raw reads
include: "read_module/processing/adapter_removal.smk"

# Filter reads based on quality thresholds
include: "read_module/processing/quality_filtering.smk"

# Merge reads by individual sample for downstream analysis
include: "read_module/processing/merge_by_individual.smk"

# Generate statistics on processed reads
include: "read_module/analytics/statistics/get_read_counts_statistics.smk"

# Perform FastQC quality checks on raw and processed reads
include: "read_module/analytics/quality/fastqc_check.smk"

# Aggregate FastQC results using MultiQC
include: "read_module/analytics/quality/multiqc_check.smk"

# Plot comparison of reads before and after processing
include: "read_module/plotting/plot_read_counts.smk"

# Check for contamination using ECMSD
include: "read_module/analytics/contamination/check_contamination_ecmsd.smk"

# Check for contamination using Centrifuge
include: "read_module/analytics/contamination/check_contamination_centrifuge.smk"

# Check for contamination using Kraken
#include: "read_module/analytics/contamination/check_contamination_kraken.smk"
# =================================================================================================
# End of read_module_processing.smk
# =================================================================================================
