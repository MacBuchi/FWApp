"""test_fwapp_sicherung.py – Die Regeln der Sicherung (#247, #248) ohne Docker.

Dass Sicherung und automatisches Zurückspielen wirklich funktionieren —
Datenbank, Fotos samt Inhaltstyp, Schlüssel —, beweist der Docker-Nachweis
in docs/INSTALLATION.md. Hier steht, WAS gesichert wird (fehlt ein Volume in
der Liste, fällt das erst beim Zurückspielen auf, also zu spät), wie viele
Sicherungen bleiben und woran die Sicherungsplatte erkannt wird.
"""
import os
import tempfile
import unittest
from unittest import mock

import fwapp_install as inst
import fwapp_sicherung as s


def container(name, *mounts):
    return {"Name": f"/{name}", "Mounts": list(mounts)}


def vol(name, ziel, rw=True):
    return {"Type": "volume", "Name": name, "Destination": ziel, "RW": rw}


def bind(quelle, ziel, rw=True):
    return {"Type": "bind", "Source": quelle, "Destination": ziel, "RW": rw}


class Ziele(unittest.TestCase):
    INSPECT = [
        container(
            "supabase-db",
            bind("/srv/fwapp/db", "/var/lib/postgresql/data"),
            vol("fwapp_db-config", "/etc/postgresql-custom"),
            bind("/srv/fwapp/server/db/roles.sql", "/docker-entrypoint-initdb.d/x.sql", rw=False),
        ),
        container("supabase-storage", bind("/srv/fwapp/storage", "/var/lib/storage")),
        container(
            "fwapp-web",
            bind("/srv/fwapp/web", "/usr/share/nginx/html", rw=False),
            bind("/srv/fwapp/server/nginx.conf", "/etc/nginx/conf.d/default.conf", rw=False),
        ),
        container("supabase-edge-functions", bind("/srv/fwapp/functions", "/home/deno/functions")),
        container("fwapp-caddy", vol("fwapp_caddy-data", "/data")),
    ]

    def test_alles_beschreibbare_und_nur_das(self):
        pfade = {(z.container, z.pfad) for z in s.ziele_aus_inspect(self.INSPECT)}
        self.assertEqual(
            pfade,
            {
                ("supabase-db", "/var/lib/postgresql/data"),
                ("supabase-db", "/etc/postgresql-custom"),  # ⚠️ pgsodium-Schlüssel
                ("supabase-storage", "/var/lib/storage"),
                ("supabase-edge-functions", "/home/deno/functions"),
                ("fwapp-caddy", "/data"),  # Zertifikate: sonst neu beantragen, Rate-Limit
            },
        )

    def test_der_pfad_des_rechners_spielt_keine_rolle(self):
        """Docker Desktop meldet /host_mnt/… — ein Pfad, den es auf dem
        Rechner nicht gibt. Die erste Fassung prüfte ihn auf dem Rechner und
        übersprang die Datenbank still. Heute hängt der Helfer die Daten
        über den Container ein; der Pfad wird nie angefasst."""
        inspect = [container("supabase-db", bind("/host_mnt/gibt/es/nicht", "/var/lib/postgresql/data"))]
        self.assertEqual(
            [(z.container, z.pfad) for z in s.ziele_aus_inspect(inspect)],
            [("supabase-db", "/var/lib/postgresql/data")],
        )

    def test_ohne_datenbank_oder_fotos_keine_sicherung(self):
        ziele = s.ziele_aus_inspect(self.INSPECT)
        self.assertEqual(s.fehlende_pflicht(ziele), [])
        ohne_db = [z for z in ziele if z.pfad != "/var/lib/postgresql/data"]
        self.assertEqual(s.fehlende_pflicht(ohne_db), ["/var/lib/postgresql/data"])

    def test_geteiltes_volume_nur_einmal(self):
        inspect = [container("a", vol("v", "/x")), container("b", vol("v", "/y"))]
        self.assertEqual(len(s.ziele_aus_inspect(inspect)), 1)


