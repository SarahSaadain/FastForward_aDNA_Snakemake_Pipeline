####################################################
# Python helper functions for rules
# Naming of functions: <rule_name>_<rule_parameter>[_<rule_subparameter>]>
####################################################

def merge_reads_by_individual_input(wildcards):

    species = wildcards.species
    individual = wildcards.individual

    samples_of_individual = get_samples_for_species_individual(species, individual)   
    
    if len(samples_of_individual) == 0:
        logger.info(f"Requested individual: {individual}")
        logger.error(f"No raw read files found for individual {individual}. Check that the individual ID is correct and that raw read files are present.")
        raise Exception(f"No raw read files found for individual {individual}. Check that the individual ID is correct and that raw read files are present.")
    
    # for each raw R1 file, generate the corresponding quality-filtered filename
    quality_filtered_files = []
    for sample in samples_of_individual:
        qf_file = f"{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered_final.fastq.gz"
        quality_filtered_files.append(qf_file)
    
    return quality_filtered_files

####################################################
# Snakemake rules
####################################################

# Rule: Merge quality-filtered reads by individual
rule merge_reads_by_individual:
    input:
        merge_reads_by_individual_input
    output:
        "{species}/processed/reads_module/reads_merged/{individual}.fastq.gz"
    log:
        "{species}/processed/reads_module/reads_merged/{individual}_merge_reads.log"
    message: 
        "Merging individual {wildcards.individual} of species {wildcards.species}."
    shell:
        """
        echo "Merging quality-filtered reads for individual {wildcards.individual} of species {wildcards.species}..." > "{log}"
        echo "Input files:" >> "{log}"
        for f in {input}; do
            echo "  $f" >> "{log}"
        done
        echo "Output file: {output}" >> "{log}"

        cat {input} > "{output}"
        echo "Merging completed for individual {wildcards.individual} of species {wildcards.species}." >> "{log}"
        """
