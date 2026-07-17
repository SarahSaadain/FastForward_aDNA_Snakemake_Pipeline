
####################################################
# Helper functions
####################################################

def _scg_ranking_input_stats(wildcards):
    """Collect per-individual SCG stats JSON files for ranking."""
    individuals = get_individuals_for_species(wildcards.species)
    return expand(
        "{species}/processed/dynamics/scg/stats/{individual}_scg_stats.json",
        species=wildcards.species,
        individual=individuals
    )

####################################################
# Snakemake rules
####################################################

rule compute_scg_stats_for_bam:
    input:
        bam="{species}/processed/dynamics/scg/reads_mapped/{individual}_scg_library.sorted.bam",
        bai="{species}/processed/dynamics/scg/reads_mapped/{individual}_scg_library.sorted.bam.bai"
    output:
        stats="{species}/processed/dynamics/scg/stats/{individual}_scg_stats.json"
    log:
        "{species}/processed/dynamics/scg/stats/{individual}_scg_stats.log"
    message: "Computing SCG coverage stats for {wildcards.individual} of {wildcards.species}"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/dynamics/scg/compute_scg_stats_for_bam.py"

# Ranking TSV/JSON go to results/ — they are primary outputs the user cares about
rule determine_scg_ranking:
    input:
        stats=_scg_ranking_input_stats
    output:
        ranked_tsv="{species}/results/dynamics/scg/{species}_scg_ranked.tsv",
        ranked_json="{species}/results/dynamics/scg/{species}_scg_ranked.json"
    log:
        "{species}/results/dynamics/scg/{species}_scg_ranked.log"
    message: "Ranking SCGs across individuals for {wildcards.species}"
    conda:
        "../../../envs/python_and_r.yaml"
    script:
        "../../../scripts/dynamics/scg/determine_scg_ranking.py"

# Intermediate selection files stay in processed/
rule filter_top_scgs:
    input:
        ranked_scgs="{species}/results/dynamics/scg/{species}_scg_ranked.tsv"
    output:
        relevant_contigs="{species}/processed/dynamics/scg/{species}_relevant_scg.txt",
        relevant_contigs_bed="{species}/processed/dynamics/scg/{species}_relevant_scg.bed"
    params:
        num_top_scgs=lambda wildcards: (
            config.get("species", {}).get(wildcards.species, {}).get("scg_selector", {}).get("settings", {}).get("num_top_scgs")
            or config.get("pipeline", {}).get("dynamics", {}).get("scg_selector", {}).get("settings", {}).get("num_top_scgs", 20)
        )
    message: "Selecting top {params.num_top_scgs} SCGs for {wildcards.species}"
    shell:
        """
        awk 'NR>1 && NR<={params.num_top_scgs}+1 {{print $1}}' "{input.ranked_scgs}" | sort -u > "{output.relevant_contigs}"
        awk '{{print $1 "\t0\t1000000000"}}' "{output.relevant_contigs}" | sort -u > "{output.relevant_contigs_bed}"
        """

# The filtered FASTA stays in processed/ — it feeds into the seqvista prepare_libraries pipeline
rule filter_scg_fasta:
    input:
        fasta="{species}/processed/dynamics/scg/{species}_scg_library.fasta",
        id_list="{species}/processed/dynamics/scg/{species}_relevant_scg.txt"
    output:
        filtered="{species}/processed/dynamics/scg/{species}_relevant_scg.fasta"
    message: "Filtering SCG FASTA to top-ranked sequences for {wildcards.species}"
    run:
        with open(input.id_list) as f:
            ids_to_keep = set(line.strip() for line in f if line.strip())

        with open(input.fasta) as fin, open(output.filtered, "w") as fout:
            write = False
            for line in fin:
                if line.startswith(">"):
                    seq_id = line[1:].split()[0].strip()
                    write = seq_id in ids_to_keep
                if write:
                    fout.write(line)