class Werkzeug(unittest.TestCase):
    def test_borg_steht_gepinnt_im_buendel(self):
        text = (inst.HIER / "docker-compose.yml").read_text()
        image = s.borg_image([text])
        self.assertIn("borg", image)
        self.assertRegex(image, r":\d{8}_\d{6}$", "datierter Tag, kein latest")

    def test_das_werkzeug_startet_nie_mit_dem_stack(self):
        text = (inst.HIER / "docker-compose.yml").read_text()
        block = text[text.index("  borg:"):]
        self.assertIn("profiles:", block.split("\n\n")[0])

    def test_ohne_werkzeug_keine_sicherung(self):
        with self.assertRaises(inst.Abbruch):
            s.borg_image(["services:\n  web:\n    image: nginx:1\n"])


class Kommentar(unittest.TestCase):
    def test_klammern_verdoppelt_und_nach_borg_wieder_json(self):
        daten = {"version": "v1.64.0", "ziele": [{"pfad": "/var/lib/storage"}]}
        k = s.borg_kommentar(daten)
        self.assertNotRegex(k.replace("{{", "").replace("}}", ""), r"[{}]")
        # Borg macht aus {{ wieder { — was `borg list` zurückgibt, ist JSON.
        import json

        self.assertEqual(json.loads(k.replace("{{", "{").replace("}}", "}")), daten)


class Aufbewahrung(unittest.TestCase):
    def test_namen_tragen_zeit_und_anlass(self):
        name = s.archiv_name("vor-v1.64.0", jetzt=0)
        self.assertRegex(name, r"^\d{8}-\d{6}-vor-v1\.64\.0$")
        self.assertEqual(s.anlass_von(name), "vor")
        self.assertEqual(s.anlass_von("20260927-023000-woche"), "woche")
        self.assertEqual(s.anlass_von("20260927-023000-von-hand"), "von-hand")

    def test_vier_wochen_zwei_vor_updates(self):
        """Marcus 2026-09-23: vier Wochensicherungen behalten (#248)."""
        wochen = [f"2026090{i}-023000-woche" for i in range(1, 7)]
        vor = [f"2026091{i}-030000-vor-v1.6{i}.0" for i in range(1, 4)]
        weg = s.zu_loeschen(wochen + vor)
        self.assertEqual(weg, sorted(wochen[:2] + vor[:1]))

    def test_anlaesse_verdraengen_sich_nicht(self):
        # Viele Updates in einer Woche dürfen keine Wochensicherung löschen.
        namen = ["20260901-023000-woche"] + [f"2026090{i}-030000-vor-v1.{i}.0" for i in range(2, 9)]
        self.assertNotIn("20260901-023000-woche", s.zu_loeschen(namen))


class Platz(unittest.TestCase):
    GIB = 1024**3

    def test_neues_archiv_braucht_die_daten_einmal(self):
        self.assertFalse(s.platz_reicht(3 * self.GIB, 3 * self.GIB, archiv_neu=True))
        self.assertTrue(s.platz_reicht(5 * self.GIB, 3 * self.GIB, archiv_neu=True))

    def test_bestehendes_nur_die_aenderungen(self):
        """Das ist der Gewinn von Borg: vier Wochen kosten nicht viermal."""
        self.assertTrue(s.platz_reicht(2 * self.GIB, 30 * self.GIB, archiv_neu=False))


class Sicherungsplatte(unittest.TestCase):
    def test_fehlt_das_verzeichnis(self):
        with tempfile.TemporaryDirectory() as data:
            grund = s.externes_ziel("/gibt/es/nicht", data)
            self.assertIn("nicht angeschlossen", grund)

    def test_nicht_eingehaengt_heisst_gleicher_datentraeger(self):
        """Ohne Platte ist der Einhängepunkt ein leerer Ordner auf der SSD.
        Eine Sicherung dorthin schützte vor nichts."""
        with tempfile.TemporaryDirectory() as data:
            ziel = os.path.join(data, "usb")
            os.mkdir(ziel)
            self.assertIn("nicht eingehängt", s.externes_ziel(ziel, data))

    def test_anderer_datentraeger_ist_gut(self):
        with tempfile.TemporaryDirectory() as data, tempfile.TemporaryDirectory() as ziel:
            echt = os.stat

            def stat(pfad, *a, **k):
                r = echt(pfad, *a, **k)
                if pfad == ziel:
                    return os.stat_result((*r[:2], r.st_dev + 1, *r[3:]))
                return r

            with mock.patch("os.stat", stat):
                self.assertIsNone(s.externes_ziel(ziel, data))


if __name__ == "__main__":
    unittest.main()
