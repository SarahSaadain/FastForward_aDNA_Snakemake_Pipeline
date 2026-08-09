import pandas as pd

df = pd.read_csv(snakemake.input.tsv, sep="\t")
flagged = df[df["flag"].notna() & (df["flag"] != "")][["seqid", "flag"]]
flagged.to_csv(snakemake.output.txt, sep="\t", index=False)
