####################################################
# Python helper functions for rules
####################################################

def combine_normalizations_for_species_input_coverage_files(wildcards):
    species = wildcards.species
    feature_library = wildcards.feature_library

    individuals = get_individuals_for_species(species)

    list_of_normalization_files_of_individuals = []

    for individual in individuals:
        list_of_normalization_files_of_individuals.append(f"{species}/results/dynamics/{feature_library}/normalization/{individual}_coverage.tsv")

    if not list_of_normalization_files_of_individuals:
        raise ValueError(f"No normalization files could be determined for species {species}.")

    return list_of_normalization_files_of_individuals

####################################################
# Snakemake rules
####################################################

rule determine_normalization_of_individual:
    input:
        bam="{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam",
    output:
        coverage="{species}/results/dynamics/{feature_library}/normalization/{individual}_coverage.tsv",
        summary="{species}/results/dynamics/{feature_library}/normalization/{individual}_summary.txt"
    message: "Normalize scg and te coverage for {wildcards.individual}"
    log:
        "{species}/results/dynamics/{feature_library}/normalization/{individual}_normalization.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/dynamics/normalization/calculate_normalization.py"

rule combine_normalizations_for_species:
    input:
        coverage_files=combine_normalizations_for_species_input_coverage_files
    output:
        combined="{species}/results/dynamics/{feature_library}/normalization/{species}_normalized_coverage.combined.tsv"
    message: "Combine normalized coverage for {wildcards.species}"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/dynamics/normalization/combine_normalized_coverage.py"

rule plot_normalization:
    input:
        "{species}/results/dynamics/{feature_library}/normalization/{species}_normalized_coverage.combined.tsv"
    output:
        directory("{species}/results/dynamics/{feature_library}/normalization/plots/")
    message: "Plot normalized coverage for {wildcards.species}"
    params:
        order=lambda wildcards: ",".join(get_individuals_for_species(wildcards.species)),
        names=lambda wildcards: ",".join(get_individuals_for_species(wildcards.species))
    conda:
        "../../../envs/python_and_r.yaml"
    shell:
        """
        Rscript workflow/scripts/dynamics/normalization/plot_normalization.r --input "{input}" --output "{output}" --order "{params.order}" --names "{params.names}"
        """
