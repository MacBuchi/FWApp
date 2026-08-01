-- autodeploy_probe.sql – End-zu-End-Probe von Route A (Issue #74).
--
-- Absichtlich folgenlos: Diese Migration existiert, um EINMAL den ganzen
-- automatischen Weg zu beweisen — Merge auf main → Manifest → Timer auf der
-- VM → frischer Dump → Generalprobe → Einspielen → Ledger-Eintrag 'auto'.
-- Der Kommentar unten ist zugleich der sichtbare Beweis in der Datenbank.

comment on table deploy.applied_migrations is
  'Welche Migration hat DIESE Datenbank gesehen? Quelle der Wahrheit für '
  'tool/vm/fwapp_autodeploy.sh; rollt bei einem Restore mit zurück. '
  'Route-A-Probe bestanden am 2026-08-01 (Issue #74).';
