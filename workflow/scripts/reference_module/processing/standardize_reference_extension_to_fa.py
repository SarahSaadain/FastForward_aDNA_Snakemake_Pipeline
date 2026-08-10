import os

ref_path = snakemake.params.ref_path
output_fa = snakemake.output.fa

os.makedirs(os.path.dirname(output_fa), exist_ok=True)

# Only rename if the standardized file doesn't already exist
if not os.path.exists(output_fa):
    # Use symlink if you don't want to copy the file
    os.rename(ref_path, output_fa)
    print(f"Reference {ref_path} renamed to {output_fa}")
else:
    print(f"Reference {output_fa} already exists, skipping.")
