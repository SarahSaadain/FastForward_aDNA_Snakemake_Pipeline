
# SCG selector rules
include: "reveal/scg/identify_scg_with_busco.smk"
include: "reveal/scg/map_reads_to_scg_library.smk"
include: "reveal/scg/rank_scg.smk"

# REVEAL / feature-library rules
include: "reveal/prepare_libraries.smk"
include: "reveal/map_reads_to_library.smk"
include: "reveal/visualization.smk"
include: "reveal/determine_normalization.smk"
