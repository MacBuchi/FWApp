-- 20260805130000_feedback_fahrzeug_vorschlag.sql – Ein vierter Feedback-Typ:
-- `fahrzeug` (Issue #145).
--
-- Wer eine fehlende Fahrzeug-Vorlage vorschlagen will, schickt sie über den
-- bestehenden Feedback-Weg: App → Tabelle `feedback` → Bot
-- (tool/feedback_bot.py) → öffentliches Issue mit eigenem Label
-- `fahrzeug-vorschlag`. Dieselbe Entscheidung wie beim Katalog-Vorschlag
-- (20260802180000): kein neuer Endpunkt, kein Geheimnis in der App.
--
-- Mehr als der Typ ändert sich nicht: RLS, Grants und die Längenprüfung der
-- Nachricht gelten unverändert, und der Bot liest ohnehin alle Zeilen.
--
-- ⚠️ Reihenfolge: Diese Migration muss VOR dem App-Release draußen sein,
-- sonst lehnt Postgres den Vorschlag mit einer Constraint-Verletzung ab und
-- die App meldet nur „Senden fehlgeschlagen". Der Autodeploy (Route A) holt
-- sie sich beim Merge, das APK braucht danach noch seinen Build.

alter table public.feedback drop constraint feedback_type_check;

alter table public.feedback add constraint feedback_type_check
  check (type in ('feature', 'bug', 'katalog', 'fahrzeug'));
