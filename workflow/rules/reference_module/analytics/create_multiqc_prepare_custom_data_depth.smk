#
rule summarize_coverage:
    input:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv"
    output:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_summary.tsv"
    params:
        individual="{individual}",  
        reference="{reference}"
    conda:
        "../../../envs/python_and_r.yaml",
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_summary.log"
    script:
        "../../../scripts/summary_module/summarize_coverage.py"

rule prepare_custom_data_depth:
    input:
        csv="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv"
    output:
        avg="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_depth_coverage_avg.csv",
        max="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_depth_coverage_max.csv"
    conda:
        "../../../envs/python_and_r.yaml",
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_depth_coverage.log"
    script:
        "../../../scripts/summary_module/prepare_custom_data_depth.py"