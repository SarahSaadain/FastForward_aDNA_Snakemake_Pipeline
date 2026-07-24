
import os
import glob
import re
from venv import logger

# Raised when the config requests individuals or references that do not exist on disk.
# Unlike generic discovery failures, these must not be silently caught.
class ConfigValidationError(Exception):
    pass

# -----------------------------------------------------------------------------------------------
# Read the config filter lists for a given species and key (e.g. "individuals", "references").
# Returns None when the key is absent/empty (meaning "use all").
def _get_species_config_list(species, key):
    try:
        value = config.get("species", {}).get(species, {}).get(key)
    except NameError:
        return None
    if not value:
        return None
    return list(value)

# -----------------------------------------------------------------------------------------------
# Get all files in a folder matching a specific pattern (e.g., *.fastq.gz)
def get_files_in_folder_matching_pattern(folder: str, pattern: str) -> list:
    # Check if the folder exists
    if not os.path.exists(folder):
        logger.warning(f"Invalid folder: {folder}")
        raise Exception(f"Invalid folder: {folder}")
    # Read all files matching the pattern into a list
    files = glob.glob(os.path.join(folder, pattern))
    return files

# -----------------------------------------------------------------------------------------------
# Get all raw read files for a given species    
def get_read_files_for_species(species: str) -> list[str]:

    read_folder = f"{species}/input/reads_module"

    try:   
        logger.debug(f"Looking for read files in {read_folder} for species {species}.")
        read_files = get_files_in_folder_matching_pattern(read_folder, "*.fastq.gz")
    except Exception as e:  
        # Try looking in species folder directly as fallback.
        logger.debug(f"Read folder not found for species {species}. Trying species folder directly.")
        read_files = get_files_in_folder_matching_pattern(species, "*.fastq.gz")
        
    if len(read_files) == 0:
        logger.warning(f"No read files found for species {species}. Make sure the files are named with the pattern <Individual>*R[1,2]*.fastq.gz and are located in either {read_folder} or {species}.")
        raise Exception(f"No read files found for species {species}. Make sure the files are named with the pattern <Individual>*R[1,2]*.fastq.gz and are located in either {read_folder} or {species}.")
    
    logger.debug(f"Read files for species {species}: {read_files}")
        
    return read_files

# -----------------------------------------------------------------------------------------------
# Get only R1 raw read files for a given species
def get_r1_read_files_for_species(species: str) -> list[str]:
    files = get_read_files_for_species(species)
    
    # since R1 and R2 files should always come in pairs, if there are no R1 files, 
    # then there is probably something wrong with the file structure or naming. 
    # Besides R1/R2, the name of the read files should be the same, 
    # so we can just check for R1 files to build the list of samples and 
    # individuals for a species. 

    r1_files = [f for f in files if "_R1" in os.path.basename(f)]

    if len(r1_files) == 0:
        logger.warning(f"No R1 read files found for species {species}. Make sure the files are named with the pattern <Individual>*R[1,2]*.fastq.gz.")
        logger.warning(f"Available read files for species {species}: {files}")
        raise Exception(f"No R1 read files found for species {species}. Make sure the files are named with the pattern <Individual>*R[1,2]*.fastq.gz.")
    
    logger.debug(f"R1 read files for species {species}: {r1_files}")
    
    return r1_files

# -----------------------------------------------------------------------------------------------
# Get sample IDs for a species based on raw read filenames
def get_sample_ids_for_species(species):
    files = get_r1_read_files_for_species(species)

    samples = []
    for raw_file in files:
        filename = os.path.basename(raw_file).replace('.fastq.gz','').split("_R1")[0]
        samples.append(filename)
    
    logger.debug(f"Sample IDs for species {species}: {samples}")

    if len(samples) == 0:
        logger.warning(f"No sample IDs found for species {species}.")
        raise Exception(f"No sample IDs found for species {species}.")
    
    return samples

