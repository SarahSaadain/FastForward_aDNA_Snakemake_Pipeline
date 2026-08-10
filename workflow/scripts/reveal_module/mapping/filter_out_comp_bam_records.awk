# Drop @SQ header lines for _comp-suffixed contigs and alignment records against them,
# keeping all other header lines and records as-is. Expects SAM text (e.g. `samtools view -h`).
/^@SQ/ && $2~/^SN:.*_comp$/ {next}
/^@/ {print; next}
$3~/_comp$/ {next}
{print}
