import os
import logging

# -----------------------------------------------------------------------------------------------
# Get all expected output file paths for reference processing
def get_expected_output_reference_processing(species):

    if config.get("pipeline", {}).get("reference_processing", {}).get("execute", True) == False:
        logging.info(f"Skipping reference processing for {species}. Disabled in config.")
        return []

    expected_outputs = []

    try:
    # Get all reference for the species
        references_list = get_references_ids_for_species(species)

    except Exception as e: 
        # Print error if reference files are missing or inaccessible
        logging.error(e)
        return []
    
     # Get all individuals for the species
    individuals = get_individuals_for_species(species)

    for reference in references_list:

        # Endogenous reads data always generated
        expected_outputs.append(f"{species}/results/{reference}/analytics/species_level/{species}/endogenous/{reference}_endogenous.csv")

        if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("execute", True) == True:
            if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("create_plots", True) == True:
                expected_outputs.append(f"{species}/results/{reference}/plots/endogenous_reads/{species}_{reference}_endogenous_reads_bar_chart.png")
                expected_outputs.append(f"{species}/results/{reference}/plots/endogenous_reads/{species}_{reference}_raw_and_endogenous_reads_bar_chart.png")
                expected_outputs.append(f"{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_depth_coverage_violin.png")
                expected_outputs.append(f"{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_depth_coverage_bar.png")
                expected_outputs.append(f"{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_coverage_breadth_bar.png")
                expected_outputs.append(f"{species}/results/{reference}/plots/coverage/{species}_{reference}_individual_coverage_breadth_violin.png")
            else:
                logging.info(f"Skipping plots for species {species} and reference {reference}. Disabled in config.")

            if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("species_multiqc", True) == True:
                expected_outputs.append(f"{species}/results/{reference}/analytics/species_level/{species}_{reference}_multiqc.html")
        else:
            logging.info(f"Skipping analysis for species {species} and reference {reference}. Disabled in config.")

        for individual in individuals:

            expected_outputs.append(f"{species}/processed/{reference}/mapped/{individual}_{reference}_final.bam")
            expected_outputs.append(f"{species}/processed/{reference}/mapped/{individual}_{reference}_final.bam.bai")

            if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("execute", True) == True:
                if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("individual_multiqc", True) == True:
                    expected_outputs.append(f"{species}/results/{reference}/analytics/individual_level/{individual}_{reference}_multiqc.html")

                if config.get("pipeline", {}).get("reference_processing", {}).get("analysis", {}).get("settings", {}).get("damage_analysis", True) == True:
                    expected_outputs.append(f"{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/")
                else:
                    logging.info(f"Skipping damage analysis for species {species} and individual {individual} to reference {reference}. Disabled in config.")
            else:
                logging.info(f"Skipping analysis for species {species} and individual {individual} to reference {reference}. Disabled in config.")

            if config.get("pipeline", {}).get("reference_processing", {}).get("filter_unmapped_reads", {}).get("execute", False) == True:
                action = config.get("pipeline", {}).get("reference_processing", {}).get("filter_unmapped_reads", {}).get("settings", {}).get("action", "remove")
                if action in ("keep", "remove"):
                    # keep: unmapped reads stay in the final BAM (no extra output)
                    # remove: _mapped_only.bam is a temp intermediate; get_final_bam copies to _final.bam
                    pass
                elif action == "extract_fastq":
                    expected_outputs.append(f"{species}/processed/{reference}/unmapped/{individual}_{reference}_unmapped.fastq.gz")
                elif action == "extract_fasta":
                    expected_outputs.append(f"{species}/processed/{reference}/unmapped/{individual}_{reference}_unmapped.fasta.gz")
                else:
                    logging.warning(f"Unknown filter_unmapped_reads action '{action}' for {individual}/{reference}. Skipping.")
            else:
                logging.info(f"Skipping unmapped reads filtering for species {species}, individual {individual}, reference {reference}. Disabled in config.")

    return expected_outputs