# =================================================================================================
#     Reads to Reference Processing Workflow
# =================================================================================================
# This file coordinates the steps for mapping aDNA reads to a reference and downstream analyses.
# Each include statement brings in rules for a specific processing or analysis step.

# Prepare the reference for mapping (indexing, etc.)
include: "reads_to_reference/processing/prepare_reference_for_mapping.smk"

# Map ancient DNA reads to the reference
include: "reads_to_reference/processing/map_reads_to_reference.smk"

# Deduplicate mapped reads
include: "reads_to_reference/processing/deduplication.smk"

# Analyze DNA damage patterns and rescale BAM files
include: "reads_to_reference/processing/analyze_damage_and_rescale_bam.smk"

# Get the final BAM file
include: "reads_to_reference/processing/get_final_bam.smk"

# Optionally remove or extract unmapped reads after QC statistics are captured
include: "reads_to_reference/processing/filter_unmapped_reads.smk"

# Determine coverage depth and breadth statistics
include: "reads_to_reference/analytics/determine_coverage_depth_breadth.smk"

# Calculate additional mapping statistics using samtools
include: "reads_to_reference/analytics/analyze_bam_with_samtools_stats.smk"

# Calculate additional mapping statistics using Qualimap
include: "reads_to_reference/analytics/analyze_bam_with_qualimap.smk"

# Calculate additional mapping statistics using preseq
include: "reads_to_reference/analytics/analyze_bam_with_preseq_lc_extrap.smk"

# Prepare custom content for MultiQC reports
include: "reads_to_reference/analytics/create_multiqc_prepare_custom_data_breadth.smk"
include: "reads_to_reference/analytics/create_multiqc_prepare_custom_data_depth.smk"
include: "reads_to_reference/analytics/create_multiqc_prepare_custom_data_reads_processing.smk"
include: "reads_to_reference/analytics/create_multiqc_prepare_custom_folder_links.smk"

#create_multiqc_bam.smk
include: "reads_to_reference/analytics/create_multiqc_bam.smk"

# create_multiqc_reference.smk
include: "reads_to_reference/analytics/create_multiqc_reference.smk"

# Calculate endogenous reads
include: "reads_to_reference/analytics/determine_endogenous_reads.smk"

# Plot endogenous reads statistics
include: "reads_to_reference/plotting/plot_endogenous_reads.smk"

# Plot coverage breadth across the reference 
include: "reads_to_reference/plotting/plot_coverage_breadth.smk"

# Plot coverage depth across the reference
include: "reads_to_reference/plotting/plot_coverage_depth.smk"

# Plot raw and endogenous reads
include: "reads_to_reference/plotting/plot_raw_and_endogenous_reads.smk"
# =================================================================================================
# End of reads_to_reference_processing.smk
# =================================================================================================