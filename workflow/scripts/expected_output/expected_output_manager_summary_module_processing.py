def get_expected_output_summary_processing(species):
    expected_output = []

    if config.get("pipeline", {}).get("summary_processing", {}).get("execute", True) == False:
        logging.info(f"Skipping summary processing for {species}. Disabled in config.")
        return expected_output

    if config.get("pipeline", {}).get("summary_processing", {}).get("settings", {}).get("species_multiqc", True) == True:
        expected_output.append(f"{species}/results/summary/species_level/{species}_multiqc.overall.html")

    if config.get("pipeline", {}).get("summary_processing", {}).get("settings", {}).get("individual_multiqc", True) == True:
        for individual in get_individuals_for_species(species):
            expected_output.append(f"{species}/results/summary/individual_level/{individual}_multiqc.html")

    return expected_output