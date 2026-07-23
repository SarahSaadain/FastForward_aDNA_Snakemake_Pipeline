#
rule prepare_custom_data_breadth:
    input:
        csv="{species}/results/{reference}/analytics/individual_level/{individual}/coverage/{individual}_{reference}_coverage_analysis.csv"
    output:
        tsv="{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/{individual}_{reference}_coverage_analysis.tsv"
    params:
        individual="{individual}",
        reference="{reference}"
    conda:
        "../../../envs/python_and_r.yaml",
    script:
        "../../../scripts/processing_summary/prepare_custom_data_breadth.py"