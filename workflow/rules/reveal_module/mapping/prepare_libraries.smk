####################################################
# Python helper functions for rules
####################################################

_comp_execute = config.get("pipeline", {}).get("reveal_module", {}).get("mapping", {}).get("settings", {}).get("competitive_mapping", False)


def get_competition_fasta_input(wildcards):
    path = get_competition_fasta_for_species(wildcards.species)
    if not path:
        raise ValueError(
            f"pipeline.reveal_module.mapping.competitive_mapping.execute is true, but no competition "
            f"FASTA was found in '{wildcards.species}/input/reveal_module/competition/' for species "
            f"'{wildcards.species}'. Place exactly one FASTA file there to use competitive mapping."
        )
    return path


def _comp_library_input(wildcards):
    if _comp_execute:
        return f"{wildcards.species}/processed/reveal_module/competition/competition.suffixed.fasta"
    return []


def clean_scg_library_name_input(wildcards):
    """
    Return the FASTA path for the SCG library: user-provided if available,
    otherwise the auto-determined path produced by the SCG selector.
    """
    species = wildcards.species
    scg_library = wildcards.scg_library

    # Try user-provided SCG library first
    try:
        scg_library_path = get_scg_library_file_for_species_and_library(species, scg_library)
        return scg_library_path
    except Exception:
        pass

    # Fall back to auto-determined SCG output
    auto_id = get_effective_scg_library_id_for_species(species)
    if scg_library == auto_id:
        return f"{species}/processed/reveal_module/scg/{species}_relevant_scg.fasta"

    raise ValueError(f"No SCG library file could be determined for species {species} and library {scg_library}.")


def clean_feature_library_name_input(wildcards):
    """
    Return the full path to the FASTA file for this feature library.
    """
    species = wildcards.species
    feature_library = wildcards.feature_library

    feature_library_path = get_feature_library_file_for_species_and_library(species, feature_library)

    if not feature_library_path:
        raise ValueError(f"No feature library file could be determined for species {species} and library {feature_library}.")

    return feature_library_path

####################################################
# Snakemake rules
####################################################

rule clean_feature_library_name:
    input:
        clean_feature_library_name_input
    output:
        temp("{species}/processed/reveal_module/{feature_library}/library/{feature_library}.clean.fasta")
    conda:
        "../../../envs/python_and_r.yaml"
    message: "Preparing TE library for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/{feature_library}/library/{feature_library}.clean.log"
    shell:
        """
        ln -sf "$(realpath "{input}")" "{output}" > "{log}" 2>&1
        """

rule prepare_feature_library:
    input:
        "{species}/processed/reveal_module/{feature_library}/library/{feature_library}.clean.fasta"
    output:
        temp("{species}/processed/reveal_module/{feature_library}/library/{feature_library}.suffixed.fasta")
    conda:
        "../../../envs/python_and_r.yaml"
    message: "Preparing TE library for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/{feature_library}/library/{feature_library}.suffixed.log"
    shell:
        # remove trailing whitespace from headers and append _fle to each header
        """
        sed -E '/^>/ s/[[:space:]]//g; /^>/ s/(_fle)?$/_fle/' "{input}" > "{output}" 2> "{log}"
        """

rule clean_scg_library_name:
    input:
        clean_scg_library_name_input
    output:
        temp("{species}/processed/reveal_module/scg/library/{scg_library}.clean.fasta")
    conda:
        "../../../envs/python_and_r.yaml"
    message: "Preparing SCG library for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/scg/library/{scg_library}.clean.log"
    shell:
        """
        ln -sf "$(realpath "{input}")" "{output}" > "{log}" 2>&1
        """

rule prepare_scg_library:
    input:
        "{species}/processed/reveal_module/scg/library/{scg_library}.clean.fasta"
    output:
        temp("{species}/processed/reveal_module/scg/library/{scg_library}.suffixed.fasta")
    conda:
        "../../../envs/python_and_r.yaml"
    message: "Preparing SCG library for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/scg/library/{scg_library}.suffixed.log"
    shell:
        # remove trailing whitespace from headers and append _scg to each header
        """
        sed -E '/^>/ s/[[:space:]]//g; /^>/ s/(_scg)?$/_scg/' "{input}" > "{output}" 2> "{log}"
        """

if _comp_execute:
    rule create_no_comp_library:
        input:
            "{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta"
        output:
            "{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.no_comp.suffixed.fasta"
        message: "Removing competition sequences from combined library for REVEAL ({wildcards.species})"
        shell:
            # Skip any FASTA entry whose header ends in _comp (header + its sequence lines)
            """
            awk -f workflow/scripts/reveal_module/mapping/filter_out_comp_fasta_entries.awk "{input}" > "{output}"
            """

    rule prepare_competition_library:
        input:
            get_competition_fasta_input
        output:
            temp("{species}/processed/reveal_module/competition/competition.suffixed.fasta")
        message: "Preparing competition library for {wildcards.species}"
        shell:
            # remove trailing whitespace from headers and append _comp to each header
            """
            sed -E '/^>/ s/[[:space:]]//g; /^>/ s/(_comp)?$/_comp/' "{input}" > "{output}"
            """

rule combine_scg_and_ref_library:
    input:
        scg=lambda wildcards: f"{wildcards.species}/processed/reveal_module/scg/library/{get_effective_scg_library_id_for_species(wildcards.species)}.suffixed.fasta",
        fl="{species}/processed/reveal_module/{feature_library}/library/{feature_library}.suffixed.fasta",
        comp=_comp_library_input
    output:
        library="{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta"
    conda:
        "../../../envs/python_and_r.yaml"
    message: "Concatenating SCG and Feature libraries for {wildcards.species}"
    log:
        "{species}/processed/reveal_module/{feature_library}/library/{feature_library}_and_scg.suffixed.log"
    shell:
        """
        cat "{input.scg}" "{input.fl}" {input.comp} > "{output.library}" 2> "{log}"
        """
