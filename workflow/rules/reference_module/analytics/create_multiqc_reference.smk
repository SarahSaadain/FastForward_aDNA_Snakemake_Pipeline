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
    conda:
        "../../../envs/python_and_r.yaml"
    log:
        "{species}/results/reference_module/{reference}/analytics/species_level/{species}_{reference}/{species}_{reference}_multiqc_config.log"
    script:
        "../../../scripts/summary_module/create_multiqc_species_individual_script_create_multiqc_species_individual_config.py"
