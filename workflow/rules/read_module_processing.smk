# =================================================================================================
#     Raw Reads Processing Workflow
# =================================================================================================
# This file orchestrates the main steps for processing raw sequencing reads in the pastForward pipeline.
# Each include statement brings in a specific rule or set of rules for a processing or analysis step.

# Prepare raw reads for processing
include: "raw_read/processing/prepare_raw_reads.smk"

# Remove sequencing adapters from raw reads
include: "raw_read/processing/adapter_removal.smk"

# Filter reads based on quality thresholds
include: "raw_read/processing/quality_filtering.smk"

# Merge reads by individual sample for downstream analysis
include: "raw_read/processing/merge_by_individual.smk"

# Generate statistics on processed reads
include: "raw_read/analytics/statistics/get_read_counts_statistics.smk"

# Perform FastQC quality checks on raw and processed reads
include: "raw_read/analytics/quality/fastqc_check.smk"

# Aggregate FastQC results using MultiQC
include: "raw_read/analytics/quality/multiqc_check.smk"

# Plot comparison of reads before and after processing
include: "raw_read/plotting/plot_read_counts.smk"

# Check for contamination using ECMSD
include: "raw_read/analytics/contamination/check_contamination_ecmsd.smk"

# Check for contamination using Centrifuge
include: "raw_read/analytics/contamination/check_contamination_centrifuge.smk"

# Check for contamination using Kraken
#include: "raw_read/analytics/contamination/check_contamination_kraken.smk"
# =================================================================================================
# End of raw_reads_processing.smk
# =================================================================================================
