#!/usr/bin/env bash
### ci_supabase_start.sh – Den lokalen Supabase-Stack in CI starten, robust
### gegen Drosselung der Image-Registries. Genutzt von ci.yml und
### supabase-preview.yml.
###
### Drei Dinge, jedes mit Grund:
###
### 1. Die Registry-Vorgabe der Action wird aufgehoben. `supabase/setup-cli`
###    setzt SUPABASE_INTERNAL_IMAGE_REGISTRY=ghcr.io — und eine gesetzte
###    Registry schaltet die Ausweichkette der CLI ab (public.ecr.aws →
###    ghcr.io → Docker Hub, siehe GetRegistryImageUrls in der CLI). Am
###    2026-09-23 drosselte ghcr.io die Runner („toomanyrequests") und die CI
###    wurde zweimal hintereinander rot, ohne dass ein Test lief.
### 2. Nur die Dienste, die die Tests brauchen. Gemessen in #239: Alle
###    E2E-Tests laufen grün ohne Logflare, imgproxy, postgres-meta,
###    Realtime, Studio und vector — weniger Images heißt weniger Downloads,
###    die gedrosselt werden können. Mailpit (inbucket) bleibt: Die
###    Einladungs- und Reset-Tests lesen ihre Mails dort.
###    ⚠️ `-x` will die IMAGE-Namen. Die Namen aus `supabase start --help`
###    („analytics", „meta") nimmt die CLI stillschweigend an und startet
###    die Dienste trotzdem — lokal nachgesehen mit `docker ps`.
### 3. Drei Versuche mit Pause. Eine Drosselung ist vorübergehend.
set -euo pipefail

unset SUPABASE_INTERNAL_IMAGE_REGISTRY

for versuch in 1 2 3; do
  if supabase start -x logflare,imgproxy,postgres-meta,realtime,studio,vector; then
    exit 0
  fi
  echo "::warning::supabase start scheiterte (Versuch $versuch/3) — neuer Versuch in $((versuch * 30)) s"
  supabase stop --no-backup || true
  sleep $((versuch * 30))
done
echo "::error::supabase start scheiterte dreimal"
exit 1
