####################################################
# Snakemake rules
####################################################

def create_multiqc_bam_individual_input(wildcards):

    species = wildcards.species
    reference = wildcards.reference
    individual = wildcards.individual

    file_list = []

    #for individual in individuals:
    # get samples for individual
    samples_of_individual = get_samples_for_species_individual(species, individual)

    if config.get("pipeline", {}).get("read_module", {}).get("execute", True) == True:

        if config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("execute", True) == True :

            if config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("centrifuge", {}).get("execute", True) == True:
                
                for sample in samples_of_individual:
                    raw_reads = get_raw_reads_for_sample(species, sample)
                    file_list.append(f"{species}/results/reads_module/contamination_analysis/centrifuge/{individual}/{sample}/{sample}_top10_total_taxa.tsv")
                    
            if config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("execute", True) == True:
                file_list.append(f"{species}/results/reads_module/contamination_analysis/ecmsd/{individual}_Mito_summary_hits_combined.tsv")

        # merged reads fastqc
        if config.get("pipeline", {}).get("read_module", {}).get("analysis", {}).get("execute", True) == True and config.get("pipeline", {}).get("read_module", {}).get("analysis", {}).get("settings", {}).get("multiqc_merged_reads", True) == True:
            file_list.append(f"{species}/results/reads_module/reads_merged/fastqc/{individual}_merged_fastqc.zip")

    if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("execute", True) == True:
        #file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.lc_extrap")
        if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("c_curve", True) == True:
            file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.c_curve.txt")
        if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("qualimap", True) == True:
            file_list.append(directory(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/qualimap"))
        if config.get("pipeline", {}).get("reference_module", {}).get("analysis", {}).get("settings", {}).get("samtools_stats", True) == True:
            file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/samtools_stats/{individual}_{reference}_final.bam.stats")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary_stacked.tsv")
        # file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.tsv")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_depth_coverage_avg.csv")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_summary.tsv")
    
    if config.get("pipeline", {}).get("reference_module", {}).get("damage_rescaling", {}).get("execute", True) == True:
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/3pGtoA_freq.txt")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/5pCtoT_freq.txt")
        file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/lgdistribution.txt")
    
    # if config.get("pipeline", {}).get("reference_module", {}).get("deduplication", {}).get("execute", True) == True:
    #     file_list.append(f"{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/dedup/{individual}_{reference}_final.dedup.json")

    return file_list

####################################################
# Snakemake rules
####################################################
rule create_multiqc_bam_individual:
    input:
        create_multiqc_bam_individual_input,
        config="{species}/results/summary/individual_level/{individual}/{individual}_{reference}_multiqc_config.yaml"
    output:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}_{reference}_multiqc.html",
        directory("{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_data"),
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
        use_input_files_only=True,  # Optional: only use the specified input files.
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc.log",
    wrapper:
        "v9.3.0/bio/multiqc"

rule create_multiqc_bam_individual_config:
    output:
        "{species}/results/summary/individual_level/{individual}/{individual}_{reference}_multiqc_config.yaml"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/summary_module/create_multiqc_species_individual_script_create_multiqc_species_individual_config.py"
        