
####################################################
# Python helper functions for rules
# Naming of functions: <rule_name>_<rule_parameter>[_<rule_subparameter>]>
####################################################

def dedup_merge_split_bams_input(wildcards):
    """
    Get all dedup BAMs corresponding to the contig group files named as 'cluster_{start}_{end}.bed'.
    """
    import glob
    import os

    # Get checkpoint output folder
    # we use the checkpoint here to make sure that the files are generated before we try to access them
    # for more info see: https://snakemake.readthedocs.io/en/stable/snakefiles/rules.html#data-dependent-conditional-execution
    checkpoint_output = checkpoints.dedup_create_all_contig_clusters.get(
        species=wildcards.species, reference=wildcards.reference
    ).output.cluster_folder

    # Find all group files
    group_files = sorted(glob.glob(os.path.join(checkpoint_output, "cluster_*.bed")))

    logger.debug(f"Found {len(group_files)} contig cluster files for deduplication.")
    logger.debug(f"Cluster files: {group_files}")

    bam_files = []
    for group_file in group_files:
        group_name = os.path.splitext(os.path.basename(group_file))[0]  # "group_1_50"
        start_end = group_name.split("_")[1:]  # ["1", "50"]
        start, end = map(int, start_end)
        bam_path = (
            f"{wildcards.species}/processed/{wildcards.reference}/dedup_cluster/"
            f"{wildcards.individual}/dedup_{start}_{end}/{wildcards.individual}_{wildcards.reference}_cluster_{start}_{end}_rmdup.bam"
        )
        bam_files.append(bam_path)

    # add unmapped reads bam file to the list of bams to merge
    bam_files.append(
        f"{wildcards.species}/processed/{wildcards.reference}/mapped/{wildcards.individual}_{wildcards.reference}_unmapped_reads.bam"
    )

    logger.debug(f"Requesting {len(bam_files)} deduplicated BAM files for merging.")
    logger.debug(f"Deduplicated BAM files: {bam_files}")

    return bam_files


def dedup_merge_split_jsons_input(wildcards):
    """
    Get all DeDup JSON files corresponding to contig group files
    named as 'cluster_{start}_{end}.bed'.
    """
    import glob
    import os

    # Resolve checkpoint output folder (forces execution before globbing)
    checkpoint_output = checkpoints.dedup_create_all_contig_clusters.get(
        species=wildcards.species,
        reference=wildcards.reference
    ).output.cluster_folder

    # Find all contig group files
    group_files = sorted(
        glob.glob(os.path.join(checkpoint_output, "cluster_*_*.bed"))
    )

    logger.info(f"Found {len(group_files)} contig group files.")
    logger.debug(f"Group files: {group_files}")

    json_files = []

    for group_file in group_files:
        # group_1_500.txt → start=1, end=500
        group_name = os.path.basename(group_file)
        group_name = os.path.splitext(group_name)[0]

        _, start, end = group_name.split("_", 2)

        json_path = (
            f"{wildcards.species}/processed/{wildcards.reference}/dedup_cluster/"
            f"{wildcards.individual}/dedup_{start}_{end}/{wildcards.individual}_{wildcards.reference}_cluster_{start}_{end}.dedup.json"
        )

        json_files.append(json_path)

    logger.info(f"Requesting {len(json_files)} DeDup JSON files for MultiQC.")
    logger.debug(f"DeDup JSON files: {json_files}")

    return json_files

####################################################
# Snakemake rules
####################################################

# Rule: Extract contig names from reference FAI
# Rule: Extract contigs as BED (full-length intervals) from reference FAI
rule dedup_extract_contigs_from_reference_fai:
    input:
        fai="{species}/raw/ref/{reference}.fa.fai"
    output:
        bed=temp("{species}/processed/{reference}/dedup_cluster/contigs.bed")
    message:
        "Extracting full-length contig BED from FAI for {wildcards.species} / {wildcards.reference}"
    shell:
        """
        awk '{{print $1 "\t0\t" $2}}' "{input.fai}" > "{output.bed}"
        """

# Checkpoint: Create all contig clusters for deduplication
checkpoint dedup_create_all_contig_clusters:
    input:
        contigs="{species}/processed/{reference}/dedup_cluster/contigs.bed"
    output:
        cluster_folder=directory("{species}/processed/{reference}/dedup_cluster/clusters")
    message:
        "Creating contig clusters for deduplication for species {wildcards.species} and reference {wildcards.reference}"
    params:
        cores = workflow.cores,
        min_contigs_per_cluster = config.get("pipeline", {}).get("reference_processing", {}).get("deduplication", {}).get("settings", {}).get("min_contigs_per_cluster", 1),
        max_contigs_per_cluster = config.get("pipeline", {}).get("reference_processing", {}).get("deduplication", {}).get("settings", {}).get("max_contigs_per_cluster", 500)
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/reads_to_reference/processing/deduplication_script_dedup_create_all_contig_clusters.py"