def get_raw_reads_for_sample(species, sample):

    read_files = get_read_files_for_species(species) 
    
    # turn read paths into file names only
    read_files = [os.path.basename(f) for f in read_files]

    reads_dir = f"{species}/input/reads_module"
 
    # R1
    base_r1 = f"{sample}_R1"
    candidates_r1 = [f for f in read_files
                     if re.match(base_r1 + r"(\S*)?\.fastq\.gz", f)]
    
    if not candidates_r1:
        logger.warning(f"No R1 found for {sample}. Expected pattern: {base_r1}*.fastq.gz in {reads_dir}. Found files: {read_files}")
        raise FileNotFoundError(f"No R1 found for {sample}. Expected pattern: {base_r1}*.fastq.gz in {reads_dir}. Found files: {read_files}")

    r1 = os.path.join(reads_dir, sorted(candidates_r1)[0])
 
    # R2
    base_r2 = f"{sample}_R2"
    candidates_r2 = [f for f in read_files
                     if re.match(base_r2 + r"(\S*)?\.fastq\.gz", f)]
 
    if candidates_r2:
        r2 = os.path.join(reads_dir, sorted(candidates_r2)[0])
        return [r1, r2]  # Paired-end
    else:
        return [r1]      # Single-end

# -----------------------------------------------------------------------------------------------
# (internal) Discover all individuals from disk without applying any config filter
def _discover_all_individuals_for_species(species):
    samples = get_sample_ids_for_species(species)
    if len(samples) == 0:
        logger.warning(f"No samples found for species {species}.")
        raise Exception(f"No samples found for species {species}.")
    individuals = set()
    for s in samples:
        individuals.add(get_individual_from_sample(s))
    logger.debug(f"Discovered individuals for species {species}: {individuals}")
    return sorted(list(individuals))

# -----------------------------------------------------------------------------------------------
# Get individual sample IDs for a given species based on raw read filenames.
# If config specifies an 'individuals' list for this species, only those are returned.
# Raises ConfigValidationError when a requested individual is not found on disk.
def get_individuals_for_species(species):
    all_individuals = _discover_all_individuals_for_species(species)

    requested = _get_species_config_list(species, "individuals")
    if requested is None:
        return all_individuals

    all_set = set(all_individuals)
    missing = [ind for ind in requested if ind not in all_set]
    if missing:
        raise ConfigValidationError(
            f"Species '{species}': the following individuals were requested in the config "
            f"but not found on disk: {missing}. "
            f"Available individuals: {sorted(all_set)}"
        )

    selected = [ind for ind in all_individuals if ind in set(requested)]
    logger.debug(f"Config-filtered individuals for species {species}: {selected}")
    return selected

# -----------------------------------------------------------------------------------------------
# (internal) Discover all reference files from disk without applying any config filter
def _discover_all_reference_file_list_for_species(species: str) -> list[tuple[str, str]]:
    species_folder = species
    reference_folder = f"{species}/input/reference_module"
    try:
        logger.debug(f"Looking for reference files in {reference_folder} for species {species}.")
        reference_files = get_files_in_folder_matching_pattern(reference_folder, "*.fna")
        reference_files += get_files_in_folder_matching_pattern(reference_folder, "*.fasta")
        reference_files += get_files_in_folder_matching_pattern(reference_folder, "*.fa")
    except Exception:
        logger.debug(f"Reference folder not found for species {species}. Trying species folder directly.")
        reference_files = get_files_in_folder_matching_pattern(species_folder, "*.fna")
        reference_files += get_files_in_folder_matching_pattern(species_folder, "*.fasta")
        reference_files += get_files_in_folder_matching_pattern(species_folder, "*.fa")

    if len(reference_files) == 0:
        raise Exception(f"No reference found for species {species}.")

    result = [(os.path.splitext(os.path.basename(f))[0].replace('.', '_'), f) for f in reference_files]
    logger.debug(f"Discovered reference files for species {species}: {result}")
    return result

