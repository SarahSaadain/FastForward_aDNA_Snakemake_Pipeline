####################################################
# Snakemake rules
####################################################

# Rule: Calculate coverage depth using samtools
rule determine_mapped_reads_coverage:
    input:
        bams=["{species}/processed/{reference}/mapped/{individual}_{reference}_final.bam"]
    output:
        temp("{species}/processed/{reference}/coverage/{individual}/{individual}_{reference}_depth.tsv")
    log:
        "{species}/processed/{reference}/coverage/{individual}/{individual}_{reference}_depth.log"
    message: "Calculating coverage depth for {input.bams}"
    params:
        # optional bed file passed to -b
        extra="-aa",  # optional additional parameters as string
    wrapper:
        "v9.3.0/bio/samtools/depth"

# Rule: Analyze coverage depth and breadth
rule analyze_mapped_reads_coverage:
    input:
        depth_txt="{species}/processed/{reference}/coverage/{individual}/{individual}_{reference}_depth.tsv"
    output:
        analysis="{species}/results/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv"
    message: "Analyzing coverage depth and breadth for {input.depth_txt}"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/reads_to_reference/analytics/statistics/analyze_samtools_depth_individual_file.py"

# Rule: Combine coverage analysis files
rule combine_analyzed_mapped_reads_coverage:
    input:
        analysis = lambda wildcards: expand(
            "{species}/results/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv",
            species=wildcards.species,
            reference=wildcards.reference,
            individual=get_individuals_for_species(wildcards.species),
        )
    output:
        combined="{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis.csv",
        detailed="{species}/results/{reference}/analytics/species_level/{species}/coverage/{reference}_combined_coverage_analysis_detailed.csv"
    message: "Combining coverage analysis files for species {params.species}"
    conda:
        "../../../envs/python_and_r.yaml",
    params:
        species="{species}"
    script:
        "../../../scripts/reads_to_reference/analytics/statistics/combine_analyzed_depth_breadth_files.py"
