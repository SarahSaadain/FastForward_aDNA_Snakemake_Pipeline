####################################################
# Snakemake rules
####################################################
_ref_mapper = config.get("pipeline", {}).get("reference_module", {}).get("mapping", {}).get("settings", {}).get("mapper", "bwa-mem2")

rule standardize_reference_extension_to_fa:
    output:
        fa="{species}/input/reference_module/{reference}.fa"
    conda:
        "../../../envs/python_and_r.yaml",
    params:
        ref_path=_standardize_reference_extension_to_fa_ref_path
    message:
        "Ensuring reference {wildcards.reference} for {wildcards.species} is standardized to .fa"
    log:
        "{species}/input/reference_module/{reference}_standardize.log"
    script:
        "../../../scripts/reference_module/processing/standardize_reference_extension_to_fa.py"


if _ref_mapper == "minimap2":
    rule index_reference_for_mapping_minimap2:
        input:
            target="{species}/input/reference_module/{reference}.fa"
        output:
            "{species}/input/reference_module/{reference}.mmi",
        message: "Indexing reference {wildcards.reference} with minimap2"
        log:
            "{species}/processed/reference_module/{reference}/index/{reference}_minimap2_index.log"
        resources:
            mem_mb=16000,
        cache: True
        wrapper:
            "v9.3.0/bio/minimap2/index"

elif _ref_mapper == "bwa-aln":
    # bwa-aln
    rule index_reference_for_mapping_bwa_aln:
        input:
            "{species}/input/reference_module/{reference}.fa"
        output:
            multiext("{species}/input/reference_module/{reference}.fa", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        message: "Indexing reference {wildcards.reference} with BWA (for BWA ALN)"
        log:
            "{species}/processed/reference_module/{reference}/index/{reference}_bwa_aln_index.log"
        resources:
            mem_mb=369000,
        cache: True
        wrapper:
            "v9.3.0/bio/bwa/index"
    

else:
    rule index_reference_for_mapping_bwa_mem2:
        input:
            "{species}/input/reference_module/{reference}.fa"
        output:
            multiext("{species}/input/reference_module/{reference}.fa", ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac"),
        message: "Indexing reference {wildcards.reference} with BWA-MEM2"
        log:
            "{species}/processed/reference_module/{reference}/index/{reference}_bwa_mem2_index.log"
        resources:
            mem_mb=369000,
        cache: True
        wrapper:
            "v9.3.0/bio/bwa-mem2/index"
    

rule index_reference_with_samtools:
    input:
       "{species}/input/reference_module/{reference}.fa"
    output:
        "{species}/input/reference_module/{reference}.fa.fai"
    log:
        "{species}/input/reference_module/{reference}.fa.fai.log"
    params:
        extra="",
    wrapper:
        "v9.3.0/bio/samtools/faidx"