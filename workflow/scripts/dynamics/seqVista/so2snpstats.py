#!/usr/bin/env python3
"""
Compute per-position SNP statistics from a single .so file.

Output is a TSV with one row per SNP position, intended as input for
compare_snpstats.py. For indel statistics see so2indelstats.py.

Usage
-----
    SeqVista snpstats --so sample1.so --sample-id Dmel1933_SL07
    SeqVista snpstats --so sample1.so --sample-id Dmel1933_SL07 --outfile out.snpstats.tsv

Output columns
--------------
  seqid             sequence name
  pos               1-based position in the reference
  sampleid          value of --sample-id
  cov               coverage at this position
  refc              reference base
  A  T  C  G        absolute read counts for each base
  A_freq .. G_freq  count / cov for each base
  major_alt         non-reference base with the highest count
  major_alt_freq    major_alt count / cov

Authors
-------
    Robert Kofler
    Sarah Saadain
"""

import argparse
import logging
from pathlib import Path

import pandas as pd

from modules import SeqEntryReader

log = logging.getLogger(__name__)

_COLS = [
    "seqid", "pos", "sampleid", "cov",
    "refc", "A", "T", "C", "G",
    "A_freq", "T_freq", "C_freq", "G_freq",
    "major_alt", "major_alt_freq",
]


def _snp_records(se, sample_id: str) -> list[dict]:
    """Extract one record per SNP position from a SeqEntry."""
    records = []
    cov = se.cov
    for snp in se.snplist:
        p = snp.pos  # 0-based
        c = cov[p] if p < len(cov) else 0.0

        a_freq = round(snp.ac / c, 4) if c > 0 else 0.0
        t_freq = round(snp.tc / c, 4) if c > 0 else 0.0
        c_freq = round(snp.cc / c, 4) if c > 0 else 0.0
        g_freq = round(snp.gc / c, 4) if c > 0 else 0.0

        alts = {
            b: cnt for b, cnt in
            (("A", snp.ac), ("T", snp.tc), ("C", snp.cc), ("G", snp.gc))
            if b != snp.refc and cnt > 0
        }
        major_alt      = max(alts, key=alts.get) if alts else pd.NA
        major_alt_freq = round(alts[major_alt] / c, 4) if (major_alt is not pd.NA and c > 0) else 0.0

        records.append({
            "seqid":          se.seqname,
            "pos":            p + 1,
            "sampleid":       sample_id,
            "cov":            round(c, 3),
            "refc":           snp.refc,
            "A":              round(snp.ac, 3),
            "T":              round(snp.tc, 3),
            "C":              round(snp.cc, 3),
            "G":              round(snp.gc, 3),
            "A_freq":         a_freq,
            "T_freq":         t_freq,
            "C_freq":         c_freq,
            "G_freq":         g_freq,
            "major_alt":      major_alt,
            "major_alt_freq": major_alt_freq,
        })
    return records


def compute_snpstats(filepath: Path, sample_id: str, outfile: Path) -> int:
    """Stream per-position SNP stats straight to outfile, one scaffold at a time.

    Positions are only ever duplicated within a single scaffold's SNP list
    (seqid already scopes them), so duplicates are detected per scaffold as
    it's processed rather than across the whole file. This keeps memory
    bounded by the largest single scaffold instead of the total SNP count
    across the whole file, which otherwise dwarfs the input file size for
    genomes with millions of SNPs.
    """
    n_written = 0
    header_written = False
    with open(outfile, "w") as out:
        for se in SeqEntryReader(str(filepath), need_ambcov=False):
            records = _snp_records(se, sample_id)
            df = pd.DataFrame(records, columns=_COLS) if records else pd.DataFrame(columns=_COLS)
            dupes = df.duplicated(subset=["seqid", "pos"])
            if dupes.any():
                log.warning(
                    "%d duplicate (seqid, pos) positions for %s in %s — keeping first occurrence:\n%s",
                    int(dupes.sum()), se.seqname, filepath.name,
                    df[dupes][["seqid", "pos"]].to_string(index=False),
                )
                df = df[~dupes].reset_index(drop=True)
            df.to_csv(out, sep="\t", index=False, header=not header_written)
            header_written = True
            n_written += len(df)
        if not header_written:
            pd.DataFrame(columns=_COLS).to_csv(out, sep="\t", index=False)
    return n_written


def main():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    parser = argparse.ArgumentParser(
        description="Compute per-position SNP stats from a single .so file.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--so", required=True, type=Path, metavar="FILE",
                        help="Input .so file.")
    parser.add_argument("--sample-id", required=True, dest="sample_id", metavar="ID",
                        help="Sample identifier written into the output (e.g. Dmel1933_SL07).")
    parser.add_argument("--outfile", "-o", type=Path, default=None, metavar="FILE",
                        help="Output TSV (default: <sample_id>.snpstats.tsv).")

    args = parser.parse_args()

    if not args.so.is_file():
        parser.error(f"File not found: {args.so}")

    outfile = args.outfile or Path(f"{args.sample_id}.snpstats.tsv")

    log.info("Parsing %s (sample_id=%s)", args.so.name, args.sample_id)
    n = compute_snpstats(args.so, args.sample_id, outfile)
    log.info("SNPs → %s  (%d positions)", outfile, n)


if __name__ == "__main__":
    main()
