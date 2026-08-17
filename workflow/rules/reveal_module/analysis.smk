####################################################
# Snakemake rules
####################################################


rule estimate_visualization_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.tsv.gz",
    output:
        estimation=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_estimation.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_estimation.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Estimating REVEAL coverage for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL estimate --so "{input.coverage}" --outfile "{output.estimation}" >"{log}" 2>&1
        """


rule calculate_visualization_normalized_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating normalized stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL covstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" >"{log}" 2>&1
        """


rule calculate_visualization_snp_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating SNP stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL snpstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" >"{log}" 2>&1
        """


rule calculate_visualization_indel_stats_of_individual:
    input:
        coverage="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.tsv.gz",
    output:
        stats=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Calculating indel stats for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        REVEAL indelstats \
            --so "{input.coverage}" \
            --outfile "{output.stats}" \
            --sample-id "{wildcards.individual}" >"{log}" 2>&1
        """


rule compare_visualization_stats_accross_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_coverage.normalized.stats.tsv",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species),
        ),
    output:
        stats=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Running REVEAL coverage comparison for {wildcards.species}."
    shell:
        """
        REVEAL covcompare --stats {input} --outfile "{output.stats}" >"{log}" 2>&1
        """


rule compare_visualization_snp_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species),
        ),
    output:
        comparison=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Comparing SNP stats across individuals of {wildcards.species}."
    shell:
        """
        REVEAL snpcompare \
            --snpstats {input} \
            --outfile "{output.comparison}" >"{log}" 2>&1
        """


rule compare_visualization_indel_stats_across_individuals_of_species:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz",
            species=wildcards.species,
            feature_library=wildcards.feature_library,
            individual=get_individuals_for_species(wildcards.species),
        ),
    output:
        comparison=temp(
            "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv"
        ),
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.log",
    conda:
        "../../envs/reveal.yaml"
    message:
        "Comparing indel stats across individuals of {wildcards.species}."
    shell:
        """
        REVEAL indelcompare \
            --indelstats {input} \
            --outfile "{output.comparison}" >"{log}" 2>&1
        """


rule combine_visualization_stats_across_feature_libraries:
    input:
        lambda wildcards: expand(
            "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
            species=wildcards.species,
            feature_library=get_feature_library_ids_for_species(wildcards.species),
        ),
    output:
        combined="{species}/results/reveal_module/{species}_reveal_coverage_comparison.tsv",
    log:
        "{species}/results/reveal_module/{species}_reveal_coverage_comparison.log",
    conda:
        "../../envs/python_and_r.yaml"
    params:
        feature_libraries=lambda wildcards: get_feature_library_ids_for_species(
            wildcards.species
        ),
    message:
        "Combining REVEAL stats comparisons across all feature libraries for {wildcards.species}."
    script:
        "../../scripts/reveal_module/combine_visualization_stats_across_feature_libraries.py"


rule extract_flagged_seqids:
    input:
        tsv="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
    output:
        txt="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_flagged_seqids.tsv",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_flagged_seqids.log",
    conda:
        "../../envs/python_and_r.yaml"
    script:
        "../../scripts/reveal_module/extract_flagged_seqids.py"


rule compress_visualization_snp_stats_of_individual:
    input:
        source="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv",
    output:
        target="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats.tsv.gz",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_snpstats_compress.log",
    conda:
        "../../envs/pigz.yaml"
    threads: 4
    message:
        "Compressing REVEAL SNP stats for {wildcards.individual} of {wildcards.species}"
    shell:
        'pigz -p {threads} -c "{input.source}" > "{output.target}" 2> "{log}"'


rule compress_visualization_indel_stats_of_individual:
    input:
        source="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv",
    output:
        target="{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats.tsv.gz",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/individual_level/{individual}_indelstats_compress.log",
    conda:
        "../../envs/pigz.yaml"
    threads: 4
    message:
        "Compressing REVEAL indel stats for {wildcards.individual} of {wildcards.species}"
    shell:
        'pigz -p {threads} -c "{input.source}" > "{output.target}" 2> "{log}"'


rule compress_visualization_coverage_comparison_of_species:
    input:
        source="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv",
    output:
        target="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison.tsv.gz",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_coverage_comparison_compress.log",
    conda:
        "../../envs/pigz.yaml"
    threads: 4
    message:
        "Compressing REVEAL coverage comparison for {wildcards.species}"
    shell:
        'pigz -p {threads} -c "{input.source}" > "{output.target}" 2> "{log}"'


rule compress_visualization_snp_comparison_of_species:
    input:
        source="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv",
    output:
        target="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison.tsv.gz",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_snp_comparison_compress.log",
    conda:
        "../../envs/pigz.yaml"
    threads: 4
    message:
        "Compressing REVEAL SNP comparison for {wildcards.species}"
    shell:
        'pigz -p {threads} -c "{input.source}" > "{output.target}" 2> "{log}"'


rule compress_visualization_indel_comparison_of_species:
    input:
        source="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv",
    output:
        target="{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison.tsv.gz",
    log:
        "{species}/results/reveal_module/{feature_library}/visualization/species_level/{species}_{feature_library}_indel_comparison_compress.log",
    conda:
        "../../envs/pigz.yaml"
    threads: 4
    message:
        "Compressing REVEAL indel comparison for {wildcards.species}"
    shell:
        'pigz -p {threads} -c "{input.source}" > "{output.target}" 2> "{log}"'
