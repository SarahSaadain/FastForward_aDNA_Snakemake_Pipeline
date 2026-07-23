####################################################
# Snakemake rules
####################################################

# Rule: Determine endogenous reads from BAM stats
rule determine_mapped_reads_endogenous:
    input:
        stats="{species}/results/{reference}/analytics/individual_level/{individual}/samtools_stats/{individual}_{reference}_final.bam.stats"
    output:
        csv="{species}/results/{reference}/analytics/individual_level/{individual}/endogenous/{individual}_{reference}.endogenous.csv"
    message: "Determining endogenous reads for {input.stats}"
    log:
        "{species}/processed/{reference}/analytics/{individual}/endogenous/{individual}_{reference}_endogenous.log"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/reads_to_reference/analytics/statistics/parse_endogenous_from_stats.py"

# Rule: Combine endogenous reads for all individuals
rule combine_determine_mapped_reads_endogenous:
    input:
        lambda wildcards: expand(
            "{species}/results/{reference}/analytics/individual_level/{individual}/endogenous/{individual}_{reference}.endogenous.csv",
            species=wildcards.species,
            reference=wildcards.reference,
            individual=get_individuals_for_species(wildcards.species),
        )
    output:
        "{species}/results/{reference}/analytics/species_level/{species}/endogenous/{reference}_endogenous.csv"
    message: "Combining endogenous reads for species {wildcards.species}"
    log:
        "{species}/processed/{reference}/analytics/{species}/endogenous/{reference}_endogenous.log"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/reads_to_reference/analytics/statistics/combine_endogenous_reads.py"
