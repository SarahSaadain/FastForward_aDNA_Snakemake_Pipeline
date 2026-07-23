####################################################
# Python helper functions for rules
# Naming of functions: <rule_name>_<rule_parameter>[_<rule_subparameter>]>
####################################################

def helper_get_bam_for_damage_analysis(wildcards):

    species = wildcards["species"]
    reference = wildcards["reference"]
    individual = wildcards["individual"]

    # if deduplication is enabled, return the dedupped bam
    # if map_reads_to_reference is enabled, return the sorted bam

    if config.get("pipeline", {}).get("reference_processing", {}).get("deduplication", {}).get("execute", True) == True:
        return f"{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped.bam"

    return f"{species}/processed/{reference}/mapped/{individual}_{reference}_sorted.bam"

def analyze_mapdamage_and_rescale_bam_input_bam(wildcards):
    return helper_get_bam_for_damage_analysis(wildcards)

def analyze_mapdamage_and_rescale_bam_input_bam_index(wildcards):
    return f"{analyze_mapdamage_and_rescale_bam_input_bam(wildcards)}.bai"

####################################################
# Snakemake rules
####################################################

# Rule: Analyze DNA damage and rescale BAM using mapDamage2
rule analyze_mapdamage_and_rescale_bam:
    input:
        bam = analyze_mapdamage_and_rescale_bam_input_bam,
        ref = "{species}/raw/ref/{reference}.fa"
    output:
        directory           = directory("{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/"),
        GtoA3p              ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.3pGtoA_freq.txt",
        CtoT5p              ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.5pCtoT_freq.txt",
        dnacomp             ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.dnacomp.txt",
        lg_dist             ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.lgdistribution.txt",
        misinc              ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.misincorporation.txt",
        plot_misinc         ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Fragmisincorporation_plot.pdf",
        plot_len            ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Length_plot.pdf",
        stats_ref           ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.dnacomp_genome.csv",
        stats_prob          ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_correct_prob.csv",
        stats_hist          ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_hist.pdf",
        stats_iter          ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_iter.csv",
        stats_summ          ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_iter_summ_stat.csv",
        stats_plot_freq     ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_post_pred.pdf",
        stats_plot_trace    ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Stats_out_MCMC_trace.pdf",
        bam                 =temp("{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.bam"),
        log                 ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.Runtime_log.txt",
    params:
        extra="",  # optional parameters for mapdamage2 (except -i, -r, -d, --rescale)
    message:
        "Analyze damage and rescale {input.bam}"
    log:
        "{species}/processed/{reference}/analytics/{individual}/mapdamage/{individual}_{reference}.rule.log",
    wrapper:
        "v9.3.0/bio/mapdamage2"

# Rule: Sort rescaled BAM file
# 3 Sort BAM
rule sort_rescaled_bam:
    input:
        "{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.bam"
    output:
        temp("{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}_sorted.bam")
    log:
        "{species}/processed/{reference}/analytics/{individual}/mapdamage/{individual}_{reference}_sorted.bam.log"
    message:
        "Sort rescaled BAM for {input}",
    threads: 10
    wrapper:
        "v9.3.0/bio/samtools/sort"

# Rule: Index rescaled BAM file
# 4 Index BAM
rule index_rescaled_bam:
    input:
        "{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}_sorted.bam"
    output:
        temp("{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}_sorted.bam.bai")
    log:
        "{species}/processed/{reference}/analytics/{individual}/mapdamage/{individual}_{reference}_sorted.bam.bai.log"
    message:
        "Index rescaled BAM for {input}",
    threads: 10
    wrapper:
        "v9.3.0/bio/samtools/index"

# Rule: Move rescaled BAM and index to processed directory
rule move_rescaled_bam:
    input:
        sorted_bam="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}_sorted.bam",
        bam_index ="{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}_sorted.bam.bai"
    output:
        sorted_bam=temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped_rescaled.bam"),
        bam_index =temp("{species}/processed/{reference}/mapped/{individual}_{reference}_sorted_dedupped_rescaled.bam.bai")
    message:
        "Move rescaled BAM and index to processed directory for {input.sorted_bam}",
    shell:
        """
        cp "{input.sorted_bam}" "{output.sorted_bam}"
        cp "{input.bam_index}" "{output.bam_index}"
        """

