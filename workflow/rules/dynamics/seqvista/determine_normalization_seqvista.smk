####################################################
# Python helper functions for rules
####################################################

_comp_execute = config.get("pipeline", {}).get("dynamics", {}).get("mapping", {}).get("settings", {}).get("competitive_mapping", False)


def _seqvista_fasta_input(wildcards):

    species = wildcards.species
    feature_library = wildcards.feature_library

    if _comp_execute:
        return (f"{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.no_comp.suffixed.fasta")
    return (f"{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta")


def combine_seqvistas_for_species_input_coverage_files(wildcards):
    species = wildcards.species
    feature_library = wildcards.feature_library

    individuals = get_individuals_for_species(species)

    list_of_seqvista_files_of_individuals = []

    for individual in individuals:
        list_of_seqvista_files_of_individuals.append(f"{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_estimation.tsv")

    if not list_of_seqvista_files_of_individuals:
        raise ValueError(f"No seqvista files could be determined for species {species}.")

    return list_of_seqvista_files_of_individuals

def combine_seqvista_coverage_stats_across_feature_libraries_input(wildcards):
    feature_libraries = get_feature_library_ids_for_species(wildcards.species)
    return expand(
        "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
        species=wildcards.species,
        feature_library=feature_libraries
    )

####################################################
# Snakemake rules
####################################################

rule determine_seqvista_of_individual_bam_to_so:
    input:
        bam="{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam",
        fasta=_seqvista_fasta_input
    output:
        coverage=temp("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.tsv")
    log:
        "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_bam2so.log"
    conda:
        "../../../envs/python_and_r.yaml"
    params:
        mapqth    = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("mapping_quality_threshold", 5),
        mc_snp    = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("minimum_count_snp", 5),
        mf_snp    = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("minimum_frequency_snp", 0.1),
        mc_indel  = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("minimum_count_indel", 3),
        mf_indel  = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("minimum_frequency_indel", 0.01)
    message:
        "Determining seqvista coverage for {wildcards.individual} of {wildcards.species} using bam2so."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/bam2so.py \
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

rule normalize_seqvista_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.tsv.gz"
    output:
        normalized=temp("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv")
    conda:
        "../../../envs/python_and_r.yaml"
    params:
        end_distance     = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("end_distance", 100),
        exclude_quantile = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("exclude_quantile", 25)
    message:
        "Normalizing seqvista coverage for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/normalize-so.py \
            --so "{input.coverage}" \
            --outfile "{output.normalized}" \
            --end-distance {params.end_distance} \
            --exclude-quantile {params.exclude_quantile}
        """

rule estimate_seqvista_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.tsv.gz"
    output:
        estimation=temp("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_estimation.tsv")
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Estimating seqvista for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/estimate-so.py --so "{input.coverage}" --outfile "{output.estimation}"
        """

rule prepare_seqvista_visualization_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        plotable=temp(directory("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plotable"))
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Preparing seqvista visualization for {wildcards.individual} of {wildcards.species}."
    params:
        bin_size = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("visualization_bin_size", "target:5000")
    shell:
        """
        python workflow/scripts/dynamics/seqvista/so2plotable.py \
            --so "{input.coverage}" \
            --outdir "{output.plotable}" \
            --bin-size "{params.bin_size}" \
            --seq-ids ALL \
            --sample-id "{wildcards.individual}"
        """

rule calculate_seqvista_normalized_stats_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.stats.tsv"
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Calculating normalized stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/so2covstats.py \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule calculate_seqvista_snp_stats_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_snpstats.tsv")
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Calculating SNP stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/so2snpstats.py \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule calculate_seqvista_indel_stats_of_individual:
    input:
        coverage="{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_indelstats.tsv")
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Calculating indel stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/so2indelstats.py \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}"
        """

rule compare_seqvista_stats_accross_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.stats.tsv",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        stats=temp("{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_coverage_comparison.tsv"),
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Running seqvista for {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/compare_covstats.py --stats {input} --outfile "{output.stats}"
        """

