import gzip


def get_fastq_read_count(fastq_file):
    """Count reads in a FASTQ file (handles gzipped files). Each read is 4 lines."""
    if fastq_file is None:
        return 0
    opener = gzip.open if fastq_file.endswith(".gz") else open
    with opener(fastq_file, "rt") as f:
        return sum(1 for _ in f) // 4


files = snakemake.input.fastq if isinstance(snakemake.input.fastq, list) else [snakemake.input.fastq]
count = sum(get_fastq_read_count(f) for f in files)

with open(snakemake.output.counted, "w") as f:
    f.write(str(count))
