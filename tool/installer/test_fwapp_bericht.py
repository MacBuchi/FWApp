"""test_fwapp_bericht.py – Die Auswertung des Wochenberichts, ohne Docker.

Ein Bericht, der jede Woche „312 Auffälligkeiten" meldet, liest nach dem
dritten Mal niemand mehr — und einer, der einen vollen Datenträger als ✅
zeigt, ist schlimmer als keiner. Deshalb stehen hier die Regeln: was als
Fehler zählt, wie gleiche Meldungen zusammenfallen, wo die Schwellen liegen,
und dass der Betreff die Ampel trägt.
"""
import io
import json
import unittest
import zipfile

import fwapp_bericht as b

GIB = 1024**3

# Echte Zeilen aus den Diensten (gekürzt), wie sie im Stack vorkommen.
GOTRUE_FEHLER = '{"level":"error","msg":"Unhandled server error: context canceled","request_id":"3f0c1a2e-8b7d-4c2a-9e1f-0a1b2c3d4e5f","time":"2026-09-20T10:00:01Z"}'
GOTRUE_INFO = '{"level":"info","msg":"request completed","path":"/token","status":200}'
POSTGRES_FEHLER = '2026-09-20 10:00:02.123 UTC [4711] ERROR:  duplicate key value violates unique constraint "x_pkey"'
KONG_500 = '172.18.0.9 - - [20/Sep/2026:10:00:03 +0000] "POST /rest/v1/rpc/publish_snapshot HTTP/1.1" 500 87 "-" "Dart/3.13"'
KONG_200 = '172.18.0.9 - - [20/Sep/2026:10:00:03 +0000] "GET /rest/v1/ HTTP/1.1" 200 12 "-" "Dart/3.13"'
NGINX_FEHLER = '2026/09/20 10:00:04 [error] 29#29: *1 open() "/usr/share/nginx/html/x" failed'


class Fehlererkennung(unittest.TestCase):
    def test_echte_fehler_werden_erkannt(self):
        for zeile in (GOTRUE_FEHLER, POSTGRES_FEHLER, KONG_500, NGINX_FEHLER,
                      "Traceback (most recent call last):", "panic: runtime error"):
            with self.subTest(zeile=zeile[:40]):
                self.assertTrue(b.ist_fehler(zeile))

    def test_normalbetrieb_ist_kein_fehler(self):
        for zeile in (GOTRUE_INFO, KONG_200, "LOG:  checkpoint complete",
                      "could not receive data from client: Connection reset by peer ERROR",
                      "[crit] 1110#0: *395 [lua] targets.lua:248: could not reschedule DNS "
                      "resolver timer: process exiting"):
            with self.subTest(zeile=zeile[:40]):
                self.assertFalse(b.ist_fehler(zeile))

    def test_gleiche_meldung_mit_anderer_id_faellt_zusammen(self):
        """Sonst stünden 40 „verschiedene" Fehler da, die derselbe sind."""
        zeilen = [GOTRUE_FEHLER.replace("3f0c1a2e", f"{i:08x}") for i in range(40)]
        zeilen += [POSTGRES_FEHLER] * 3 + [GOTRUE_INFO] * 100
        anzahl, haeufig = b.fehler_auswerten(zeilen)
        self.assertEqual(anzahl, 43)
        self.assertEqual([n for n, _ in haeufig], [40, 3])
        self.assertIn("context canceled", haeufig[0][1])


class Schwellen(unittest.TestCase):
    def test_platte(self):
        self.assertEqual(b.bewerte_platte("/srv", 64 * GIB, 40 * GIB).stufe, b.OK)
        self.assertEqual(b.bewerte_platte("/srv", 64 * GIB, 6 * GIB).stufe, b.HINWEIS)
        self.assertEqual(b.bewerte_platte("/srv", 64 * GIB, 1 * GIB).stufe, b.PROBLEM)
        # Große Platte: 60 GB frei sind nur 6 % — ein Hinweis, noch kein Problem.
        self.assertEqual(b.bewerte_platte("/srv", 1000 * GIB, 60 * GIB).stufe, b.HINWEIS)

    def test_speicher_last_temperatur(self):
        self.assertEqual(b.bewerte_speicher(8_000_000, 400_000).stufe, b.HINWEIS)
        self.assertEqual(b.bewerte_speicher(8_000_000, 3_000_000).stufe, b.OK)
        self.assertEqual(b.bewerte_last(5.0, 4).stufe, b.HINWEIS)
        self.assertEqual(b.bewerte_last(0.4, 4).stufe, b.OK)
        self.assertIsNone(b.bewerte_temperatur(None))  # VM: kein Sensor
        self.assertEqual(b.bewerte_temperatur(82).stufe, b.PROBLEM)

    def test_zertifikat(self):
        self.assertEqual(b.bewerte_zertifikat("x.de", 60).stufe, b.OK)
        self.assertEqual(b.bewerte_zertifikat("x.de", 14).stufe, b.HINWEIS)
        self.assertEqual(b.bewerte_zertifikat("x.de", 3).stufe, b.PROBLEM)
        self.assertEqual(b.bewerte_zertifikat("x.de", None, "timeout").stufe, b.HINWEIS)

    def test_sicherung_zu_alt_ist_ein_problem(self):
        self.assertEqual(b.bewerte_sicherung("Wochensicherung", 3 * 86400, 8).stufe, b.OK)
        self.assertEqual(b.bewerte_sicherung("Wochensicherung", 10 * 86400, 8).stufe, b.PROBLEM)
        self.assertEqual(b.bewerte_sicherung("Dump", None, 2).stufe, b.PROBLEM)

    def test_container(self):
        self.assertEqual(b.bewerte_container("db", "exited", "", 0, None).stufe, b.PROBLEM)
        self.assertEqual(b.bewerte_container("db", "running", "unhealthy", 0, None).stufe, b.PROBLEM)
        self.assertEqual(b.bewerte_container("db", "running", "healthy", 3, None).stufe, b.HINWEIS)
        ok = b.bewerte_container("db", "running", "healthy", 0, 2 * 86400)
        self.assertEqual(ok.stufe, b.OK)
        self.assertIn("neu gestartet", ok.text)  # nach einem Update — Info, kein Alarm


