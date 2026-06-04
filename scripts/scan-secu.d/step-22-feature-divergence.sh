#!/usr/bin/env bash
# Sourced by scripts/scan-secu.sh — uses helpers: step/pass/fail/warn/skip
# ── 22. Feature duplication & convention divergence ────────────────────────
# Detecte les "N facons differentes de faire la meme chose" : pour chaque
# convention canonique du projet, grep les alternatives interdites. Source de
# verite = CLAUDE.md §13 + docs/anti-patterns.md.
#
# Ajout d'une nouvelle convention :
#   1. Definir le canonical (ex: `buildPublicShareMeta`)
#   2. Lister les forbidden patterns (ex: ad-hoc OG building)
#   3. Ajouter un sous-check ci-dessous (CHECK_<NAME>) + ligne de DETAILS
#
# Pour opter out localement : commentaire `// canonical-skip:<rule>:<reason>`
# au-dessus du code concerne (ex: `// canonical-skip:storage:integration test`).
step 22 "Feature duplication & convention divergence (IDOR + SoftDelete + Conv)" 1 "A01 Access Control"

CONV_HITS=0
CONV_DETAILS=""

# ── A. OG meta : canonical = buildPublicShareMeta sur surfaces publiques ────
# Forbidden : public controller render sans buildPublicShareMeta + sans annotation.
# Opt-out : `// canonical-skip:og:<reason>` dans le fichier (ex: anonymous cart).
OG_GAPS=""
for f in $(grep -rln "view.render" app/controllers/public_*.ts app/controllers/portal_reviews_controller.ts 2>/dev/null \
  | grep -v "_helpers\|_show_view\|_show_state" || true); do
  if grep -qE "canonical-skip:og:" "$f"; then continue; fi
  if ! grep -qE "buildPublicShareMeta|ogImage|og_image|ogImageUrl" "$f"; then
    OG_GAPS="${OG_GAPS}${f}"$'\n'
  fi
