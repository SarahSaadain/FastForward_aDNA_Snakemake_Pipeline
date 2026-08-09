# NOTE: preseq must be run on the raw mapped BAM before any duplicate removal or damage rescaling.
# Running preseq on a deduplicated and/or mapDamage-rescaled BAM removes duplication information
# and violates preseq assumptions, leading to errors such as:
# “ERROR: Saturation expected at double initial sample size. Unable to extrapolate”.
# Library complexity estimates from deduplicated or rescaled BAMs are invalid and cannot be recovered.


rule preseq_complexitiy_curve:
    input:
        bam="{species}/processed/reference_module/{reference}/mapped/{individual}_{reference}_sorted.bam",
    output:
        txt="{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.c_curve.txt",
    log:
        "{species}/results/reference_module/{reference}/analytics/individual_level/{individual}/preseq/{individual}_{reference}.c_curve.log",
    conda:
        "../../../envs/preseq.yaml"
    threads: 1
    message:
        "Running preseq c_curve for {wildcards.individual} of {wildcards.species}."
    shell:
        """
        preseq c_curve \
            -B \
            -o "{output.txt}" \
            "{input.bam}" \
            >"{log}" 2>&1
        """
