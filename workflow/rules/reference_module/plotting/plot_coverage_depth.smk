####################################################
# Snakemake rules
####################################################

# Rule: Plot depth coverage violin by individual
rule plot_mapped_reads_depth_coverage_violin:
    input:
        "{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis_detailed.csv"
    output:
        "{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_depth_coverage_violin.png"
    message: "Plotting depth coverage violin for species {wildcards.species} and reference {wildcards.reference}"
    params:
        species="{species}"
    log:
        "{species}/processed/{reference}/plots/coverage/{species}_{reference}_individual_depth_coverage_violin.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reads_to_reference/plotting/plot_coverage_depth_by_individuals_violin.R"

# Rule: Plot depth coverage bar by individual
rule plot_mapped_reads_depth_coverage_bar:
    input:
        "{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis_detailed.csv"
    output:
        "{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_depth_coverage_bar.png"
    message: "Plotting depth coverage bar for species {wildcards.species} and reference {wildcards.reference}"
    params:
        species="{species}"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reads_to_reference/plotting/plot_coverage_depth_by_individuals_bar.R"
