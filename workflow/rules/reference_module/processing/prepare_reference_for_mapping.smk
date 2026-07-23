####################################################
# Snakemake rules
####################################################
_ref_mapper = config.get("pipeline", {}).get("reference_processing", {}).get("mapping", {}).get("settings", {}).get("mapper", "bwa-mem2")

rule standardize_reference_extension_to_fa:
    output:
        fa="{species}/raw/ref/{reference}.fa"
    message:
        "Ensuring reference {wildcards.reference} for {wildcards.species} is standardized to .fa"
    conda:
        "../../../envs/python_and_r.yaml",
    run:
        # we use python to rename the file if necessary
        import os
        import shutil

        # Get the list of reference tuples (sanitized_name, full_path)
        # the full_path contains the original file path
        reference_tuples = get_reference_file_list_for_species(wildcards.species)

        # Find the path corresponding to the sanitized reference name
        ref_path = next((path for name, path in reference_tuples if name == wildcards.reference), None)

        if ref_path is None:
            logger.error(f"Reference {wildcards.reference} not found for species {wildcards.species}")
            logger.error(f"Available references: {reference_tuples}")
            raise ValueError(f"Reference {wildcards.reference} not found for species {wildcards.species}")

        if not os.path.exists(ref_path):
            logger.error(f"Reference file {ref_path} does not exist.")
            raise FileNotFoundError(f"Reference file {ref_path} does not exist.")

        # Create the output folder if it doesn't exist
        os.makedirs(os.path.dirname(output.fa), exist_ok=True)

        # Only rename if the standardized file doesn't already exist
        if not os.path.exists(output.fa):
            # Use symlink if you don't want to copy the file
            os.rename(ref_path, output.fa)
            logger.info(f"Reference {ref_path} renamed to {output.fa}")
        else:
            logger.info(f"Reference {output.fa} already exists, skipping.")


if _ref_mapper == "minimap2":
    rule index_reference_for_mapping_minimap2:
        input:
            target="{species}/raw/ref/{reference}.fa"
        output:
            "{species}/raw/ref/{reference}.mmi",
        message: "Indexing reference {wildcards.reference} with minimap2"
        log:
            "{species}/processed/{reference}/index/{reference}_minimap2_index.log"
        resources:
            mem_mb=16000,
        cache: True
        wrapper:
            "v9.3.0/bio/minimap2/index"

elif _ref_mapper == "bwa-aln":
    # bwa-aln
    rule index_reference_for_mapping_bwa_aln:
        input:
            "{species}/raw/ref/{reference}.fa"
        output:
            multiext("{species}/raw/ref/{reference}.fa", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        message: "Indexing reference {wildcards.reference} with BWA (for BWA ALN)"
        log:
            "{species}/processed/{reference}/index/{reference}_bwa_aln_index.log"
        resources:
            mem_mb=369000,
        cache: True
        wrapper:
            "v9.3.0/bio/bwa/index"
    

else:
    rule index_reference_for_mapping_bwa_mem2:
        input:
            "{species}/raw/ref/{reference}.fa"
        output:
            multiext("{species}/raw/ref/{reference}.fa", ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac"),
        message: "Indexing reference {wildcards.reference} with BWA-MEM2"
        log:
            "{species}/processed/{reference}/index/{reference}_bwa_mem2_index.log"
        resources:
            mem_mb=369000,
        cache: True
        wrapper:
            "v9.3.0/bio/bwa-mem2/index"
    

rule index_reference_with_samtools:
    input:
       "{species}/raw/ref/{reference}.fa"
    output:
        "{species}/raw/ref/{reference}.fa.fai"
    log:
        "{species}/raw/ref/{reference}.fa.fai.log"
    params:
        extra="",
    wrapper:
        "v9.3.0/bio/samtools/faidx"