# -----------------------------------------------------------------------------------------------
# Get reference files for a given species (supports .fna, .fasta, .fa).
# If config specifies a 'references' list for this species, only those are returned.
# Reference IDs are the filename stem with dots replaced by underscores
# (e.g. 'genome.fna' → 'genome', 'EquCab3.0.fna' → 'EquCab3_0').
# Raises ConfigValidationError when a requested reference ID is not found on disk.
def get_reference_file_list_for_species(species: str) -> list[tuple[str, str]]:
    all_refs = _discover_all_reference_file_list_for_species(species)

    requested = _get_species_config_list(species, "references")
    if requested is None:
        return all_refs

    all_map = {ref_id: ref_path for ref_id, ref_path in all_refs}
    missing = [ref_id for ref_id in requested if ref_id not in all_map]
    if missing:
        raise ConfigValidationError(
            f"Species '{species}': the following references were requested in the config "
            f"but not found on disk: {missing}. "
            f"Available reference IDs: {sorted(all_map.keys())}"
        )

    selected = [(ref_id, all_map[ref_id]) for ref_id in requested]
    logger.debug(f"Config-filtered references for species {species}: {selected}")
    return selected

# -----------------------------------------------------------------------------------------------
# Extract individual ID from a given file path or sample name
def get_individual_from_filepath(filepath):
    basename = os.path.basename(filepath)
    return get_individual_from_sample(basename)

# -----------------------------------------------------------------------------------------------
# Extract individual ID from a sample name
def get_individual_from_sample(sample):
    return sample.split("_")[0]

# -----------------------------------------------------------------------------------------------
# Get only reference file paths for a species
def get_references_paths_for_species(species):
    refs = get_reference_file_list_for_species(species)
    return [ref[1] for ref in refs]

# -----------------------------------------------------------------------------------------------
# Get only reference IDs for a species
def get_references_ids_for_species(species):
    refs = get_reference_file_list_for_species(species)
    return [ref[0] for ref in refs]

# -----------------------------------------------------------------------------------------------
# Get sample IDs for a specific individual within a species
def get_samples_for_species_individual(species, individual):
    samples = get_sample_ids_for_species(species)

    # Currently, a sample is everything before the first "_R1" or "_R2" in the filename.
    # The first part of the sample name (before the first "_") is considered the individual ID.
    # The sample might contain additional information after the individual ID, 
    # but we only want to match the samples with the individual ID at the start of the sample name.
    samples_of_individual = [f for f in samples if f.startswith(f"{individual}_")]

    # in case there is no additional information after the individual ID, 
    # the sample name will be the same as the individual ID.
    samples_of_individual += [f for f in samples if f == individual]

    logger.debug(f"Samples for individual {individual} in species {species}: {samples_of_individual}")

    if len(samples_of_individual) == 0:
        logger.warning(f"No samples found for individual {individual} in species {species}. Available samples: {samples}")
        raise Exception(f"No samples found for individual {individual} in species {species}.")
    
    return samples_of_individual

# -----------------------------------------------------------------------------------------------
# (internal) Discover all feature library files from disk without applying any config filter
def _discover_all_feature_library_file_list_for_species(species: str) -> list[tuple[str, str]]:
    species_folder = species
    feature_library_folder = f"{species_folder}/input/reveal_module/feature_library"
    library_files = []
    try:
        logger.debug(f"Looking for feature library files in {feature_library_folder} for species {species}.")
        library_files = get_files_in_folder_matching_pattern(feature_library_folder, "*.fna")
        library_files += get_files_in_folder_matching_pattern(feature_library_folder, "*.fasta")
        library_files += get_files_in_folder_matching_pattern(feature_library_folder, "*.fa")
    except Exception as e:
        logger.warning(f"Failed to find feature library files in {feature_library_folder} for species {species}. Exception: {e}")

    if len(library_files) == 0:
        raise Exception(f"No feature library files found for species {species}.")

    result = [(os.path.splitext(os.path.basename(f))[0].replace('.', '_'), f) for f in library_files]
    logger.debug(f"Discovered feature library files for species {species}: {result}")
    return result

