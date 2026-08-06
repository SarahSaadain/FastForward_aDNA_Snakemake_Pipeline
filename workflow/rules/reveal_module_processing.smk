# =================================================================================================
#     REVEAL Processing Workflow
# =================================================================================================
# This file coordinates the REVEAL feature-library and SCG-selector pipeline stage.
# Each include statement brings in rules for one section of pipeline.reveal_module in the config.

# scg_selector: automatic single-copy gene determination via BUSCO
include: "reveal_module/scg_selector/identify_scg_with_busco.smk"
include: "reveal_module/scg_selector/map_reads_to_scg_library.smk"
include: "reveal_module/scg_selector/rank_scg.smk"

# mapping: build the SCG + feature library and map reads to it
include: "reveal_module/mapping/prepare_libraries.smk"
include: "reveal_module/mapping/map_reads_to_library.smk"

# sequence_overview: convert mapped BAM into per-position coverage/SNP/indel calls
include: "reveal_module/sequence_overview.smk"

# normalization: normalise sequence overview coverage against SCG depth
include: "reveal_module/normalization.smk"

# visualization: plotable generation and plot rendering
include: "reveal_module/visualization.smk"

# analysis: per-individual and species-level stats, comparisons, and plots
include: "reveal_module/analysis.smk"
# =================================================================================================
# End of reveal_module_processing.smk
# =================================================================================================
