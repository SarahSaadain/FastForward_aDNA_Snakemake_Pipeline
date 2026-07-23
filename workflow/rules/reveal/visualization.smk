####################################################
# Python helper functions for rules
####################################################

_comp_execute = config.get("pipeline", {}).get("reveal", {}).get("mapping", {}).get("settings", {}).get("competitive_mapping", False)


def _visualization_fasta_input(wildcards):

    species = wildcards.species
    feature_library = wildcards.feature_library

    if _comp_execute:
        return (f"{species}/processed/reveal/{feature_library}/library/{feature_library}_and_scg.no_comp.suffixed.fasta")
    return (f"{species}/processed/reveal/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta")


def combine_visualizations_for_species_input_coverage_files(wildcards):
    species = wildcards.species
    feature_library = wildcards.feature_library

    individuals = get_individuals_for_species(species)

    list_of_visualization_files_of_individuals = []

    for individual in individuals:
        list_of_visualization_files_of_individuals.append(f"{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_estimation.tsv")

    if not list_of_visualization_files_of_individuals:
        raise ValueError(f"No visualization files could be determined for species {species}.")

    return list_of_visualization_files_of_individuals

def combine_visualization_coverage_stats_across_feature_libraries_input(wildcards):
    feature_libraries = get_feature_library_ids_for_species(wildcards.species)
    return expand(
        "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
        species=wildcards.species,
        feature_library=feature_libraries
    )

####################################################
# Snakemake rules
####################################################

