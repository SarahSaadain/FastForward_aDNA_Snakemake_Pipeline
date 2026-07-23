####################################################
# Snakemake rules
####################################################

rule normalize_visualization_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    output:
        normalized=temp("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv")
    conda:
        "../../envs/reveal_module.yaml"
    params:
        end_distance     = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("normalization", {}).get("settings", {}).get("end_distance", 100),
        exclude_quantile = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("normalization", {}).get("settings", {}).get("exclude_quantile", 25)
    message:
        "Normalizing REVEAL coverage for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL normalize \
            --so "{input.coverage}" \
            --outfile "{output.normalized}" \
            --end-distance {params.end_distance} \
            --exclude-quantile {params.exclude_quantile}
        """

rule compress_visualization_coverage_normalized_of_individual:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL normalized output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""
