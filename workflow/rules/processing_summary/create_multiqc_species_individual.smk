import textwrap

def create_multiqc_species_individual_input(wildcards):
    """Generate a list of input files for MultiQC report for a given species and its individuals."""

    species = wildcards.species
    individual = wildcards.individual

    try:
        # Get all reference for the species
        references = get_references_ids_for_species(species)
    except Exception as e: 
        # Print error if reference files are missing or inaccessible
        logging.info(e)
        references = []

    file_list = []

    #for individual in individuals:
    # get samples for individual
    samples_of_individual = get_samples_for_species_individual(species, individual)

    for sample in samples_of_individual:

        # get raw read file paths
        raw_reads = get_raw_reads_for_sample(species, sample)

        # if config.get("pipeline", {}).get("reads_processing", {}).get("adapter_removal", {}).get("execute", True) == True:
        #     # add fastp json reports
        #     # fastp trimming reports
        #     if len(raw_reads) == 2:
        #         file_list.append(f"{species}/results/reads/reads_trimmed/fastp_report/{sample}_trimmed.pe.json")
        #     else:
        #         file_list.append(f"{species}/results/reads/reads_trimmed/fastp_report/{sample}_trimmed.se.json")

        # if config.get("pipeline", {}).get("reads_processing", {}).get("quality_filtering", {}).get("execute", True) == True:
        #     # fastp quality filtering reports
        #     file_list.append(f"{species}/results/reads/reads_quality_filtered/fastp_report/{sample}_quality_filtered.json")

        # contamination analysis outputs
        if config.get("pipeline", {}).get("raw_reads_processing", {}).get("contamination_analysis", {}).get("execute", True) == True:

            #if config.get("pipeline", {}).get("reference_processing", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("execute", True) == True:
            #    file_list.append(f"{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/pipeline/{sample}_ecmsd_proportions.tsv")

            if config.get("pipeline", {}).get("raw_reads_processing", {}).get("contamination_analysis", {}).get("tools", {}).get("centrifuge", {}).get("execute", True) == True:
                # file_list.append(f"{species}/results/contamination_analysis/centrifuge/{individual}/{sample}/{sample}_centrifuge_proportions.tsv")
                file_list.append(f"{species}/results/contamination_analysis/centrifuge/{individual}/{sample}/{sample}_top10_total_taxa.tsv")
                # file_list.append(f"{species}/results/contamination_analysis/centrifuge/{individual}/{sample}/{sample}_top10_unique_taxa.tsv")

    if config.get("pipeline", {}).get("raw_reads_processing", {}).get("contamination_analysis", {}).get("execute", True) == True and config.get("pipeline", {}).get("raw_reads_processing", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("execute", True) == True:
        file_list.append(f"{species}/results/contamination_analysis/ecmsd/{individual}_Mito_summary_hits_combined.tsv")

    # merged reads fastqc
    if config.get("pipeline", {}).get("raw_reads_processing", {}).get("analysis", {}).get("execute", True) == True and config.get("pipeline", {}).get("raw_reads_processing", {}).get("analysis", {}).get("settings", {}).get("multiqc_merged_reads", True) == True:
        file_list.append(f"{species}/results/reads/reads_merged/fastqc/{individual}_merged_fastqc.zip")

    # bam analytics
    if config.get("pipeline", {}).get("reference_processing", {}).get("execute", False) == True:

        for reference in references:
            
            if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("execute", True) == True:
                #file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.lc_extrap")
                if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("c_curve", True) == True:
                    file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.c_curve.txt")
                if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("qualimap", True) == True:
                    file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/qualimap/{individual}_{reference}")
                if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("samtools_stats", True) == True:
                    file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/samtools_stats/{individual}_{reference}_final.bam.stats")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary_stacked.tsv")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.tsv")
                # file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_depth_coverage_avg.csv")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_summary.tsv")
            
            if config.get("pipeline", {}).get("reference_processing", {}).get("damage_rescaling", {}).get("execute", True) == True:
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/3pGtoA_freq.txt")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/5pCtoT_freq.txt")
                file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/lgdistribution.txt")
            
            # if config.get("pipeline", {}).get("reference_processing", {}).get("deduplication", {}).get("execute", True) == True:
            #     file_list.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/dedup/{individual}_{reference}_final.dedup.json")

    logger.debug(f"MultiQC input files for species {species}: {file_list}")

    return file_list

####################################################
# Snakemake rules
####################################################
rule create_multiqc_species_individual:
    input:
        create_multiqc_species_individual_input,
        config="{species}/results/summary/individual_level/{individual}/{individual}_multiqc_config.yaml"
    output:
        "{species}/results/summary/individual_level/{individual}_multiqc.html",
        directory("{species}/results/summary/individual_level/{individual}/multiqc_data"),
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
        use_input_files_only=True
    log:
        "{species}/results/summary/individual_level/{individual}/multiqc.log",
    wrapper:
        "v9.3.0/bio/multiqc"

rule create_multiqc_species_individual_config:
    output:
        "{species}/results/summary/individual_level/{individual}/{individual}_multiqc_config.yaml"
    script:
        "../../scripts/processing_summary/create_multiqc_species_individual_script_create_multiqc_species_individual_config.py"
        