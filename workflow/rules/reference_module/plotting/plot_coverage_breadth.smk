####################################################
# Snakemake rules
####################################################

# Rule: Plot coverage breadth violin by individual
rule plot_mapped_reads_coverage_breadth_violin:
    input:
        "{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis_detailed.csv"
    output:
        "{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_coverage_breadth_violin.png"
    params:
        species="{species}"
    message: "Plotting coverage breadth violin for species {wildcards.species} and reference {wildcards.reference}"
    log:
        "{species}/processed/{reference}/plots/coverage/{species}_{reference}_individual_coverage_breadth_violin.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reads_to_reference/plotting/plot_coverage_breadth_by_individuals_violin.R"

# Rule: Plot coverage breadth bar by individual
rule plot_mapped_reads_coverage_breadth_bar:
    input:
        "{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis_detailed.csv"
    output:
        "{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_coverage_breadth_bar.png"
    message: "Plotting coverage breadth bar for species {wildcards.species} and reference {wildcards.reference}"
    params:
        species="{species}"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reads_to_reference/plotting/plot_coverage_breadth_by_individuals_bar.R"
