####################################################
# Snakemake rules
####################################################

# Rule: Run FastQC on raw reads
rule run_fastqc_raw:
    input:
        "{species}/raw/reads/{sample}.fastq.gz"
    output:
        html="{species}/results/reads/reads_raw/fastqc/{sample}_raw_fastqc.html",
        zip="{species}/results/reads/reads_raw/fastqc/{sample}_raw_fastqc.zip"
    message: "Running FastQC on raw reads for sample {wildcards.sample} in species {wildcards.species}"
    params:
        extra="--quiet",
        mem_overhead_factor=0.1,
    log:
        "{species}/processed/reads/reads_raw/fastqc/{sample}_fastqc.log"
    threads: 1
    resources:
        mem_mb = 1024,
    wrapper:
        "v9.3.0/bio/fastqc"

# Rule: Run FastQC on adapter-trimmed reads
rule run_fastqc_adapter_removed:
    input:
        "{species}/processed/reads/reads_trimmed/{sample}_trimmed_final.fastq.gz"
    output:
        html="{species}/results/reads/reads_trimmed/fastqc/{sample}_trimmed_fastqc.html",
        zip="{species}/results/reads/reads_trimmed/fastqc/{sample}_trimmed_fastqc.zip"
    message: "Running FastQC on adapter-trimmed reads for sample {wildcards.sample} in species {wildcards.species}"
    params:
        extra="--quiet",
        mem_overhead_factor=0.1,
    log:
        "{species}/processed/reads/reads_trimmed/fastqc/{sample}_trimmed_fastqc.log"
    threads: 1
    resources:
        mem_mb = 1024,
    wrapper:
        "v9.3.0/bio/fastqc"

# Rule: Run FastQC on quality-filtered reads
rule run_fastqc_quality_filtered:
    input:
        "{species}/processed/reads/reads_quality_filtered/{sample}_quality_filtered_final.fastq.gz"
    output:
        html="{species}/results/reads/reads_quality_filtered/fastqc/{sample}_quality_filtered_fastqc.html",
        zip="{species}/results/reads/reads_quality_filtered/fastqc/{sample}_quality_filtered_fastqc.zip"
    message: "Running FastQC on quality-filtered reads for sample {wildcards.sample} in species {wildcards.species}"
    params:
        extra="--quiet",
        mem_overhead_factor=0.1,
    log:
        "{species}/processed/reads/reads_quality_filtered/fastqc/{sample}_quality_filtered_fastqc.log"
    threads: 1
    resources:
        mem_mb = 1024,
    wrapper:
        "v9.3.0/bio/fastqc"

# Rule: Run FastQC on merged reads
rule run_fastqc_merged:
    input:
        merged="{species}/processed/reads/reads_merged/{individual}.fastq.gz"
    output:
        html="{species}/results/reads/reads_merged/fastqc/{individual}_merged_fastqc.html",
        zip="{species}/results/reads/reads_merged/fastqc/{individual}_merged_fastqc.zip"
    message: "Running FastQC on merged reads for individual {wildcards.individual} in species {wildcards.species}"
    params:
        extra="--quiet",
        mem_overhead_factor=0.1,
    log:
        "{species}/processed/reads/reads_merged/fastqc/{individual}_fastqc.log"
    threads: 1
    resources:
        mem_mb = 1024,
    wrapper:
        "v9.3.0/bio/fastqc"