#
rule prepare_custom_data_breadth:
    input:
        csv="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv",
    output:
        tsv="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.tsv",
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.log",
    conda:
        "../../../envs/python_and_r.yaml"
    params:
        individual="{individual}",
        reference="{reference}",
    script:
        "../../../scripts/summary_module/prepare_custom_data_breadth.py"
