####################################################
# Snakemake rules
####################################################

rule prepare_visualization_plotables_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        plotable=temp(directory("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plotable"))
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Preparing REVEAL visualization for {wildcards.individual} of {wildcards.species}."
    params:
        bin_size = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("visualization", {}).get("settings", {}).get("visualization_bin_size", "target:5000")
    shell:
        """
        REVEAL so2plotable \
            --so "{input.coverage}" \
            --outdir "{output.plotable}" \
            --bin-size "{params.bin_size}" \
            --seq-ids ALL \
            --sample-id "{wildcards.individual}"
        """

rule run_visualization_plots_of_individual:
    input:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plotable"
    output:
        directory("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plots")
    conda:
        "../../envs/reveal_module.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("visualization", {}).get("settings", {}).get("y_axis_log_scale_threshold_individual", 25)
    message:
        "Running REVEAL visualization for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL plot --folder "{input}" --outdir "{output}"  --log {params.log_threshhold}  --threads {threads}
        """

rule run_visualization_plots_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plotable",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        plots=directory("{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_plots_facet"),
        merged=temp(directory("{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_plotables_facet")),
    conda:
        "../../envs/reveal_module.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("reveal_module", {}).get("visualization", {}).get("settings", {}).get("y_axis_log_scale_threshold_species", 25)
    message:
        "Running REVEAL visualization for {wildcards.species}."
    shell:
        """
        REVEAL plot --folders {input} --outdir "{output.plots}" --merged-dir "{output.merged}" --log {params.log_threshhold} --threads {threads}
        """

rule compress_visualization_plotable_of_individual:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plotable",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_plotable.tar.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL plotables of individual for {wildcards.individual} of {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""

rule compress_visualization_plotable_of_species:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_plotables_facet"
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_plotables_facet.tar.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL plotables of species for {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""