# -----------------------------------------------------------------------------------------------
# Get feature library files for a given species (supports .fna, .fasta, .fa).
# If config specifies a 'feature_libraries' list for this species, only those are returned.
# Library IDs are the filename stem with dots replaced by underscores
# (e.g. 'genes.fna' → 'genes', 'my.lib.fna' → 'my_lib').
# Raises ConfigValidationError when a requested library ID is not found on disk.
def get_feature_library_file_list_for_species(species: str) -> list[tuple[str, str]]:
    all_libs = _discover_all_feature_library_file_list_for_species(species)

    requested = _get_species_config_list(species, "feature_libraries")
    if requested is None:
        return all_libs

    all_map = {lib_id: lib_path for lib_id, lib_path in all_libs}
    missing = [lib_id for lib_id in requested if lib_id not in all_map]
    if missing:
        raise ConfigValidationError(
            f"Species '{species}': the following feature libraries were requested in the config "
            f"but not found on disk: {missing}. "
            f"Available feature library IDs: {sorted(all_map.keys())}"
        )

    selected = [(lib_id, all_map[lib_id]) for lib_id in requested]
    logger.debug(f"Config-filtered feature libraries for species {species}: {selected}")
    return selected

# -----------------------------------------------------------------------------------------------
# Get only reference file paths for a species
def get_feature_library_paths_for_species(species):
    refs = get_feature_library_file_list_for_species(species)
    return [ref[1] for ref in refs]

# -----------------------------------------------------------------------------------------------
# Get only reference IDs for a species
def get_feature_library_ids_for_species(species):
    refs = get_feature_library_file_list_for_species(species)
    return [ref[0] for ref in refs]

# -----------------------------------------------------------------------------------------------
# Get scg library files for a given species (supports .fna, .fasta, .fa)
# Returns an empty list when nothing is found (no exception) so callers can
# distinguish "user provided none" from an unexpected error.
def get_scg_library_file_list_for_species(species: str) -> list[tuple[str, str]]:
    # Construct reference folder path
    species_folder = species

    scg_library_folder = os.path.join(f"{species_folder}/input/reveal_module/scg")
    library_files = []
    try:
        # Collect all supported reference files
        logger.debug(f"Looking for SCG library files in {scg_library_folder} for species {species}.")

        library_files = get_files_in_folder_matching_pattern(scg_library_folder, "*.fna")
        library_files += get_files_in_folder_matching_pattern(scg_library_folder, "*.fasta")
        library_files += get_files_in_folder_matching_pattern(scg_library_folder, "*.fa")
    except Exception as e:
        logger.debug(f"Failed to find SCG library files in {scg_library_folder} for species {species}. Exception: {e}")

    if len(library_files) == 0:
        logger.debug(f"No user-provided SCG library files found for species {species}.")
        return []

    # Return as list of tuples: (filename without extension, full path)
    library_files_with_filename = [(get_cleaned_feature_library_id_for_library_path(f), f) for f in library_files]

    logger.debug(f"SCG library files for species {species}: {library_files_with_filename}")

    return library_files_with_filename

# -----------------------------------------------------------------------------------------------
# Get only scg library file paths for a species
def get_scg_library_paths_for_species(species):
    refs = get_scg_library_file_list_for_species(species)
    return [ref[1] for ref in refs] 

# -----------------------------------------------------------------------------------------------
# Get only scg library IDs for a species  
def get_scg_library_ids_for_species(species):
    refs = get_scg_library_file_list_for_species(species)
    return [ref[0] for ref in refs]

# -----------------------------------------------------------------------------------------------
# Get cleaned feature library ID for a given feature library path
def get_cleaned_feature_library_id_for_library_path(feature_library_path):
    return os.path.splitext(os.path.basename(feature_library_path))[0].replace('.', '_')

# -----------------------------------------------------------------------------------------------
# Get feature library file for a given species and library ID
def get_feature_library_file_for_species_and_library(species, library_id):
    libraries = get_feature_library_file_list_for_species(species)
    for lib in libraries:
        if lib[0] == library_id:
            return lib[1]
    logger.error(f"Feature library with ID {library_id} not found for species {species}. Available libraries: {libraries}")
    raise Exception(f"Feature library with ID {library_id} not found for species {species}.")

