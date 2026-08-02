-- katalog_vorschlaege.sql – Ein dritter Feedback-Typ: `katalog`
-- (Nutzerkonzept §5, Issue #103).
--
-- Wer einen selbst angelegten Gerätetyp für den GLOBALEN Katalog vorschlagen
-- will, schickt ihn über den bestehenden Feedback-Weg: App → Tabelle
-- `feedback` → Bot (tool/feedback_bot.py) → öffentliches Issue mit eigenem
-- Label. Bewusst KEINE neue Edge Function und kein neuer Weg — die App kennt
-- damit weiterhin kein Geheimnis, der Service-Key bleibt beim Bot als
-- GitHub-Secret.
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
  check (type in ('feature', 'bug', 'katalog'));
