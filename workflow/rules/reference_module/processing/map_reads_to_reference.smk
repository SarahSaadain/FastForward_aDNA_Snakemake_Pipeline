####################################################
# Snakemake rules
####################################################
_ref_settings      = config.get("pipeline", {}).get("reference_processing", {}).get("mapping", {}).get("settings", {})
_ref_mapper        = _ref_settings.get("mapper", "bwa-mem2")
_BWA_ALN_DEFAULTS  = "-n 0.01 -k 2 -l 1024 -o 2"  # Oliva et al. 2021 (10.1093/bib/bbab076)
_MINIMAP2_DEFAULTS = "-ax sr"
_ref_mapper_extra  = _ref_settings.get(
    "mapper_extra_params",
    _BWA_ALN_DEFAULTS if _ref_mapper == "bwa-aln" else
    _MINIMAP2_DEFAULTS if _ref_mapper == "minimap2" else ""
)

if _ref_mapper == "minimap2":
    rule map_reads_to_reference_minimap2:
        input:
            query=["{species}/processed/reads/reads_merged/{individual}.fastq.gz"],
            target="{species}/raw/ref/{reference}.mmi",
        output:
            temp("{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted.bam")
        log:
            "{species}/processed/{reference}/mapped/{individual}_{reference}.bam.log"
        params:
            extra=_ref_mapper_extra,
            sorting="none",
        threads: 15
        wrapper:
            "v9.3.0/bio/minimap2/aligner"

elif _ref_mapper == "bwa-aln":
    
     # bwa-aln
    rule align_reads_to_reference_bwa_aln:
        input:
            fastq="{species}/processed/reads/reads_merged/{individual}.fastq.gz",
            idx=multiext("{species}/raw/ref/{reference}.fa", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        output:
            temp("{species}/processed/{reference}/mapped/{individual}_{reference}.sai"),
        log:
            "{species}/processed/{reference}/mapped/{individual}_{reference}_bwa_aln.log",
        params:
            extra=_ref_mapper_extra,
        threads: 10
        wrapper:
            "v9.3.0/bio/bwa/aln"

    rule map_reads_to_reference_bwa_aln:
        input:
            fastq="{species}/processed/reads/reads_merged/{individual}.fastq.gz",
            sai="{species}/processed/{reference}/mapped/{individual}_{reference}.sai",
            idx=multiext("{species}/raw/ref/{reference}.fa", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        output:
            temp("{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted.bam")
        log:
            "{species}/processed/{reference}/mapped/{individual}_{reference}.bam.log"
        threads: 1
        wrapper:
            "v9.3.0/bio/bwa/samse"

else:
    rule map_reads_to_reference_bwa_mem2:
        input:
            reads=["{species}/processed/reads/reads_merged/{individual}.fastq.gz"],
            idx=multiext("{species}/raw/ref/{reference}.fa", ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac"),
        output:
            temp("{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted.bam")
        log:
            "{species}/processed/{reference}/mapped/{individual}_{reference}.bam.log"
        params:
            extra=_ref_mapper_extra,
        threads: 15
        wrapper:
            "v9.3.0/bio/bwa-mem2/mem"
   

# Rule: Sort BAM file
rule sort_mapped_reads_bam:
    # 3 Sort BAM
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted.bam"
    output:
        temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam")
    message: "Sorting BAM file for {input}"
    log:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_bam.log",
    threads: 10
    wrapper:
        "v9.3.0/bio/samtools/sort"

# Rule: Index BAM file
rule index_mapped_sorted_reads_bam:
    # 4 Index BAM
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam"
    output:
        temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam.bai")
    message: "Indexing BAM file for {input}"
    params:
        extra="",  # optional params string
    threads: 5
    wrapper:
        "v9.3.0/bio/samtools/index"
