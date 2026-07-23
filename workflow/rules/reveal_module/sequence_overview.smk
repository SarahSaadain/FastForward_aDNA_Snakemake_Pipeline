####################################################
# Python helper functions for rules
####################################################

_comp_execute = config.get("pipeline", {}).get("reveal_module", {}).get("mapping", {}).get("settings", {}).get("competitive_mapping", False)


def _visualization_fasta_input(wildcards):

    species = wildcards.species
    feature_library = wildcards.feature_library

    if _comp_execute:
        return (f"{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.no_comp.suffixed.fasta")
    return (f"{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta")

####################################################
# Snakemake rules
####################################################

rule determine_visualization_of_individual_bam_to_so:
    input:
        bam="{species}/processed/reveal_module/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam",
        fasta=_visualization_fasta_input
    output:
        coverage=temp("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv")
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_bam2so.log"
    conda:
        "../../envs/reveal_module.yaml"
    params:
        mapqth    = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("sequence_overview", {}).get("settings", {}).get("mapping_quality_threshold", 5),
        mc_snp    = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_count_snp", 5),
        mf_snp    = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_frequency_snp", 0.1),
        mc_indel  = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_count_indel", 3),
        mf_indel  = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_frequency_indel", 0.01)
    message:
        "Determining REVEAL coverage for {wildcards.individual} of {wildcards.species} using bam2so."
    shell:
        """
        REVEAL bam2so \
            --infile "{input.bam}" \
            --fasta "{input.fasta}" \
            --outfile "{output.coverage}" \
            --mapqth {params.mapqth} \
            --mc-snp {params.mc_snp} \
            --mf-snp {params.mf_snp} \
            --mc-indel {params.mc_indel} \
            --mf-indel {params.mf_indel} \
            2> "{log}"
        """

rule compress_visualization_coverage_of_individual:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL coverage output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""