rule save_unmapped_reads_from_bam:
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam"
    output:
        bam=temp("{species}/processed/{reference}/mapped/{individual}_{reference}_unmapped_reads.bam") # needs to be called .unsorted.bam otherwise snakemake had problems with unambigous names
    message: "Converting SAM to BAM for {input}"
    params:
        extra="-b -f 4",  # optional params string
    threads: 2
    wrapper:
        "v9.3.0/bio/samtools/view"

# Rule: Split BAM file into contig clusters
rule dedup_split_bam_into_clusters_by_contig_cluster:
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam"
    output:
        bam = temp("{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_cluster_{start}_{end}.bam"),
    message:
        "Splitting BAM file {input} into cluster {wildcards.start}-{wildcards.end} for individual {wildcards.individual} in species {wildcards.species}",
    log:
        "{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_{start}_{end}.bam.log",
    params:
        extra="-L {species}/processed/{reference}/dedup_cluster/clusters/cluster_{start}_{end}.bed",
        region="",  # optional region string
    threads: 2
    wrapper:
        "v9.3.0/bio/samtools/view"

# Rule: Index split cluster BAM file
rule dedup_index_split_cluster_bam:
    input:
        "{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_cluster_{start}_{end}.bam"
    output:
        temp("{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_cluster_{start}_{end}.bam.bai")
    message:
        "Indexing split BAM file for cluster {wildcards.start}-{wildcards.end} for individual {wildcards.individual} in species {wildcards.species}"
    params:
        extra="",  # optional params string
    threads: 2
    wrapper:
        "v9.3.0/bio/samtools/index"

# Rule: Deduplicate BAM file for each contig cluster
rule dedup_deduplicate_bam_cluster:
    input:
        bam="{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_cluster_{start}_{end}.bam",
        bai="{species}/processed/{reference}/dedup_cluster/{individual}/split_cluster/{individual}_{reference}_cluster_{start}_{end}.bam.bai"
    output:
        dedup_folder= directory("{species}/processed/{reference}/dedup_cluster/{individual}/dedup_{start}_{end}/"),
        dedup_bam   = temp("{species}/processed/{reference}/dedup_cluster/{individual}/dedup_{start}_{end}/{individual}_{reference}_cluster_{start}_{end}_rmdup.bam"),
        dedup_hist  = "{species}/processed/{reference}/dedup_cluster/{individual}/dedup_{start}_{end}/{individual}_{reference}_cluster_{start}_{end}.hist",
        dedup_json  = "{species}/processed/{reference}/dedup_cluster/{individual}/dedup_{start}_{end}/{individual}_{reference}_cluster_{start}_{end}.dedup.json",
    message:
        "Deduplicating BAM file for {input.bam} using dedup for individual {wildcards.individual} in species {wildcards.species}",
    log: 
        "{species}/processed/{reference}/dedup_cluster/{individual}/dedup_{start}_{end}/{individual}_{reference}_{start}_{end}.dedup.log",
    resources:
        mem_mb = 20000
    params:
        jar = DEDUP_JAR_PATH
    conda:
        "../../../envs/dedup.yaml"
    shell:
        """
        mkdir -p "{output.dedup_folder}"
        java -Xms5g -Xmx20g -jar "{params.jar}" --input "{input.bam}" --merged --output "{output.dedup_folder}"
        """

# Rule: Merge deduplicated BAM files
rule dedup_merge_bam_clusters:
    input:
        dedup_merge_split_bams_input
    output:
        temp("{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted_dedupped.bam")
    log:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted_dedupped.log"
    message:
        "Merging deduplicated BAM files for individual {wildcards.individual} in species {wildcards.species}"
    params:
        extra="",  # optional additional parameters as string
    threads: 8
    wrapper:
        "v9.3.0/bio/samtools/merge"

# Rule: Sort BAM file
rule sort_mapped_dedupped_reads_bam:
    # 3 Sort BAM
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_unsorted_dedupped.bam"
    output:
        temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped.bam")
    message: "Sorting deduplicated BAM file for {input}"
    log:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_bam.log",
    threads: 10
    wrapper:
        "v9.3.0/bio/samtools/sort"

# Rule: Index BAM file
rule dedup_index_dedupped_bam:
    # 4 Index BAM
    input:
        "{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped.bam" 
    output:
        temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped.bam.bai")
    message: "Indexing deduplicated BAM file for {input}"
    params:
        extra="",  # optional params string
    threads: 5
    wrapper:
        "v9.3.0/bio/samtools/index"

# Rule: Merge DeDup JSON files
rule dedup_merge_cluster_jsons:
    input:
        dedup_merge_split_jsons_input
    output:
        json="{species}/results/{reference}/analytics/individual_level/{individual}/dedup/{individual}_{reference}_final.dedup.json"
    message:
        "Merging DeDup JSON files for individual {wildcards.individual} in species {wildcards.species}"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/reads_to_reference/processing/deduplication_script_dedup_merge_cluster_jsons.py"

