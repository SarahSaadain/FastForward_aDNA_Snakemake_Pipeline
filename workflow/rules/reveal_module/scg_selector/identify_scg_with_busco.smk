####################################################
# Snakemake rules
####################################################

def _scg_setting(wildcards, key, default):
    """Return pipeline-level reveal_module.scg_selector.settings.{key}, falling back to default."""
    return (
        config.get("pipeline", {})
              .get("reveal_module", {})
              .get("scg_selector", {})
              .get("settings", {})
              .get(key, default)
    )


def _get_busco_lineage(wildcards):
    lineage = config.get("species", {}).get(wildcards.species, {}).get("lineage")
    if lineage is None:
        raise ValueError(
            f"BUSCO lineage is required for species '{wildcards.species}' but was not provided. "
            f"Set species.{wildcards.species}.lineage in your config."
        )
    return lineage


rule prepare_scg_determination_reference:
    input:
        ref=lambda wildcards: get_scg_determination_reference_path(wildcards.species)
    output:
        ref_link=temp("{species}/processed/reveal_module/scg/ref/{species}_scg_ref.fasta")
    message: "Preparing reference genome for SCG determination for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/scg/ref/{species}_scg_ref.log"
    shell:
        """
        ln -sf "$(realpath "{input.ref}")" "{output.ref_link}" > "{log}" 2>&1
        """

rule run_busco_for_scg_determination:
    input:
        "{species}/processed/reveal_module/scg/ref/{species}_scg_ref.fasta"
    output:
        short_json="{species}/processed/reveal_module/scg/busco/short_summary.json",
        short_txt="{species}/processed/reveal_module/scg/busco/short_summary.txt",
        full_table="{species}/processed/reveal_module/scg/busco/full_table.tsv",
        miss_list="{species}/processed/reveal_module/scg/busco/busco_missing.tsv",
        out_dir=temp(directory("{species}/processed/reveal_module/scg/busco/output/")),
        dataset_dir=temp(directory("{species}/processed/reveal_module/scg/busco/busco_downloads")),
    log:
        "{species}/processed/reveal_module/scg/busco/busco.log",
    message: "Running BUSCO to identify single-copy genes for {wildcards.species}"
    params:
        mode="genome",
        lineage=lambda wildcards: _get_busco_lineage(wildcards),
        extra="",
    threads: 8
    wrapper:
        "v9.3.0/bio/busco"

rule prepare_scg_library_from_busco:
    input:
        busco_full_table="{species}/processed/reveal_module/scg/busco/full_table.tsv",
        ref_genome="{species}/processed/reveal_module/scg/ref/{species}_scg_ref.fasta"
    output:
        scg="{species}/processed/reveal_module/scg/{species}_scg_library.fasta"
    message: "Extracting SCG sequences from BUSCO results for {wildcards.species}"
    conda:
        "../../../envs/python_and_r.yaml"
    params:
        min_length_scg=lambda wildcards: _scg_setting(wildcards, "min_length_scg", 4000),
        max_length_scg=lambda wildcards: _scg_setting(wildcards, "max_length_scg", 8000)
    log:
        "{species}/processed/reveal_module/scg/{species}_scg_library.log"
    script:
        "../../../scripts/reveal_module/scg/get_scg_from_busco.py"
