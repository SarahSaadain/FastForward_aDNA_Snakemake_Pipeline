####################################################
# Snakemake rules
####################################################

def prepare_custom_data_reads_processing_dedup(wildcards):

    if config.get("pipeline", {}).get("reference_processing", {}).get("execute", True) == False:
        return []
    
    if config.get("pipeline", {}).get("reference_processing", {}).get("deduplication", {}).get("execute", True) == True:
        return f"{wildcards.species}/results/{wildcards.reference}/analytics/individual_level/{wildcards.individual}/dedup/{wildcards.individual}_{wildcards.reference}_final.dedup.json"
    else:
        return []

def prepare_custom_data_reads_processing_endogenous(wildcards):
    
    if config.get("pipeline", {}).get("reference_processing", {}).get("execute", True) == True:
        #"{species}/results/{reference}/analytics/individual_level/{individual}/endogenous/{individual}_{reference}.endogenous.csv"
        return f"{wildcards.species}/results/{wildcards.reference}/analytics/individual_level/{wildcards.individual}/endogenous/{wildcards.individual}_{wildcards.reference}.endogenous.csv"
    else:
        return []

####################################################
# Snakemake rules
####################################################

rule prepare_custom_data_reads_processing_absolute_values:
    input:
        reads = "{species}/results/reads/statistics/{species}_reads_counts.csv",
        endogenous = prepare_custom_data_reads_processing_endogenous,
        dedup = prepare_custom_data_reads_processing_dedup
    output:
        "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv",
    conda:
        "../../../envs/python_and_r.yaml",
    params:
        individual="{individual}",
        reference="{reference}",
    script:
        "../../../scripts/processing_summary/prepare_custom_data_reads_processing.py"
        
rule combine_custom_data_reads_processing_absolute_values:
    input:
        lambda wildcards: expand(
            "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv",
            species=wildcards.species,
            reference=wildcards.reference,
            individual=get_individuals_for_species(wildcards.species),
        )
    output:
        "{species}/results/summary/species_level/{species}_overall/multiqc_custom_content/{species}_{reference}_reads_processing_summary_combined.tsv",
    conda:
        "../../../envs/python_and_r.yaml",
    run:
        import pandas as pd
        import os

        input_files = input
        output_file = output[0]

        combined_df = pd.DataFrame()

        for file in input_files:
            if os.path.exists(file):
                df = pd.read_csv(file, sep="\t")
                combined_df = pd.concat([combined_df, df], ignore_index=True)
            else:
                print(f"Warning: Input file {file} does not exist and will be skipped.")

        combined_df.to_csv(output_file, sep="\t", index=False)

rule prepare_custom_data_reads_processing_stacked_values:
    input:
        "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary.tsv",
    output:
        "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary_stacked.tsv",
    conda:
        "../../../envs/python_and_r.yaml",
    run:
        import pandas as pd

        input_file = input[0]
        output_file = output[0]

        df = pd.read_csv(input_file, sep="\t")

        df_out = pd.DataFrame()
        df_out["individual"] = df["individual"]

        # delta calculations
        #df_out["adapter_removed"] = df["raw_reads"] - df["after_adapter_removed"]
        #df_out["quality_filtered"] = df["after_adapter_removed"] - df["after_quality_filter"]
        df_out["non_endogenous"] = df["after_quality_filter"] - df["mapped_endogenous_reads"]
        df_out["duplicates"] = df["mapped_endogenous_reads"] - df["endogenous_duplicates_removed"]
        df_out["endogenous"] = df["endogenous_duplicates_removed"]

        #sort the columns: endogenous, duplicates, non_endogenous
        columns_order = ["individual", "endogenous", "duplicates", "non_endogenous"]
        df_out = df_out[columns_order]

        df_out.to_csv(output_file, sep="\t", index=False)

rule combine_custom_data_reads_processing_stacked_values:
    input:
        lambda wildcards: expand(
            "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_reads_processing_summary_stacked.tsv",
            species=wildcards.species,
            reference=wildcards.reference,
            individual=get_individuals_for_species(wildcards.species),
        )
    output:
        "{species}/results/summary/species_level/{species}_overall/multiqc_custom_content/{species}_{reference}_reads_processing_summary_stacked_combined.tsv",
    conda:
        "../../../envs/python_and_r.yaml",
    run:
        import pandas as pd
        import os

        input_files = input
        output_file = output[0]

        combined_df = pd.DataFrame()

        for file in input_files:
            if os.path.exists(file):
                df = pd.read_csv(file, sep="\t")
                combined_df = pd.concat([combined_df, df], ignore_index=True)
            else:
                print(f"Warning: Input file {file} does not exist and will be skipped.")

        #sort the columns: endogenous, duplicates, non_endogenous
        columns_order = ["individual", "endogenous", "duplicates", "non_endogenous"]
        combined_df = combined_df[columns_order]

        combined_df.to_csv(output_file, sep="\t", index=False)