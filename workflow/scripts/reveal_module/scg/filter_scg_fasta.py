with open(snakemake.input.id_list) as f:
    ids_to_keep = set(line.strip() for line in f if line.strip())

with open(snakemake.input.fasta) as fin, open(snakemake.output.filtered, "w") as fout:
    write = False
    for line in fin:
        if line.startswith(">"):
            seq_id = line[1:].split()[0].strip()
            write = seq_id in ids_to_keep
        if write:
            fout.write(line)
