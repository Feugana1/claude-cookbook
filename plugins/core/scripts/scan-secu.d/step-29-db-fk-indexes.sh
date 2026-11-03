#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 29. DB indexes — foreign keys covered ──────────────────────────────────
# Sans index, FK lookups deviennent seq scans = lock + connection pool exhausted
# en prod. Audit migrations : chaque .foreign() doit avoir une .index() adjacente
# OU être sur une PK (déjà indexed) OU être annoté canonical-skip:db-index.
step 29 "DB indexes — foreign keys covered" 3 "Performance"
FK_GAPS=$(perl -0777 -ne '
  while (/\.foreign\(\s*["\x27]([a-z_]+)["\x27]/g) {
    my $col = $1;
    my $pos = $-[0];
    # Skip si colonne contient "id" suivi de plus rien (= PK ou auto-indexed)
    next if $col eq "id";
    # Skip si .index() apparait dans 200 chars autour (avant ou apres .foreign)
    my $window_start = $pos > 200 ? $pos - 200 : 0;
    my $window_end = $pos + 200 < length($_) ? $pos + 200 : length($_);
    my $context = substr($_, $window_start, $window_end - $window_start);
    next if $context =~ /\.index\(\s*\[?["\x27]?$col/;
    next if $context =~ /canonical-skip:db-index/;
    # Skip si la table elle-meme a un index composite sur cette FK (heuristique)
    next if $context =~ /createIndex.*$col|CREATE\s+INDEX.*$col/i;
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line:$col\n";
  }
' database/migrations/*.ts 2>/dev/null | head -20 || true)
if [ -z "$FK_GAPS" ]; then
  pass "All foreign keys appear indexed (or annotated canonical-skip:db-index)"
else
  C=$(echo "$FK_GAPS" | wc -l | tr -d ' \r')
  warn "$C foreign key(s) may lack covering index (audit with EXPLAIN ANALYZE if hot path)"
  echo "$FK_GAPS" | head -5 | while IFS= read -r line; do echo "    $line"; done
fi
