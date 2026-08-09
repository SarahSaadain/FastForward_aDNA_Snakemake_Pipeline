import textwrap

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
    conda:
        "../../envs/python_and_r.yaml"
    log:
        "{species}/results/summary/individual_level/{individual}/{individual}_multiqc_config.log"
    script:
        "../../scripts/summary_module/create_multiqc_species_individual_script_create_multiqc_species_individual_config.py"
        