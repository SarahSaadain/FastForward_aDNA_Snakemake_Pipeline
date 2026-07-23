####################################################
# Snakemake rules
####################################################

# Rule: Plot endogenous reads bar chart
rule plot_mapped_reads_endogenous_bar:
    input:
        "{species}/results/summary/species_level/{species}_overall/multiqc_custom_content/{species}_{reference}_reads_processing_summary_combined.tsv"
    output:
        plot = "{species}/results/{reference}/plots/endogenous_reads/{species}_{reference}_endogenous_reads_bar_chart.png"
    message: "Plotting endogenous reads bar chart for species {wildcards.species} and reference {wildcards.reference}"
    log:
        "{species}/processed/{reference}/plots/endogenous_reads/{species}_{reference}_endogenous_reads_bar_chart.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/reads_to_reference/plotting/plot_endogenous_reads_bar.R"