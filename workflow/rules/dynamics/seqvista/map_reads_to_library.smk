
####################################################
# Snakemake rules
####################################################
_dyn_settings        = config.get("pipeline", {}).get("dynamics", {}).get("mapping", {}).get("settings", {})
_dyn_mapper          = _dyn_settings.get("mapper", "bwa-mem2")
_BWA_ALN_DEFAULTS    = "-n 0.01 -k 2 -l 1024 -o 2"  # Oliva et al. 2021 (10.1093/bib/bbab076)
_MINIMAP2_DEFAULTS   = "-ax sr"
_dyn_mapper_extra    = _dyn_settings.get("mapper_extra_params", _BWA_ALN_DEFAULTS if _dyn_mapper == "bwa-aln" else (_MINIMAP2_DEFAULTS if _dyn_mapper == "minimap2" else ""))
_dyn_keep_mapped_bam = _dyn_settings.get("keep_mapped_bam", False)
_dyn_min_mapq_scg    = _dyn_settings.get("min_mapq_scg", 0)
_dyn_min_mapq_fle    = _dyn_settings.get("min_mapq_fle", 0)
_comp_execute        = config.get("pipeline", {}).get("dynamics", {}).get("mapping", {}).get("settings", {}).get("competitive_mapping", False)

_MAPPED_BAM = "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam"
_MAPPED_BAI = _MAPPED_BAM + ".bai"
_MAPPED_BAM_PRECOMP  = "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.precomp.bam"
_MAPPED_BAM_PREMAPQ  = "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.premapq.bam"

if _dyn_mapper == "minimap2":
    rule index_library_for_mapping_minimap2:
        input:
            target="{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta"
        output:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.mmi",
        log:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg_minimap2_index.log"
        message: "Indexing SCG and Feature library {input} with minimap2"
        wrapper:
            "v9.3.0/bio/minimap2/index"

    rule map_reads_to_scg_feature_library_minimap2:
        input:
            query=["{species}/processed/reads/reads_merged/{individual}.fastq.gz"],
            target="{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.mmi",
        output:
            temp("{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.with_unmapped.bam"),
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg_minimap2.log",
        message: "Mapping reads of {wildcards.individual} to {wildcards.species} SCG and Feature library with minimap2"
        params:
            extra=_dyn_mapper_extra,
            sorting="coordinate"
        threads: 10
        wrapper:
            "v9.3.0/bio/minimap2/aligner"

