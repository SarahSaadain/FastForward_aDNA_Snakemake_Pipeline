# Skip any FASTA entry whose header ends in _comp (header + its sequence lines).
/^>/{skip=/_comp$/}
!skip
