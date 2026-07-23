####################################################
# Snakemake rules
####################################################

# Rule: Plot read count comparison for species
rule plot_read_counts:
    input:
        "{species}/results/reads/statistics/{species}_reads_counts.csv"
    output:
        "{species}/results/reads/plots/{species}_read_counts.png"
    message: "Plotting read counts comparison for species {wildcards.species}"
    log:
        "{species}/processed/reads/plots/{species}_read_counts.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/raw_reads/plotting/plot_read_counts.R"

# Rule: Plot read count comparison by individual
rule plot_read_counts_comparison_by_individual:
    input:
        "{species}/results/reads/statistics/{species}_reads_counts.csv"
    output:
         "{species}/results/reads/plots/{species}_read_counts_comparison_by_individual.png"
    message: "Plotting read counts comparison per individual for species {wildcards.species}"
    log:
        "{species}/processed/reads/plots/{species}_read_counts_comparison_by_individual.log"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/raw_reads/plotting/plot_read_counts_comparison_by_individual.R"