elif _dyn_mapper == "bwa-aln":
    rule index_library_for_mapping_bwa_aln:
        input:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta"
        output:
            multiext("{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        log:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg_bwa_aln_index.log"
        message: "Indexing SCG and Feature library {input} with BWA (for BWA ALN)"
        wrapper:
            "v9.3.0/bio/bwa/index"

    rule align_reads_to_library_bwa_aln:
        input:
            fastq="{species}/processed/reads/reads_merged/{individual}.fastq.gz",
            idx=multiext("{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        output:
            temp("{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sai"),
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg_bwa_aln.log",
        params:
            extra=_dyn_mapper_extra,
        threads: 10
        wrapper:
            "v9.3.0/bio/bwa/aln"

    rule map_reads_to_scg_feature_library_bwa_aln:
        input:
            fastq="{species}/processed/reads/reads_merged/{individual}.fastq.gz",
            sai="{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sai",
            idx=multiext("{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta", ".amb", ".ann", ".bwt", ".pac", ".sa"),
        output:
            temp("{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.unsorted.with_unmapped.bam"),
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg_bwa_samse.log"
        threads: 1
        wrapper:
            "v9.3.0/bio/bwa/samse"

    rule sort_bam_reads_to_library:
        input:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.unsorted.with_unmapped.bam"
        output:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.with_unmapped.bam"
        message: "Sorting BAM file for {input}"
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg_sort_bam.log",
        threads: 8
        wrapper:
            "v9.3.0/bio/samtools/sort"

else:
    # bwa-mem2 (default)
    rule index_library_for_mapping_bwa_mem2:
        input:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta"
        output:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.0123",
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.amb",
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.ann",
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.bwt.2bit.64",
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta.pac",
        log:
            "{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg_bwa_index.log"
        message: "Indexing SCG and Feature library {input} with BWA-MEM2"
        wrapper:
            "v9.3.0/bio/bwa-mem2/index"

    rule map_reads_to_scg_feature_library_bwa_mem2:
        input:
            reads=["{species}/processed/reads/reads_merged/{individual}.fastq.gz"],
            idx=multiext("{species}/processed/dynamics/{feature_library}/library/{feature_library}_and_scg.suffixed.fasta", ".amb", ".ann", ".bwt.2bit.64", ".pac", ".0123"),
        output:
            temp("{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.with_unmapped.bam"),
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg_bwa.log",
        message: "Mapping reads of {wildcards.individual} to {wildcards.species} SCG and Feature library with BWA-MEM2"
        params:
            extra=_dyn_mapper_extra,
            sort="samtools",
            sort_order="coordinate",
        threads: 10
        wrapper:
            "v9.3.0/bio/bwa-mem2/mem"

if _comp_execute:
    # Rule: Remove unmapped reads — output is intermediate (competition filter follows)
    rule remove_unmapped_reads_to_scg_feature_library:
        input:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.with_unmapped.bam"
        output:
            bam=temp(_MAPPED_BAM_PRECOMP)
        message: "Removing unmapped reads from BAM file for {input}"
        params:
            extra="-b -F 4",
        threads: 2
        wrapper:
            "v9.3.0/bio/samtools/view"

    # Rule: Remove reads mapping to competition sequences (_comp suffix)
    rule filter_competition_reads_from_bam:
        input:
            bam=_MAPPED_BAM_PRECOMP
        output:
            bam=temp(_MAPPED_BAM_PREMAPQ) if (_dyn_min_mapq_scg > 0 or _dyn_min_mapq_fle > 0) else (_MAPPED_BAM if _dyn_keep_mapped_bam else temp(_MAPPED_BAM))
        message: "Filtering competition sequences from BAM for {wildcards.individual}"
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_filter_comp.log"
        threads: 2
        conda:
            "../../../envs/samtools.yaml"
        shell:
            # Stream the BAM through awk to drop @SQ headers and alignment records for _comp references.
            # No index needed because we process the stream linearly.
            """
            samtools view -h "{input.bam}" | \
            awk '/^@SQ/ && $2~/^SN:.*_comp$/{{next}} /^@/{{print; next}} $3~/_comp$/{{next}} {{print}}' | \
            samtools view -b > "{output.bam}" 2>"{log}"
            """

else:
    # Rule: Remove unmapped reads — output is either pre-MAPQ intermediate or the final BAM
    rule remove_unmapped_reads_to_scg_feature_library:
        input:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.with_unmapped.bam"
        output:
            bam=temp(_MAPPED_BAM_PREMAPQ) if (_dyn_min_mapq_scg > 0 or _dyn_min_mapq_fle > 0) else (_MAPPED_BAM if _dyn_keep_mapped_bam else temp(_MAPPED_BAM))
        message: "Removing unmapped reads from BAM file for {input}"
        params:
            extra="-b -F 4",
        threads: 2
        wrapper:
            "v9.3.0/bio/samtools/view"

if _dyn_min_mapq_scg > 0 or _dyn_min_mapq_fle > 0:
    # Rule: Apply per-suffix MAPQ filters; SCG (_scg) and feature (_fle) thresholds are independent.
    rule filter_dynamics_reads_from_bam_by_mapq:
        input:
            bam=_MAPPED_BAM_PREMAPQ
        output:
            bam=_MAPPED_BAM if _dyn_keep_mapped_bam else temp(_MAPPED_BAM)
        message: "Filtering reads by MAPQ (SCG < {params.min_mapq_scg}, FLE < {params.min_mapq_fle}) for {wildcards.individual}"
        log:
            "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_filter_mapq.log"
        params:
            min_mapq_scg=_dyn_min_mapq_scg,
            min_mapq_fle=_dyn_min_mapq_fle
        threads: 2
        conda:
            "../../../envs/samtools.yaml"
        shell:
            """
            samtools view -h "{input.bam}" | \
            awk -v mq_scg={params.min_mapq_scg} -v mq_fle={params.min_mapq_fle} \
              'BEGIN{{OFS="\t"}} /^@/{{print; next}} ($3 ~ /_scg$/ && $5+0 < mq_scg) {{next}} ($3 ~ /_fle$/ && $5+0 < mq_fle) {{next}} {{print}}' | \
            samtools view -b -o "{output.bam}" 2>"{log}"
            """

# SAMTOOLS doesn't parallelize the indexing work — it only parallelizes compression/decompression.
rule index_bam_reads_to_library:
    input:
        "{species}/processed/dynamics/{feature_library}/mapped/{individual}_{feature_library}_and_scg.sorted.bam"
    output:
        _MAPPED_BAI if _dyn_keep_mapped_bam else temp(_MAPPED_BAI)
    message: "Indexing BAM file for {input}"
    params:
        extra="",
    threads: 5
    wrapper:
        "v9.3.0/bio/samtools/index"
