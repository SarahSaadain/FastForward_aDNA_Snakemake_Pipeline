####################################################
# Python helper functions for rules
####################################################

def combine_visualizations_for_species_input_coverage_files(wildcards):
    species = wildcards.species
    feature_library = wildcards.feature_library

    individuals = get_individuals_for_species(species)

    list_of_visualization_files_of_individuals = []

    for individual in individuals:
        list_of_visualization_files_of_individuals.append(f"{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_estimation.tsv")

    if not list_of_visualization_files_of_individuals:
        raise ValueError(f"No visualization files could be determined for species {species}.")

    return list_of_visualization_files_of_individuals

def combine_visualization_coverage_stats_across_feature_libraries_input(wildcards):
    feature_libraries = get_feature_library_ids_for_species(wildcards.species)
    return expand(
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
        species=wildcards.species,
        feature_library=feature_libraries
    )

####################################################
# Snakemake rules
####################################################

rule estimate_visualization_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz"
    output:
        estimation=temp("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_estimation.tsv")
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Estimating REVEAL coverage for {wildcards.individual} of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_estimation.log"
    shell:
        """
        REVEAL estimate --so "{input.coverage}" --outfile "{output.estimation}" > "{log}" 2>&1
        """

rule calculate_visualization_normalized_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv"
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Calculating normalized stats for {wildcards.individual} of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.log"
    shell:
        """
        REVEAL covstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" > "{log}" 2>&1
        """

rule calculate_visualization_snp_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv")
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Calculating SNP stats for {wildcards.individual} of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.log"
    shell:
        """
        REVEAL snpstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" > "{log}" 2>&1
        """

rule calculate_visualization_indel_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp("{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv")
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Calculating indel stats for {wildcards.individual} of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.log"
    shell:
        """
        REVEAL indelstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" > "{log}" 2>&1
        """

rule compare_visualization_stats_accross_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        stats=temp("{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv"),
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Running REVEAL coverage comparison for {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.log"
    shell:
        """
        REVEAL covcompare --stats {input} --outfile "{output.stats}" > "{log}" 2>&1
        """

rule compare_visualization_snp_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv"),
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Comparing SNP stats across individuals of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.log"
    shell:
        """
        REVEAL snpcompare \
            --snpstats {input} \
            --outfile "{output.comparison}" > "{log}" 2>&1
        """

rule compare_visualization_indel_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species))
    output:
        comparison=temp("{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv"),
    conda:
        "../../envs/reveal_module.yaml"
    message:
        "Comparing indel stats across individuals of {wildcards.species}."
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.log"
    shell:
        """
        REVEAL indelcompare \
            --indelstats {input} \
            --outfile "{output.comparison}" > "{log}" 2>&1
        """

rule combine_visualization_stats_across_feature_libraries:
    input:
        combine_visualization_coverage_stats_across_feature_libraries_input
    output:
        combined="{species}/results/reveal_module/{species}_reveal_coverage_comparison.tsv"
    conda:
        "../../envs/python_and_r.yaml"
    message:
        "Combining REVEAL stats comparisons across all feature libraries for {wildcards.species}."
    log:
        "{species}/results/reveal_module/{species}_reveal_coverage_comparison.log"
    run:
        import pandas as pd
        feature_libraries = get_feature_library_ids_for_species(wildcards.species)
        frames = []
        for feature_library, tsv_file in zip(feature_libraries, input):
            df = pd.read_csv(tsv_file, sep="\t")
            df.insert(0, "feature_library", feature_library)
            frames.append(df)
        pd.concat(frames, ignore_index=True).to_csv(output.combined, sep="\t", index=False)

rule extract_flagged_seqids:
    input:
        tsv = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    output:
        txt = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_flagged_seqids.tsv"
    conda:
        "../../envs/python_and_r.yaml"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_flagged_seqids.log"
    run:
        import pandas as pd
        df = pd.read_csv(input.tsv, sep="\t")
        flagged = df[df["flag"].notna() & (df["flag"] != "")][["seqid", "flag"]]
        flagged.to_csv(output.txt, sep="\t", index=False)

rule compress_visualization_snp_stats_of_individual:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL SNP stats for {wildcards.individual} of {wildcards.species}"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats_compress.log"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\" 2> \"{log}\""

rule compress_visualization_indel_stats_of_individual:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL indel stats for {wildcards.individual} of {wildcards.species}"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats_compress.log"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\" 2> \"{log}\""

rule compress_visualization_coverage_comparison_of_species:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL coverage comparison for {wildcards.species}"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison_compress.log"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\" 2> \"{log}\""

rule compress_visualization_snp_comparison_of_species:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL SNP comparison for {wildcards.species}"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison_compress.log"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\" 2> \"{log}\""

rule compress_visualization_indel_comparison_of_species:
    input:
        source = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv",
    output:
        target = "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv.gz"
    threads: 4
    conda:
        "../../envs/pigz.yaml"
    message: "Compressing REVEAL indel comparison for {wildcards.species}"
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison_compress.log"
    shell:
        "pigz -p {threads} -c \"{input.source}\" > \"{output.target}\" 2> \"{log}\""
