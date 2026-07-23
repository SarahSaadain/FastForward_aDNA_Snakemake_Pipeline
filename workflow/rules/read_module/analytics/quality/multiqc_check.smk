####################################################
# Python helper functions for rules
# Naming of functions: <rule_name>_<rule_parameter>[_<rule_subparameter>]>
####################################################

def run_multiqc_raw_input(wildcards):
    return get_expected_output_fastqc_raw(wildcards.species)

def run_multiqc_trimmed_input(wildcards):
    return get_expected_output_fastqc_trimmed(wildcards.species)

def run_multiqc_quality_filtered_input(wildcards):
    return get_expected_output_fastqc_quality_filtered(wildcards.species)

def run_multiqc_merged_input(wildcards):
    return get_expected_output_fastqc_merged(wildcards.species)

####################################################
# Snakemake rules
####################################################

# Rule: Run MultiQC on raw FastQC outputs
rule run_multiqc_raw:
    input:
        run_multiqc_raw_input
    output:
        "{species}/results/reads/{species}_multiqc_raw.html"
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
    log:
        "{species}/processed/reads/{species}_multiqc_raw.log"
    message: "Running MultiQC on raw FastQC outputs for species {wildcards.species}"
    wrapper:
        "v9.3.0/bio/multiqc"

# Rule: Run MultiQC on trimmed FastQC outputs
rule run_multiqc_trimmed:
    input:
        run_multiqc_trimmed_input
    output:
        "{species}/results/reads/{species}_multiqc_trimmed.html"
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
    log:
        "{species}/processed/reads/{species}_multiqc_trimmed.log"
    message: "Running MultiQC on trimmed FastQC outputs for species {wildcards.species}"
    wrapper:
        "v9.3.0/bio/multiqc"

# Rule: Run MultiQC on quality-filtered FastQC outputs
rule run_multiqc_quality_filtered:
    input:
        run_multiqc_quality_filtered_input
    output:
        "{species}/results/reads/{species}_multiqc_quality_filtered.html"
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
    log:
        "{species}/processed/reads/{species}_multiqc_quality_filtered.log"
    message: "Running MultiQC on quality-filtered FastQC outputs for species {wildcards.species}"
    wrapper:
        "v9.3.0/bio/multiqc"

# Rule: Run MultiQC on merged FastQC outputs
rule run_multiqc_merged:
    input:
        run_multiqc_merged_input
    output:
        "{species}/results/reads/{species}_multiqc_merged.html"
    params:
        extra="--verbose",  # Optional: extra parameters for multiqc.
    log:
        "{species}/processed/reads/{species}_multiqc_merged.log"
    message: "Running MultiQC on merged FastQC outputs for species {wildcards.species}"
    wrapper:
        "v9.3.0/bio/multiqc"