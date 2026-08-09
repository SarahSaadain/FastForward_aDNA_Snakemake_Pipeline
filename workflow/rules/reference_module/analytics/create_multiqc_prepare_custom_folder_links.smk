rule link_qualimap_for_multiqc:
    input:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/qualimap"
    output:
        directory("{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/qualimap/{individual}_{reference}")
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Linking qualimap results for {wildcards.individual} of {wildcards.species} to multiqc custom content."
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/qualimap/{individual}_{reference}_link.log"
    shell:
        """
        mkdir -p "$(dirname "{output}")"
        cp -r "{input}" "{output}" > "{log}" 2>&1
        """

rule copy_mapdamage_result_for_multiqc:
    input:
        GtoA3p  = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.3pGtoA_freq.txt",
        CtoT5p  = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.5pCtoT_freq.txt",
        lg_dist = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.lgdistribution.txt",
    output:
        folder  = directory("{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}"),
        GtoA3p  = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/3pGtoA_freq.txt",
        CtoT5p  = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/5pCtoT_freq.txt",
        lg_dist = "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/lgdistribution.txt",
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Copying mapdamage results for {wildcards.individual} of {wildcards.species} to multiqc custom content."
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}_copy.log"
    shell:
        """
        mkdir -p "{output.folder}"
        cp "{input.GtoA3p}" "{output.GtoA3p}" > "{log}" 2>&1
        cp "{input.CtoT5p}" "{output.CtoT5p}" >> "{log}" 2>&1
        cp "{input.lg_dist}" "{output.lg_dist}" >> "{log}" 2>&1
        """
