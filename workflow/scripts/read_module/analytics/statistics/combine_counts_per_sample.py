with open(snakemake.input.raw_reads) as f:
    raw = int(f.read())
with open(snakemake.input.trimmed_reads) as f:
    trimmed = int(f.read())
with open(snakemake.input.quality_filtered_reads) as f:
    quality_filtered = int(f.read())

sample = snakemake.wildcards.sample
individual = sample.split("_")[0] if sample else "N/A"

with open(snakemake.output.counts, "w") as f:
    f.write(f"{sample},{individual},{raw},{trimmed},{quality_filtered}\n")
