
# create_multiqc_species.smk
# Contains rules for generating MultiQC reports for each species.
include: "processing_summary/create_multiqc_species.smk"


# create_multiqc_species_individual.smk
# Contains rules for generating MultiQC reports for each species and individual.
include: "processing_summary/create_multiqc_species_individual.smk"

