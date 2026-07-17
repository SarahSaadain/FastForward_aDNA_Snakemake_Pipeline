rule link_qualimap_for_multiqc:
    input:
        "{species}/results/{reference}/analytics/individual_level/{individual}/qualimap"
    output:
        directory("{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/qualimap/{individual}_{reference}")
    message:
        "Linking qualimap results for {wildcards.individual} of {wildcards.species} to multiqc custom content."
    shell:
        """
        mkdir -p "$(dirname "{output}")"
        cp -r "{input}" "{output}"
        """

rule copy_mapdamage_result_for_multiqc:
    input:
        GtoA3p  = "{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.3pGtoA_freq.txt",
        CtoT5p  = "{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.5pCtoT_freq.txt",
        lg_dist = "{species}/results/{reference}/analytics/individual_level/{individual}/mapdamage/{individual}_{reference}.lgdistribution.txt",
    output:
        folder  = directory("{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}"),
        GtoA3p  = "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/3pGtoA_freq.txt",
        CtoT5p  = "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/5pCtoT_freq.txt",
        lg_dist = "{species}/results/{reference}/analytics/individual_level/{individual}/multiqc_custom_content/mapdamage/{individual}_{reference}/lgdistribution.txt",
    message:
        "Copying mapdamage results for {wildcards.individual} of {wildcards.species} to multiqc custom content."
    shell:
        """
        mkdir -p "{output.folder}"
        cp "{input.GtoA3p}" "{output.GtoA3p}"
        cp "{input.CtoT5p}" "{output.CtoT5p}"
        cp "{input.lg_dist}" "{output.lg_dist}"
        """
