####################################################
# Snakemake rules
####################################################

# Rule: Plot endogenous reads bar chart
rule plot_raw_and_endogenous_reads_as_bar_plot:
    input:
        processing_results = "{species}/results/reads_module/statistics/{species}_reads_counts.csv",
        endogenous_results = "{species}/results/reference_module/{reference}/analytics/species_level/{species}/endogenous/{reference}_endogenous.csv"
    output:
        plot = "{species}/results/reference_module/{reference}/plots/endogenous_reads/{species}_{reference}_raw_and_endogenous_reads_bar_chart.png"
    message: "Plotting raw results and endogenous reads bar chart for species {wildcards.species} and reference {wildcards.reference}"
    log:
        "{species}/processed/reference_module/{reference}/plots/endogenous_reads/{species}_{reference}_raw_and_endogenous_reads_bar_chart.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reference_module/plotting/plot_raw_results_and_endogenous_reads_bar.R"