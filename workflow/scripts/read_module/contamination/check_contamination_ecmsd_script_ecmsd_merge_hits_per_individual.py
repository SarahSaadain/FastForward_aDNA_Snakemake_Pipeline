#!/usr/bin/env python3
import pandas as pd
from pathlib import Path

# Access Snakemake object
input_files = snakemake.input         # list of input TSVs
output_file = snakemake.output[0]     # output TSV path
taxonomic_hierarchy = snakemake.params.taxonomic_hierarchy  # e.g., "genus", "family", etc.

all_dfs = []
taxonomic_column = taxonomic_hierarchy.lower()

for file in input_files:
    df = pd.read_csv(file, sep="\t")

    # no contamination hits for this sample -> keep it as a zero row instead of
    # dropping it, otherwise a clean sample vanishes from the matrix entirely
    # and, if it's the only sample for its individual, MultiQC gets a
    # data-less TSV it can't parse (ponytail: header-only synthetic row, revisit if ECMSD output format changes)
    if df.empty:
        df = pd.DataFrame({taxonomic_column: ["none_detected"], "TotalReads": [0]})

    sample_name = Path(file).stem
    df['Sample'] = sample_name.replace(f"_Mito_summary_{taxonomic_hierarchy}_proportions", '')

    # remove Proportion column if exists
    if 'Proportion' in df.columns:
        df = df.drop(columns=['Proportion'])

    all_dfs.append(df)

# Combine all dataframes
combined = pd.concat(all_dfs, ignore_index=True)

# Pivot: rows = Sample, columns = Genus, values = TotalReads
matrix = combined.pivot_table(
    index='Sample',
    columns=taxonomic_hierarchy.lower(),
    values='TotalReads',
    fill_value=0   # fill missing combinations with 0
)

# Sort columns by total reads (descending)
matrix = matrix[matrix.sum(axis=0).sort_values(ascending=False).index]

# Optional: reset column names if you want a flat TSV
matrix.reset_index(inplace=True)

# Save as TSV
matrix.to_csv(output_file, sep="\t", index=False)