rule determine_visualization_of_individual_bam_to_so:
    input:
        bam="{species}/processed/reveal/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam",
        fasta=_visualization_fasta_input
    output:
        coverage=temp("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.tsv")
    log:
        "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_bam2so.log"
    conda:
        "../../envs/reveal.yaml"
    params:
        mapqth    = lambda _: config.get("pipeline", {}).get("reveal", {}).get("sequence_overview", {}).get("settings", {}).get("mapping_quality_threshold", 5),
        mc_snp    = lambda _: config.get("pipeline", {}).get("reveal", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_count_snp", 5),
        mf_snp    = lambda _: config.get("pipeline", {}).get("reveal", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_frequency_snp", 0.1),
        mc_indel  = lambda _: config.get("pipeline", {}).get("reveal", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_count_indel", 3),
        mf_indel  = lambda _: config.get("pipeline", {}).get("reveal", {}).get("sequence_overview", {}).get("settings", {}).get("minimum_frequency_indel", 0.01)
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

rule normalize_visualization_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    output:
        normalized=temp("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv")
    conda:
        "../../envs/reveal.yaml"
    params:
        end_distance     = lambda _: config.get("pipeline", {}).get("reveal", {}).get("normalization", {}).get("settings", {}).get("end_distance", 100),
        exclude_quantile = lambda _: config.get("pipeline", {}).get("reveal", {}).get("normalization", {}).get("settings", {}).get("exclude_quantile", 25)
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

rule estimate_visualization_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    output:
        estimation=temp("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_estimation.tsv")
    conda:
        "../../envs/reveal.yaml"
    message:
        "Estimating REVEAL coverage for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL estimate --so "{input.coverage}" --outfile "{output.estimation}"
        """

rule prepare_visualization_plotables_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        plotable=temp(directory("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plotable"))
    conda:
        "../../envs/reveal.yaml"
    message:
        "Preparing REVEAL visualization for {wildcards.individual} of {wildcards.species}."
    params:
        bin_size = lambda _: config.get("pipeline", {}).get("reveal", {}).get("visualization", {}).get("settings", {}).get("visualization_bin_size", "target:5000")
    shell:
        """
        REVEAL so2plotable \
            --so "{input.coverage}" \
            --outdir "{output.plotable}" \
            --bin-size "{params.bin_size}" \
            --seq-ids ALL \
            --sample-id "{wildcards.individual}"
        """

rule calculate_visualization_normalized_stats_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv"
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating normalized stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL covstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule calculate_visualization_snp_stats_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv")
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating SNP stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL snpstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule calculate_visualization_indel_stats_of_individual:
    input:
        coverage="{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv")
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating indel stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL indelstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule compare_visualization_stats_accross_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        stats=temp("{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv"),
    conda:
        "../../envs/reveal.yaml"
    message:
        "Running REVEAL coverage comparison for {wildcards.species}."
    shell:
        """
        REVEAL covcompare --stats {input} --outfile "{output.stats}"
        """

rule compare_visualization_snp_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv"),
    conda:
        "../../envs/reveal.yaml"
    message:
        "Comparing SNP stats across individuals of {wildcards.species}."
    shell:
        """
        REVEAL snpcompare \
            --snpstats {input} \
            --outfile "{output.comparison}"
        """

rule compare_visualization_indel_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv"),
    conda:
        "../../envs/reveal.yaml"
    message:
        "Comparing indel stats across individuals of {wildcards.species}."
    shell:
        """
        REVEAL indelcompare \
            --indelstats {input} \
            --outfile "{output.comparison}"
        """

rule combine_visualization_stats_across_feature_libraries:
    input:
        combine_visualization_coverage_stats_across_feature_libraries_input
    output:
        combined="{species}/results/reveal/{species}_reveal_coverage_comparison.tsv"
    conda:
        "../../envs/python_and_r.yaml"
    message:
        "Combining REVEAL stats comparisons across all feature libraries for {wildcards.species}."
    run:
        import pandas as pd
        feature_libraries = get_feature_library_ids_for_species(wildcards.species)
        frames = []
        for feature_library, tsv_file in zip(feature_libraries, input):
            df = pd.read_csv(tsv_file, sep="\t")
            df.insert(0, "feature_library", feature_library)
            frames.append(df)
        pd.concat(frames, ignore_index=True).to_csv(output.combined, sep="\t", index=False)

rule run_visualization_plots_of_individual:
    input:
        "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plotable"
    output:
        directory("{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plots")
    conda:
        "../../envs/reveal.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("reveal", {}).get("visualization", {}).get("settings", {}).get("y_axis_log_scale_threshold_individual", 25)
    message:
        "Running REVEAL visualization for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL plot --folder "{input}" --outdir "{output}"  --log {params.log_threshhold}  --threads {threads}
        """

rule run_visualization_plots_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plotable",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        plots=directory("{species}/results/reveal/{feature_library}/visualization/species_level/{species}_plots_facet"),
        merged=temp(directory("{species}/results/reveal/{feature_library}/visualization/species_level/{species}_plotables_facet")),
    conda:
        "../../envs/reveal.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("reveal", {}).get("visualization", {}).get("settings", {}).get("y_axis_log_scale_threshold_species", 25)
    message:
        "Running REVEAL visualization for {wildcards.species}."
    shell:
        """
        REVEAL plot --folders {input} --outdir "{output.plots}" --merged-dir "{output.merged}" --log {params.log_threshhold} --threads {threads}
        """

rule compress_visualization_coverage_of_individual:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL coverage output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_coverage_normalized_of_individual:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL normalized output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_snp_stats_of_individual:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL SNP stats for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_indel_stats_of_individual:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL indel stats for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_coverage_comparison_of_species:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL coverage comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_snp_comparison_of_species:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL SNP comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_indel_comparison_of_species:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL indel comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_visualization_plotable_of_individual:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plotable",
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/individual_level/{individual}_plotable.tar.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL plotables of individual for {wildcards.individual} of {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""

rule compress_visualization_plotable_of_species:
    input:
        source = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_plotables_facet"
    output:
        target = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_plotables_facet.tar.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL plotables of species for {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""

rule extract_flagged_seqids:
    input:
        tsv = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    output:
        txt = "{species}/results/reveal/{feature_library}/visualization/species_level/{species}_{feature_library}_flagged_seqids.tsv"
    conda:
        "../../envs/python_and_r.yaml"
    run:
        import pandas as pd
        df = pd.read_csv(input.tsv, sep="\t")
        flagged = df[df["flag"].notna() & (df["flag"] != "")][["seqid", "flag"]]
        flagged.to_csv(output.txt, sep="\t", index=False)
