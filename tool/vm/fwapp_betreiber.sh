#!/usr/bin/env bash
### fwapp_betreiber.sh – Den KreisDatenMeister dieser Installation setzen
### (Nutzerkonzept Stufe ④, Issue #101).
###
### Läuft AUF DER VM (bzw. dem Server, auf dem der Stack liegt), wie der
### Autodeploy. Es gibt bewusst keinen Weg aus der App heraus: Wer
### KreisDatenMeister wird, entscheidet, wer den Server betreibt — und der
### hat SSH. Ein Admin-Portal dafür wäre Angriffsfläche für eine Handlung,
### die einmal im Leben einer Installation vorkommt (NUTZERKONZEPT §8).
###
### Aufruf:
###   fwapp_betreiber.sh setzen  <mail> ["<Kontaktzeile>"]
###   fwapp_betreiber.sh kontakt <mail> "<Kontaktzeile>"   # nur die Zeile ändern
###   fwapp_betreiber.sh entfernen <mail>
###   fwapp_betreiber.sh liste
###
### Die Kontaktzeile steht ÖFFENTLICH auf der Login-Seite jeder App, die mit
### diesem Server spricht („Deine Wehr ist noch nicht dabei? …"). Eine
### Funktionsadresse ist dort besser als die private.
###
### ⚠️ Das Konto muss es schon geben (bestätigte Mail-Adresse). Das Skript
### legt keins an: Ein Konto samt Passwort über die Kommandozeile zu
### erzeugen hieße, ein Passwort durch die Shell-History zu schicken. Der
### Weg ist eine Einladung durch einen Kommandanten oder die Auth-Admin-API
### (docs/SERVER-SETUP.md, Abschnitt KreisDatenMeister).
set -euo pipefail

DB_CONTAINER=${DB_CONTAINER:-supabase-db}
# Überschreibbar für den lokalen Stack (dort ohne sudo):
#   DOCKER=docker DB_CONTAINER=supabase_db_FWApp tool/vm/fwapp_betreiber.sh …
DOCKER=${DOCKER:-sudo docker}

psql_db() { # SQL von stdin, Variablen per -v, bricht bei Fehler ab
  $DOCKER exec -i "$DB_CONTAINER" psql -U supabase_admin -d postgres \
    -v ON_ERROR_STOP=1 -Atq "$@"
}

nutzung() {
  sed -n 's/^### \{0,1\}//p' "$0" | sed -n '/^Aufruf:/,/^$/p'
  exit 2
}

[ $# -ge 1 ] || nutzung
aktion=$1
shift

case "$aktion" in
  setzen)
    [ $# -ge 1 ] || nutzung
    psql_db -v mail="$1" -v kontakt="${2:-}" <<'SQL'
-- psql-Variablen wirken in einem $$-Block nicht; set_config reicht sie
-- hinein, ohne dass die Adresse in SQL-Text zusammengeklebt wird.
select set_config('fwapp.mail', :'mail', false),
       set_config('fwapp.kontakt', :'kontakt', false) \g /dev/null
do $$
declare
  v_user uuid;
begin
  select u.id into v_user from auth.users u
   where lower(u.email) = lower(btrim(current_setting('fwapp.mail')))
     and u.email_confirmed_at is not null;
  if v_user is null then
    raise exception 'Kein bestaetigtes Konto zu %', current_setting('fwapp.mail');
  end if;
  insert into public.betreiber (user_id, kontakt)
  values (v_user, nullif(btrim(current_setting('fwapp.kontakt')), ''))
  on conflict (user_id) do update
    set kontakt = coalesce(excluded.kontakt, public.betreiber.kontakt);
  raise notice 'KreisDatenMeister gesetzt: %', current_setting('fwapp.mail');
end
$$;
SQL
    ;;
  kontakt)
    [ $# -ge 2 ] || nutzung
    psql_db -v mail="$1" -v kontakt="$2" <<'SQL'
update public.betreiber b
   set kontakt = nullif(btrim(:'kontakt'), '')
  from auth.users u
 where u.id = b.user_id and lower(u.email) = lower(btrim(:'mail'))
returning 'Kontaktzeile gesetzt';
SQL
    ;;
  entfernen)
    [ $# -ge 1 ] || nutzung
    psql_db -v mail="$1" <<'SQL'
delete from public.betreiber b
 using auth.users u
 where u.id = b.user_id and lower(u.email) = lower(btrim(:'mail'))
returning 'entfernt';
SQL
    ;;
  liste)
    psql_db <<'SQL'
select u.email || coalesce('  |  ' || b.kontakt, '')
  from public.betreiber b join auth.users u on u.id = b.user_id
 order by b.created_at;
SQL
    ;;
  *) nutzung ;;
esac
