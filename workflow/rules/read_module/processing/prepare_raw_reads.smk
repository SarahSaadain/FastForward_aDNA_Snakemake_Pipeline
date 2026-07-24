####################################################
# Snakemake rules
####################################################

# Rule: Run ECMSD for contamination analysis
rule prepare_raw_reads:
    input:
        raw_read = "{species}/{raw_read}",
    output:
        raw_read = "{species}/input/reads/{raw_read}",
    message: "Moving raw read file {input.raw_read} to {output.raw_read}"
    shell: 
        """
        mv "{input.raw_read}" "{output.raw_read}"
        echo "Done moving raw read file {input.raw_read} to {output.raw_read}"
        """