# -----------------------------------------------------------------------------------------------
# Get scg library file for a given species and library ID
def get_scg_library_file_for_species_and_library(species, library_id):
    libraries = get_scg_library_file_list_for_species(species)
    for lib in libraries:
        if lib[0] == library_id:
            return lib[1]
    logger.warning(f"SCG library with ID {library_id} not found for species {species}. Available libraries: {libraries}")
    raise ValueError(f"SCG library with ID {library_id} not found for species {species}.")

# -----------------------------------------------------------------------------------------------
# Resolve the reference genome path that SCG determination (BUSCO) will use.
# Priority: species.{species}.scg_reference → auto-detect from {species}/input/reference_module/
# Raises ValueError when 0 or >1 references are found without an explicit config override.
def get_scg_determination_reference_path(species):
    import logging as _log
    config_ref = config.get("species", {}).get(species, {}).get("scg_reference")
    if config_ref:
        return config_ref

    refs = get_reference_file_list_for_species(species)

    if len(refs) == 0:
        raise ValueError(
            f"No reference genome found for SCG determination of species '{species}'. "
            f"Place a FASTA in {species}/input/reference_module/ or set "
            f"species.{species}.scg_reference in config."
        )

    if len(refs) > 1:
        ref_paths = ", ".join(r[1] for r in refs)
        raise ValueError(
            f"Multiple reference genomes found for species '{species}' ({ref_paths}). "
            f"SCG determination requires exactly one reference. "
            f"Please set species.{species}.scg_reference in config."
        )

    _log.info(f"[SCG Selector] Auto-detected reference for '{species}': {refs[0][1]}")
    return refs[0][1]

# -----------------------------------------------------------------------------------------------
# Return True when all of the following hold:
#   1. scg_selector.execute is true in pipeline config
#   2. No user-provided SCG FASTA exists in {species}/input/reveal_module/scg/
#   3. A BUSCO lineage is configured for the species (required to run BUSCO)
def should_auto_determine_scg(species):
    if not config.get("pipeline", {}).get("reveal_module", {}).get("scg_selector", {}).get("execute", True):
        return False
    if get_scg_library_file_list_for_species(species):
        return False
    lineage = config.get("species", {}).get(species, {}).get("lineage")
    return bool(lineage)

# -----------------------------------------------------------------------------------------------
# Return the SCG library ID to use: user-provided ID or the auto-determined sentinel.
def get_effective_scg_library_id_for_species(species):
    user_scgs = get_scg_library_file_list_for_species(species)
    if user_scgs:
        return user_scgs[0][0]
    return f"{species}_determined_scg"

# -----------------------------------------------------------------------------------------------
# Return the FASTA path for the SCG library: user-provided or auto-determined.
def get_effective_scg_library_path_for_species(species):
    user_scgs = get_scg_library_file_list_for_species(species)
    if user_scgs:
        return user_scgs[0][1]
    return f"{species}/processed/reveal_module/scg/{species}_relevant_scg.fasta"

# -----------------------------------------------------------------------------------------------
# Get the competition FASTA file for a species from {species}/input/reveal_module/competition/.
# Returns None when no file is found (competitive mapping not configured).
# Raises ValueError when more than one FASTA is found.
def get_competition_fasta_for_species(species):
    competition_folder = f"{species}/input/reveal_module/competition"
    files = []
    try:
        logger.debug(f"Looking for competition FASTA in {competition_folder} for species {species}.")
        files = get_files_in_folder_matching_pattern(competition_folder, "*.fna")
        files += get_files_in_folder_matching_pattern(competition_folder, "*.fasta")
        files += get_files_in_folder_matching_pattern(competition_folder, "*.fa")
    except Exception as e:
        logger.debug(f"No competition folder found for species {species}: {e}")
        return None

    if len(files) == 0:
        logger.debug(f"No competition FASTA found for species {species}.")
        return None

    if len(files) > 1:
        raise ValueError(
            f"Multiple competition FASTA files found for species '{species}' in {competition_folder}. "
            f"Please provide exactly one FASTA file: {files}"
        )

    logger.debug(f"Competition FASTA for species {species}: {files[0]}")
    return files[0]