done
OG_GAPS=$(printf '%s' "$OG_GAPS" | grep -v '^$' || true)
if [ -n "$OG_GAPS" ]; then
  C=$(echo "$OG_GAPS" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [OG] $C public ctrl(s) sans buildPublicShareMeta (annotate '// og-skip-reason')"$'\n'
  echo "$OG_GAPS" | head -3 | while IFS= read -r line; do CONV_DETAILS="${CONV_DETAILS}      - $line"$'\n'; printf '      - %s\n' "$line" > /dev/null; done > /dev/null
fi

# ── B. Storage : canonical = StorageService — interdit `drive.use(` direct ──
DRIVE_DIRECT=$(grep -rn "drive\.use(" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "storage_service\.ts\|//.*canonical-skip:storage" || true)
if [ -n "$DRIVE_DIRECT" ]; then
  C=$(echo "$DRIVE_DIRECT" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Storage] $C direct drive.use() (canonical: StorageService.upload/delete/getStream)"$'\n'
  echo "$DRIVE_DIRECT" | head -3 | while IFS= read -r line; do printf '      - %s\n' "$line" > /dev/null; done > /dev/null
fi

# ── C. Auth scope : canonical = effectiveUserId — interdit `auth.user.id` direct ──
AUTH_RAW=$(grep -rnE "\.where\(['\"]userId['\"], auth\.user\?\.id" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:auth" || true)
AUTH_RAW2=$(grep -rnE "\.where\(['\"]user_id['\"], auth\.user\?\.id" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:auth" || true)
AUTH_TOTAL=$(printf '%s\n%s\n' "$AUTH_RAW" "$AUTH_RAW2" | grep -E ':[0-9]+:' || true)
if [ -n "$AUTH_TOTAL" ]; then
  C=$(echo "$AUTH_TOTAL" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Auth] $C .where('userId', auth.user.id) — canonical: effectiveUserId (middleware team)"$'\n'
fi

# ── C-bis. IDOR : .findOrFail / .firstOrFail sans .where('userId') adjacent ──
# Anti-pattern OWASP A01:2021 — un controller fetch un Model by ID sans verifier
# ownership. Detection multi-ligne perl : si Document/Gallery/Service/Contact/Booking
# .query() ... .firstOrFail() ne contient PAS .where('userId') dans la chaine,
# c'est un IDOR potentiel.
# v2 strict : match UNIQUEMENT .firstOrFail/.findOrFail (chemin critique throw)
# pas .first() qui retourne null safely. Exclus public/portal/admin/og/transfer-download
# qui auth par token, pas par userId.
PRIMARY_MODELS_RE="${PRIMARY_MODELS_RE:-Document|Gallery|Service|Contact|Booking|Transfer|Invoice|Quote}"
IDOR_RAW=$(perl -0777 -ne '
  my $models = $ENV{PRIMARY_MODELS_RE} || "Document|Gallery|Service|Contact|Booking|Transfer|Invoice|Quote";
  while (/(?<![A-Za-z])($models)\.(?:query|findOrFail|findByOrFail)\(\)([^;]{0,800}?)(?:\.firstOrFail\(|\.findOrFail\()/sg) {
    my ($model, $block) = ($1, $2);
    next if $block =~ /(?:where|whereHas|whereExists)\s*\(\s*["\x27]userId["\x27]\s*,/;
    next if $block =~ /(?:where|whereHas|whereExists)\s*\(\s*["\x27]user_id["\x27]\s*,/;
    next if $block =~ /canonical-skip:idor/;
    my $pos = $-[0];
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line:$model\n";
  }
' app/controllers/*.ts app/controllers/**/*.ts 2>/dev/null \
  | grep -vE "/(public_|portal_|admin/|og_image_|transfer_download_)" || true)
if [ -n "$IDOR_RAW" ]; then
  C=$(echo "$IDOR_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [IDOR] $C Model.query().firstOrFail() sans .where('userId') (annotate '// canonical-skip:idor:<reason>' si public/admin/token-auth)"$'\n'
fi

# ── D. Soft-delete : canonical = .whereNull('deletedAt') ──────────────────
# Detection multi-ligne : un <PRIMARY_MODELS>.query() suivi d'une chaine .where...().first()/etc
# doit contenir whereNull('deletedAt') dans la chaine. Le set de models cible
# est gouverne par CLAUDE.md §5 (PRIMARY_MODELS_RE). Perl slurp mode car bash
# grep est mono-ligne et donne des faux positifs.
DOC_NO_SOFT=$(perl -0777 -ne '
  my $models = $ENV{PRIMARY_MODELS_RE} || "Document|Gallery|Service|Contact|Booking|Transfer|Invoice|Quote";
  while (/(?<![A-Za-z])($models)\.query\(\)([^;]*?)(?:\.first\(|\.firstOrFail\(|\.exec\(|\.paginate\(|\.count\(|\.update\(|\.delete\(|\.forUpdate\()/sg) {
    my ($model, $block) = ($1, $2);
    next if $block =~ /whereNull\(["\x27]deletedAt["\x27]\)/;
    next if $block =~ /canonical-skip:soft-delete/;
    my $pos = $-[0];
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line\n";
  }
' app/controllers/*.ts app/services/*.ts 2>/dev/null \
  | grep -v "document_service\.ts\|admin_wrapped_service\.ts\|wrapped_service\.ts" || true)
if [ -n "$DOC_NO_SOFT" ]; then
  C=$(echo "$DOC_NO_SOFT" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [SoftDelete] $C <PRIMARY_MODELS>.query() sans .whereNull('deletedAt') (cf CLAUDE.md §5 ; canonical-skip:soft-delete pour opt-out)"$'\n'
fi

# ── E. Public branding : canonical = the project's branding loader ─────────
# Detect controllers publics qui calculent un brandLogo/brandName a la main
# (lecture directe user.company?.logo) sans passer par le branding loader
# du projet (typique : `BrandingService.loadPublicBranding` — varie par projet,
# cf CLAUDE.md §5).
# Multi-ligne car les annotations canonical-skip:branding sont sur la ligne
# au-dessus du code (mono-ligne grep raterait).
BRAND_RAW=$(perl -0777 -ne '
  while (/(?:user|gallery\.user)\??\.company\??\.logo/g) {
    my $pos = $-[0];
    my $idx = $pos;
    # Walk back 10 newlines pour englober une annotation comment multi-ligne
    for (my $i = 0; $i < 10; $i++) { my $prev = rindex($_, "\n", $idx - 1); last if $prev < 0; $idx = $prev; }
    my $context = substr($_, $idx, $pos - $idx);
    next if $context =~ /canonical-skip:branding/;
    next if $context =~ /BrandingService\.loadPublicBranding/;
    my $line = (substr($_, 0, $pos) =~ tr/\n//) + 1;
    print "$ARGV:$line\n";
  }
' app/controllers/public_*.ts 2>/dev/null \
  | grep -v "og_image_controller" || true)
if [ -n "$BRAND_RAW" ]; then
  C=$(echo "$BRAND_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Branding] $C reads user.company.logo directly (canonical: branding loader public — cf CLAUDE.md §5)"$'\n'
fi

# ── F. fire-and-forget promises : canonical = swallow() helper ──────────────
# Audit 2026-04-15 a corrige 81 sites — la regex catch les .catch(() => {})
# avec arg vide ou un seul ident, body vide. Voir docs/anti-patterns.md.
FAF_RAW=$(grep -rnE "\.catch\(\(?[a-z_]*\)? *=> *\{\}\)" app/controllers/ app/services/ --include="*.ts" 2>/dev/null \
  | grep -v "//.*canonical-skip:swallow" || true)
if [ -n "$FAF_RAW" ]; then
  C=$(echo "$FAF_RAW" | wc -l | tr -d ' \r')
  CONV_HITS=$((CONV_HITS + C))
  CONV_DETAILS="${CONV_DETAILS}  [Swallow] $C raw .catch(() => {}) (canonical: import swallow from '#helpers/swallow'; .catch(swallow('op_name')))"$'\n'
fi

# ── Verdict ────────────────────────────────────────────────────────────────
if [ $CONV_HITS -eq 0 ]; then
  pass "All conventions respected (OG/Storage/Auth/SoftDelete/Branding/Swallow)"
else
  warn "$CONV_HITS convention divergence(s) — review or annotate '// canonical-skip:<rule>:<reason>'"
  printf '%s' "$CONV_DETAILS" | head -12
fi
