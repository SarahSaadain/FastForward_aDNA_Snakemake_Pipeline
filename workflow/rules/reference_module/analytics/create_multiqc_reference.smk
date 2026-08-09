def create_multiqc_reference_input(wildcards):
    """Generate a list of input files for MultiQC report for all individuals of a species mapped to one reference."""

    species = wildcards.species
    reference = wildcards.reference
    individuals = get_individuals_for_species(species)

    file_list = []

    for individual in individuals:

        samples_of_individual = get_samples_for_species_individual(species, individual)

        if config.get("pipeline", {}).get("read_module", {}).get("execute", True) == True:

            if config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("execute", True) == True:
                
                if config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("tools", {}).get("centrifuge", {}).get("execute", True) == True:
                    
                    for sample in samples_of_individual:
                        raw_reads = get_raw_reads_for_sample(species, sample)
                        file_list.append(f"{species}/results/read_module/contamination/centrifuge/{individual}/{sample}/{sample}_top10_total_taxa.tsv")

                if config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("tools", {}).get("ecmsd", {}).get("execute", True) == True:
                    file_list.append(f"{species}/results/read_module/contamination/ecmsd/{individual}_Mito_summary_hits_combined.tsv")

            # merged reads fastqc
            if config.get("pipeline", {}).get("read_module", {}).get("analysis", {}).get("execute", True) == True and config.get("pipeline", {}).get("read_module", {}).get("analysis", {}).get("settings", {}).get("multiqc_merged_reads", True) == True:
                file_list.append(f"{species}/results/read_module/reads_merged/fastqc/{individual}_merged_fastqc.zip")

        # bam analytics for the single reference
        if config.get("pipeline", {}).get("reference_module", {}).get("execute", False) == True:

            if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("execute", True) == True:
                if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("preseq_complexitiy_curve", True) == True:
                    file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.c_curve.txt")
                if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("qualimap", True) == True:
                    file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/qualimap/{individual}_{reference}")
                if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("samtools_stats", True) == True:
                    file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/samtools_stats/{individual}_{reference}_final.bam.stats")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary_stacked.tsv")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.tsv")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_summary.tsv")

            if config.get("pipeline", {}).get("reference_module", {}).get("damage_rescaling", {}).get("execute", True) == True:
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/3pGtoA_freq.txt")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/5pCtoT_freq.txt")
                file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/lgdistribution.txt")

    logger.debug(f"MultiQC reference input files for species {species}, reference {reference}: {file_list}")

    return file_list

####################################################
# Snakemake rules
####################################################
rule create_multiqc_reference:
    input:
        create_multiqc_reference_input,
        config="{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/{species}_{reference}_multiqc_config.yaml"
    output:
        "{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}_multiqc.html",
        directory("{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/multiqc_data"),
    params:
        extra="--verbose",
        use_input_files_only=True,
    log:
        "{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/multiqc.log",
    wrapper:
        "v9.3.0/bio/multiqc"

rule create_multiqc_reference_config:
    output:
        "{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/{species}_{reference}_multiqc_config.yaml"
    log:
        "{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/{species}_{reference}_multiqc_config.log"
    script:
        "../../../scripts/summary_module/create_multiqc_species_individual_script_create_multiqc_species_individual_config.py"
