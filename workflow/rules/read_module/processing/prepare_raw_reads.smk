####################################################
# Snakemake rules
####################################################


# Rule: Run ECMSD for taxonomic screening
rule prepare_raw_reads:
    input:
        raw_read="{species}/{raw_read}",
    output:
        raw_read="{species}/input/read_module/{raw_read}",
    log:
        "{species}/input/read_module/{raw_read}.prepare.log",
    conda:
        "../../../envs/python_and_r.yaml"
    message:
        "Moving raw read file {input.raw_read} to {output.raw_read}"
    shell:
        """
        mv "{input.raw_read}" "{output.raw_read}" >"{log}" 2>&1
        echo "Done moving raw read file {input.raw_read} to {output.raw_read}" >>"{log}" 2>&1
        """
