####################################################
# Snakemake rules
####################################################
# Determine index path: use config if provided, otherwise use downloaded
# We use the index from https://benlangmead.github.io/aws-indexes/centrifuge
# Refseq: bacteria, archaea, viral, human
_configured_index = config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("tools", {}).get("centrifuge", {}).get("settings", {}).get("index")

def get_centrifuge_index(wildcards):
    if _configured_index:
        return _configured_index
    else:
        return "resources/centrifuge_index/p+h+v"

def get_centrifuge_index_input(wildcards):
    
    if _configured_index:
        return []
    else:
        return expand("resources/centrifuge_index/p+h+v.{ext}.cf", ext=["1", "2", "3"])

rule download_centrifuge_index:
    output:
        expand("resources/centrifuge_index/p+h+v.{ext}.cf", ext=["1", "2", "3"])
    params:
        url = "https://genome-idx.s3.amazonaws.com/centrifuge/p%2Bh%2Bv.tar.gz",
        outdir = "resources/centrifuge_index"
    conda:
        "../../../envs/wget.yaml"
    message: "Downloading Centrifuge index"
    shell:
        """
        echo "Downloading Centrifuge index from {params.url} to {params.outdir}"
        echo "This may take a while depending on your internet connection..."

        mkdir -p "{params.outdir}"
        wget -O "{params.outdir}/p+h+v.tar.gz" "{params.url}"

        echo "Extracting Centrifuge index..."
        tar -xzf "{params.outdir}/p+h+v.tar.gz" -C "{params.outdir}"

        echo "Cleaning up downloaded archive..."
        rm "{params.outdir}/p+h+v.tar.gz"
        """

rule analyze_contamination_with_centrifuge:
    input:
        fastq = "{species}/processed/reads_module/reads_quality_filtered/{sample}_quality_filtered_final.fastq.gz",
        index = get_centrifuge_index_input
    output:
        output = temp("{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_output.tsv"),
        report = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_report.tsv"
    threads: 15
    params:
        index = get_centrifuge_index,
    conda:
        config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("tools", {}).get("centrifuge", {}).get("settings", {}).get("conda_env", "../../../envs/centrifuge.yaml")
    message: "Running Centrifuge contamination analysis for {input.fastq}"
    shell:
        """
        centrifuge \
            -x "{params.index}" \
            -U "{input.fastq}" \
            -S "{output.output}" \
            --report-file "{output.report}" \
            --threads {threads}
        """

rule analyze_centrifuge_report_taxon_counts:
    input:
        centrifuge_out = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_output.tsv"
    output:
        taxon_counts = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_taxon_counts.tsv"
    message: "Counting taxon occurrences in {input.centrifuge_out}"
    shell:
        r"""
        awk '$3 != 0 {{print $3}}' "{input.centrifuge_out}" \
            | sort \
            | uniq -c \
            | sort -nr \
            > "{output.taxon_counts}"
        """

rule analyze_centrifuge_report_proportions:
    input:
        report = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_report.tsv",
        count_reads = "{species}/processed/reads_module/statistics/{sample}_quality_filtered.count"
    output:
        "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_proportions.tsv",
    params:
        sample = "{sample}"
    script:
        "../../../scripts/read_module/contamination/check_contamination_ecmsd_script_analyze_centrifuge_report_proportions.py"

rule analyze_centrifuge_report_top_taxa:
    input:
        report = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_report.tsv",
    output:
        top10_unique = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_top10_unique_taxa.tsv",
        top10_total = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_top10_total_taxa.tsv"
    params:
        sample = "{sample}",
        include_human = config.get("pipeline", {}).get("read_module", {}).get("contamination", {}).get("tools", {}).get("centrifuge", {}).get("settings", {}).get("include_human_taxid", False)
    script:
        "../../../scripts/read_module/contamination/check_contamination_ecmsd_script_analyze_centrifuge_report_top_taxa.py"

rule compress_centrifuge_output:
    input:
        tsv = "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_output.tsv",
    output:
        "{species}/results/reads_module/contamination/centrifuge/{individual}/{sample}/{sample}_centrifuge_output.tsv.gz"
    threads: 4
    conda:
        "../../../envs/pigz.yaml"
    message: "Compressing Centrifuge output for {wildcards.sample}"
    shell:
        "pigz -p {threads} -c \"{input.tsv}\" > \"{output}\""