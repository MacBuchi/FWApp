#!/usr/bin/env bash
# setup_local_supabase.sh – Creates the local test users the sync E2E test
# expects (admin@fw.local / member@fw.local, pw test1234) and promotes the
# admin. Idempotent; run after `supabase start` or `supabase db reset`.
# Uses the well-known local demo service key (same on every machine).
set -euo pipefail

API="${SUPABASE_URL:-http://127.0.0.1:54321}"
SR="${SUPABASE_SERVICE_ROLE_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU}"

auth() { curl -s -H "apikey: $SR" -H "Authorization: Bearer $SR" "$@"; }

user_id_by_email() {
  auth "$API/auth/v1/admin/users?per_page=100" |
    python3 -c "import json,sys; users=json.load(sys.stdin).get('users',[]); print(next((u['id'] for u in users if u.get('email')=='$1'), ''))"
}

ensure_user() {
  local email="$1"
  local id
  id=$(auth -X POST "$API/auth/v1/admin/users" -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"test1234\",\"email_confirm\":true}" |
    python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')
  if [ -z "$id" ]; then
    id=$(user_id_by_email "$email")
  fi
  if [ -z "$id" ]; then
    echo "FEHLER: Konnte Benutzer $email weder anlegen noch finden." >&2
    exit 1
  fi
  echo "$id"
}

ADMIN_ID=$(ensure_user admin@fw.local)
GW_ID=$(ensure_user geraetewart@fw.local)
ensure_user member@fw.local > /dev/null

auth -X PATCH "$API/rest/v1/profiles?id=eq.$ADMIN_ID" \
  -H "Content-Type: application/json" -d '{"role":"admin"}' > /dev/null
auth -X PATCH "$API/rest/v1/profiles?id=eq.$GW_ID" \
  -H "Content-Type: application/json" -d '{"role":"geraetewart"}' > /dev/null

echo "OK: admin@fw.local (admin), geraetewart@fw.local (geraetewart) und member@fw.local (member) eingerichtet."
