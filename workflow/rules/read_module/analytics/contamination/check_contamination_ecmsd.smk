# Python helper functions for rules
# Naming of functions: <rule_name>_<rule_parameter>[_<rule_subparameter>]>
####################################################

def get_ecmsd_database(wildcards):
    configured_db = config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("database")
    if configured_db:
        return configured_db
    else:
        return "resources/ecmsd_database"

def get_ecmsd_taxonomic_hierarchy():
     return config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("taxonomic_hierarchy", "species")

_ecmsd_taxonomic_hierarchy = get_ecmsd_taxonomic_hierarchy()

_ecmsd_tax_hierarchy_readlength_output        = f"{{species}}/results/contamination_analysis/ecmsd/{{individual}}/{{sample}}/mapping/{{sample}}_Mito_summary_{_ecmsd_taxonomic_hierarchy}_ReadLengths.png"
_ecmsd_tax_hierarchy_proportions_png_output   = f"{{species}}/results/contamination_analysis/ecmsd/{{individual}}/{{sample}}/mapping/{{sample}}_Mito_summary_{_ecmsd_taxonomic_hierarchy}_Proportions.png"
_ecmsd_tax_hierarchy_proportions_txt_output   = f"{{species}}/results/contamination_analysis/ecmsd/{{individual}}/{{sample}}/mapping/{{sample}}_Mito_summary_{_ecmsd_taxonomic_hierarchy}_proportions.txt"
_ecmsd_tax_hierarchy_summary_txt_output       = f"{{species}}/results/contamination_analysis/ecmsd/{{individual}}/{{sample}}/mapping/{{sample}}_Mito_summary_{_ecmsd_taxonomic_hierarchy}.txt"

####################################################
# Snakemake rules
####################################################

rule ecmsd_database_setup:
    output:
        directory("resources/ecmsd_database")
    conda:
        "../../../../envs/ecmsd.yaml"
    message:
        "Setting up ECMSD database."
    shell:
        """
        ECMSD --create-db --db-folder "{output}"
        """

rule ecmsd_analyze_contamination:
    input:
        fastq = "{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered_final.fastq.gz",
        database = get_ecmsd_database
    output:
        summary                         = "{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/mapping/{sample}_Mito_summary.txt",
        paf                             = "{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/mapping/{sample}_Mito.paf.gz",
        coverage                        = "{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/mapping/{sample}_Mito_coverage.txt",
        ranked_summary                  = "{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/mapping/{sample}_Mito_summary.ref_summary.txt",
        tax_hierarchy_proportions       = _ecmsd_tax_hierarchy_proportions_txt_output,
        tax_hierarchy_summary           = _ecmsd_tax_hierarchy_summary_txt_output,
        tax_hierarchy_readlength        = _ecmsd_tax_hierarchy_readlength_output,
        tax_hierarchy_proportions_png   = _ecmsd_tax_hierarchy_proportions_png_output,
    params:
        cov_threshold = config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("cov_threshold", 50),
        top_n = config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("top_n", 25),
        mapping_quality = config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("mapping_quality", 20),
        taxonomic_hierarchy = config.get("pipeline", {}).get("read_module", {}).get("contamination_analysis", {}).get("tools", {}).get("ecmsd", {}).get("settings", {}).get("taxonomic_hierarchy", "species"),
        prefix = "{sample}"
    threads: 15
    conda:
        "../../../../envs/ecmsd.yaml"
    message: "Running ECMSD contamination analysis for {input.fastq}"
    shell:
        """
        outdir=$(dirname "$(dirname "{output.summary}")")
        mkdir -p "$outdir"

        echo "Running ECMSD for sample {wildcards.sample}"
        echo "Input FASTQ: {input.fastq}"
        echo "Output folder: $outdir"

        ECMSD \
            --fwd "{input.fastq}" \
            --out "$outdir" \
            --threads {threads} \
            --prefix "{params.prefix}" \
            --cov-threshold {params.cov_threshold} \
            --top-n {params.top_n} \
            --mapping_quality {params.mapping_quality} \
            --taxonomic-hierarchy "{params.taxonomic_hierarchy}" \
            --db-folder "{input.database}" \
            --force
        """

rule ecmsd_merge_hits_per_individual:
    input:
        lambda wildcards: expand(_ecmsd_tax_hierarchy_proportions_txt_output,
            sample=get_samples_for_species_individual(wildcards.species, wildcards.individual),
            species=wildcards.species,
            individual=wildcards.individual
            )
    output:
        "{species}/results/contamination_analysis/ecmsd/{individual}_Mito_summary_hits_combined.tsv"
    params:
        taxonomic_hierarchy = _ecmsd_taxonomic_hierarchy
    script:
        "../../../../scripts/read_module/analytics/contamination/check_contamination_ecmsd_script_ecmsd_merge_hits_per_individual.py"

rule ecmsd_analyze_proportions:
    input:
        report = _ecmsd_tax_hierarchy_proportions_txt_output,
        count_reads = "{species}/processed/reads_module/statistics/{sample}_quality_filtered.count"
    output:
        "{species}/results/contamination_analysis/ecmsd/{individual}/{sample}/pipeline/{sample}_ecmsd_proportions.tsv"
    params:
        sample = "{sample}"
    script:
        "../../../../scripts/read_module/analytics/contamination/check_contamination_ecmsd_script_ecmsd_analyze_proportions.py"
