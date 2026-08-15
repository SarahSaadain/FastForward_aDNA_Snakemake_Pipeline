import os

ref_path = snakemake.input.ref
output_fa = snakemake.output.fa

os.makedirs(os.path.dirname(output_fa), exist_ok=True)

# input/ (or wherever ref_path was discovered) is treated as read-only - it may be a symlink
# into a shared/external reference_dir (see species_paths.py), so it is never renamed or
# written to. We only ever symlink a standardized name into processed/, pointing at the fully
# resolved real file so this stays valid even if the project folder itself is later moved or
# renamed. Use os.path.lexists (not os.path.exists) so an existing - even dangling - symlink
# is treated as "already set up" rather than crashing os.symlink with FileExistsError.
if not os.path.lexists(output_fa):
    real_ref_path = os.path.realpath(ref_path)
    os.symlink(real_ref_path, output_fa)
    print(f"Linked {output_fa} -> {real_ref_path}")
else:
    print(f"Reference {output_fa} already exists, skipping.")
