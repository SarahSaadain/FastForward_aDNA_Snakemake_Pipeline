####################################################
# Snakemake rules
####################################################

# Rule: Quality filtering of reads using fastp
rule filter_reads_by_quality:
    input:
        sample = ["{species}/processed/reads_module/reads_trimmed/{sample}_trimmed_final.fastq.gz"]
    output:
        trimmed=temp("{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered.fastq.gz"),
        failed=temp("{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered.failed.fastq.gz"),
        html="{species}/results/reads/reads_quality_filtered/fastp_report/{sample}_quality_filtered.html",
        json="{species}/results/reads/reads_quality_filtered/fastp_report/{sample}_quality_filtered.json",
    message: "Quality filtering reads in {input.sample}"
    log:
        "{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered.log",
    params:
        extra=f"--disable_adapter_trimming --qualified_quality_phred {config.get('pipeline', {}).get('read_module', {}).get('quality_filtering', {}).get('settings', {}).get('min_quality','15')} --length_required {config.get('pipeline', {}).get('read_module', {}).get('quality_filtering', {}).get('settings', {}).get('min_length','15')} --unqualified_percent_limit 40 --n_base_limit 5"
    threads: 10
    wrapper:
        "v9.3.0/bio/fastp"

rule get_quality_filtered_final:
    input:
        # If quality filtering is enabled, use the quality filtered reads as input for the next steps in the pipeline.
        # If quality filtering is not enabled, use the trimmed reads as input for the next steps in the pipeline.
        source=lambda wildcards: (
            f"{wildcards.species}/processed/reads_module/reads_quality_filtered/{wildcards.sample}_quality_filtered.fastq.gz"
            if config.get('pipeline', {}).get('read_module', {}).get('quality_filtering', {}).get('execute', True)
            else f"{wildcards.species}/processed/reads_module/reads_trimmed/{wildcards.sample}_trimmed_final.fastq.gz"
        ),
    output:
        final=temp("{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered_final.fastq.gz")
    message: "Selecting quality filtered reads for {wildcards.sample}"
    shell:
        "cp \"{input.source}\" \"{output.final}\""