class Text(unittest.TestCase):
    def abschnitte(self, *stufen):
        return [b.Abschnitt("Teil", befunde=[b.Befund(s, f"Befund {s}") for s in stufen])]

    def test_betreff_traegt_die_ampel(self):
        self.assertIn("✅ alles in Ordnung", b.betreff("FW", self.abschnitte(b.OK)))
        self.assertIn("⚠️ 2 Hinweise", b.betreff("FW", self.abschnitte(b.HINWEIS, b.HINWEIS, b.OK)))
        self.assertIn("❌ 1 Problem", b.betreff("FW", self.abschnitte(b.PROBLEM, b.HINWEIS)))

    def test_auffaelliges_steht_oben(self):
        text = b.als_text("FW", self.abschnitte(b.OK, b.PROBLEM), jetzt=0)
        oben = text.split("──")[0]
        self.assertIn("Befund problem", oben)
        self.assertNotIn("Befund ok", oben)

    def test_ausbleiben_ist_selbst_ein_zeichen(self):
        self.assertIn("Bleibt er aus", b.als_text("FW", self.abschnitte(b.OK)))


class Anhang(unittest.TestCase):
    def test_zip_mit_allen_logs(self):
        daten = b.logs_zip({"supabase-db.log": "a\nb", "update.log": "c"}, 10**6)
        with zipfile.ZipFile(io.BytesIO(daten)) as z:
            self.assertEqual(sorted(z.namelist()), ["supabase-db.log", "update.log"])

    def test_zu_gross_wird_gekuerzt_das_neueste_bleibt(self):
        import os

        rauschen = os.urandom(600_000).hex()  # nicht komprimierbar
        daten = b.logs_zip({"gross.log": rauschen + "\nNEUESTE ZEILE", "klein.log": "x"}, 400_000)
        self.assertLessEqual(len(daten), 400_000)
        with zipfile.ZipFile(io.BytesIO(daten)) as z:
            self.assertTrue(z.read("gross.log").decode().endswith("NEUESTE ZEILE"))
            self.assertEqual(z.read("klein.log"), b"x")


class Mail(unittest.TestCase):
    def test_an_den_kreisdatenmeister_mit_zip(self):
        m = b.mail({"KDM_EMAIL": "kdm@x.de", "MAIL_ABSENDER": "a@x.de"}, "Betreff", "Text", b"PK")
        self.assertEqual(m["To"], "kdm@x.de")
        self.assertEqual([t.get_content_type() for t in m.iter_attachments()], ["application/zip"])

    def test_eigener_empfaenger_moeglich(self):
        """Unsere VM hat noch keinen KreisDatenMeister — dort geht der
        Bericht an BERICHT_AN."""
        m = b.mail({"KDM_EMAIL": "kdm@x.de", "BERICHT_AN": "betrieb@x.de"}, "B", "T", b"")
        self.assertEqual(m["To"], "betrieb@x.de")


class Sammeln(unittest.TestCase):
    def test_container_und_logs_ueber_docker(self):
        """Mit einer Attrappe statt Docker: welche Befehle fallen, und was
        daraus wird."""
        container = [{"Name": "/supabase-auth", "RestartCount": 0,
                      "State": {"Status": "running", "Health": {"Status": "healthy"},
                                "StartedAt": "2026-01-01T00:00:00.0Z"}}]
        aufrufe = []

        def lauf(*befehl, zeitlimit=0):
            aufrufe.append(befehl)
            if befehl[1] == "ps":
                return 0, "abc123\n"
            if befehl[1] == "inspect":
                return 0, json.dumps(container)
            if befehl[1] == "logs":
                return 0, "\n".join([GOTRUE_FEHLER, GOTRUE_INFO])
            if befehl[1] == "stats":
                return 0, "supabase-auth\t20MiB / 6GiB"
            return 1, ""

        bericht = b.Bericht({"DATA_DIR": "/gibt/es/nicht"}, lauf=lauf)
        c = bericht.container()
        self.assertIn(("--filter", "label=com.docker.compose.project=fwapp"),
                      [tuple(a[4:6]) for a in aufrufe if a[1] == "ps"])
        dienste = bericht.dienste(c)
        self.assertEqual(dienste.befunde[0].stufe, b.OK)
        self.assertIn("20MiB", dienste.zeilen[0])
        logs = bericht.auffaelligkeiten(c)
        self.assertIn("1 Fehlerzeilen", logs.befunde[0].text)
        self.assertIn("supabase-auth.log", bericht.logs_fuer_anhang)


if __name__ == "__main__":
    unittest.main()
