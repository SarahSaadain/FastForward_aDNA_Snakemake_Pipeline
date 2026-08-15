import os

ref_path = snakemake.input.ref
output_fa = snakemake.output.fa

os.makedirs(os.path.dirname(output_fa), exist_ok=True)

# input/ (or wherever ref_path was discovered) is treated as read-only - it may be a symlink
# into a shared/external reference_dir (see species_paths.py), so it is never renamed or
# written to. We only ever symlink a standardized name into processed/.
#
# The link target is computed *lexically* (os.path.abspath, which only resolves "." / ".." and
# joins with cwd) rather than with os.path.realpath (which would also follow any symlink, e.g.
# input/reference_module itself when reference_dir is configured, all the way to its final
# target). A lexical relative path keeps the hop through input/reference_module intact instead
# of flattening it away, so the link still resolves correctly if the whole pastForward project
# folder is later moved or renamed - only moving/renaming the external reference_dir target
# itself (if configured) would break it, same as species_paths.py's own symlink already does.
#
# Use os.path.lexists (not os.path.exists) so an existing - even dangling - symlink is treated
# as "already set up" rather than crashing os.symlink with FileExistsError.
if not os.path.lexists(output_fa):
    output_dir = os.path.dirname(os.path.abspath(output_fa))
    relative_target = os.path.relpath(os.path.abspath(ref_path), start=output_dir)
    os.symlink(relative_target, output_fa)
    print(f"Linked {output_fa} -> {relative_target}")
else:
    print(f"Reference {output_fa} already exists, skipping.")