rule compare_seqvista_snp_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_snpstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_snp_comparison.tsv"),
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Comparing SNP stats across individuals of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/compare_snpstats.py \
            --snpstats {input} \
            --outfile "{output.comparison}"
        """

rule compare_seqvista_indel_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_indelstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_indel_comparison.tsv"),
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Comparing indel stats across individuals of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/compare_indelstats.py \
            --indelstats {input} \
            --outfile "{output.comparison}"
        """

rule combine_seqvista_stats_across_feature_libraries:
    input:
        combine_seqvista_coverage_stats_across_feature_libraries_input
    output:
        combined="{species}/results/dynamics/{species}_seqvista_coverage_comparison.tsv"
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Combining seqvista stats comparisons across all feature libraries for {wildcards.species}."
    run:
        import pandas as pd
        feature_libraries = get_feature_library_ids_for_species(wildcards.species)
        frames = []
        for feature_library, tsv_file in zip(feature_libraries, input):
            df = pd.read_csv(tsv_file, sep="\t")
            df.insert(0, "feature_library", feature_library)
            frames.append(df)
        pd.concat(frames, ignore_index=True).to_csv(output.combined, sep="\t", index=False)

rule run_seqvista_visualization_of_individual:
    input:
        "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plotable"
    output:
        directory("{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plots")
    conda:
        "../../../envs/python_and_r.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("y_axis_log_scale_threshold_individual", 25)
    message:
        "Running seqvista visualization for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/plot.py --folder "{input}" --outdir "{output}"  --log {params.log_threshhold}  --threads {threads}
        """

rule run_seqvista_visualization_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plotable",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        plots=directory("{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_plots_facet"),
        merged=temp(directory("{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_plotables_facet")),
    conda:
        "../../../envs/python_and_r.yaml"
    threads: 15
    params:
        log_threshhold = lambda _: config.get("pipeline", {}).get("dynamics", {}).get("seqvista", {}).get("settings", {}).get("y_axis_log_scale_threshold_species", 25)
    message:
        "Running seqvista visualization for {wildcards.species}."
    shell:
        """
        python workflow/scripts/dynamics/seqvista/plot.py --folders {input} --outdir "{output.plots}" --merged-dir "{output.merged}" --log {params.log_threshhold} --threads {threads}
        """

rule compress_seqvista_coverage_of_individual:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista coverage output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_coverage_normalized_of_individual:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_coverage.normalized.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista normalized output for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_snp_stats_of_individual:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_snpstats.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_snpstats.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista SNP stats for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_indel_stats_of_individual:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_indelstats.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_indelstats.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista indel stats for {wildcards.individual} of {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_coverage_comparison_of_species:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_coverage_comparison.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista coverage comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_snp_comparison_of_species:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_snp_comparison.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_snp_comparison.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista SNP comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_indel_comparison_of_species:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_indel_comparison.tsv",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_indel_comparison.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista indel comparison for {wildcards.species}"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\""

rule compress_seqvista_plotable_of_individual:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plotable",
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/individual_level/{individual}_plotable.tar.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista plotables of individual for {wildcards.individual} of {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""

rule compress_seqvista_plotable_of_species:
    input:
        source = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_plotables_facet"
    output:
        target = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_plotables_facet.tar.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing SeqVista plotables of species for {wildcards.species}"
    shell:
        "tar -c \"{input.source}\" | pigz -p {threads} > \"{output.target}\""

rule extract_flagged_seqids:
    input:
        tsv = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    output:
        txt = "{species}/results/dynamics/{feature_library}/seqvista/species_level/{species}_{feature_library}_flagged_seqids.tsv"
    conda:
        "../../../envs/python_and_r.yaml"
    run:
        import pandas as pd
        df = pd.read_csv(input.tsv, sep="\t")
        flagged = df[df["flag"].notna() & (df["flag"] != "")][["seqid", "flag"]]
        flagged.to_csv(output.txt, sep="\t", index=False)
