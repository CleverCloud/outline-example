#!/usr/bin/env bash
set -euo pipefail

: "${OUTLINE_URL:?Set OUTLINE_URL to the exact HTTPS origin of your Outline application}"
: "${OUTLINE_BUCKET:?Set OUTLINE_BUCKET to a globally unique bucket name}"
: "${CELLAR_ADDON_KEY_ID:?Load the linked Cellar add-on variables first}"
: "${CELLAR_ADDON_KEY_SECRET:?Load the linked Cellar add-on variables first}"
: "${CELLAR_ADDON_HOST:?Load the linked Cellar add-on variables first}"

outline_cors_file="$(mktemp)"
trap 'rm -f "$outline_cors_file"' EXIT

s3cmd --access_key="$CELLAR_ADDON_KEY_ID" \
  --secret_key="$CELLAR_ADDON_KEY_SECRET" \
  --host="$CELLAR_ADDON_HOST" \
  --host-bucket="$CELLAR_ADDON_HOST" \
  --ssl mb "s3://$OUTLINE_BUCKET"

cat > "$outline_cors_file" <<EOF
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>${OUTLINE_URL}</AllowedOrigin>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
  </CORSRule>
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
  </CORSRule>
</CORSConfiguration>
EOF

s3cmd --access_key="$CELLAR_ADDON_KEY_ID" \
  --secret_key="$CELLAR_ADDON_KEY_SECRET" \
  --host="$CELLAR_ADDON_HOST" \
  --host-bucket="$CELLAR_ADDON_HOST" \
  --ssl setcors "$outline_cors_file" "s3://$OUTLINE_BUCKET"

printf 'Configured private Cellar bucket %s for %s\n' "$OUTLINE_BUCKET" "$OUTLINE_URL"
