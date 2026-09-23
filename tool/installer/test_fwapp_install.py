"""test_fwapp_install.py – Die Logik des Installers (#241) ohne Docker.

Den ganzen Ablauf mit Docker beweist der Testmodus: Installer bauen lassen,
dann alle E2E-Tests aus test/integration/ gegen den gebauten Server (siehe
docs/INSTALLATION.md). Hier stehen die Regeln, die dabei nicht auffallen
würden — vor allem, dass ein zweiter Lauf die Schlüssel NICHT erneuert.
"""
import base64
import hashlib
import hmac
import json
import unittest

import fwapp_install as i

CONF = {
    "ERREICHBARKEIT": "caddy",
    "DOMAIN": "app.musterstadt.de",
    "NAME": "Feuerwehr Musterstadt",
    "DATA_DIR": "/srv/fwapp",
    "KDM_EMAIL": "kdm@musterstadt.de",
    "MAIL_ABSENDER": "app@musterstadt.de",
    "SMTP_HOST": "smtp.example.org",
}


def _teil(token, n):
    t = token.split(".")[n]
    return json.loads(base64.urlsafe_b64decode(t + "=" * (-len(t) % 4)))


class Schluessel(unittest.TestCase):
    def test_jwt_ist_mit_dem_geheimnis_signiert(self):
        t = i.jwt("geheim", "anon", jetzt=1_000_000)
        kopf, nutz, sig = t.split(".")
        erwartet = hmac.new(b"geheim", f"{kopf}.{nutz}".encode(), hashlib.sha256).digest()
        self.assertEqual(base64.urlsafe_b64encode(erwartet).rstrip(b"=").decode(), sig)
        self.assertEqual(_teil(t, 0)["alg"], "HS256")
        inhalt = _teil(t, 1)
        self.assertEqual(inhalt["role"], "anon")
        self.assertGreater(inhalt["exp"], inhalt["iat"])

    def test_neue_schluessel_sind_zufaellig_und_zeichensicher(self):
        a = i.neue_geheimnisse(False, jetzt=1)
        b = i.neue_geheimnisse(False, jetzt=1)
        self.assertNotEqual(a["JWT_SECRET"], b["JWT_SECRET"])
        self.assertNotEqual(a["POSTGRES_PASSWORD"], b["POSTGRES_PASSWORD"])
        # Nur Buchstaben und Ziffern — ein $ in .env hieße etwas anderes.
        self.assertTrue(a["POSTGRES_PASSWORD"].isalnum())
        self.assertEqual(_teil(a["SERVICE_ROLE_KEY"], 1)["role"], "service_role")

    def test_testmodus_nimmt_die_demo_schluessel(self):
        # Genau die, die die E2E-Tests fest eingebaut haben.
        g = i.neue_geheimnisse(True)
        self.assertEqual(g["ANON_KEY"], i.DEMO_ANON)
        self.assertEqual(_teil(g["ANON_KEY"], 1)["role"], "anon")

    def test_ein_zweiter_lauf_behaelt_die_schluessel(self):
        """⚠️ Neue Schlüssel hießen: alle Handys neu koppeln — oder ein
        Server, dessen Datenbank das neue Passwort gar nicht kennt."""
        erste = i.neue_geheimnisse(False, jetzt=1)
        env = i.env_inhalt(CONF, erste, False)
        zweite = i.geheimnisse_behalten(env, False)
        self.assertEqual(zweite, erste)

    def test_ohne_vollstaendige_alte_env_gibt_es_neue(self):
        g = i.geheimnisse_behalten('JWT_SECRET="x"\n', False)
        self.assertNotEqual(g["JWT_SECRET"], "x")
        self.assertIn("ANON_KEY", i.geheimnisse_behalten(None, False))


class Konfiguration(unittest.TestCase):
    def test_vollstaendig(self):
        self.assertEqual(i.pruefe_conf(CONF), [])

    def test_fehlt_etwas_steht_es_als_satz_da(self):
        f = i.pruefe_conf({"ERREICHBARKEIT": "tunnel", "DATA_DIR": "srv"})
        text = " ".join(f)
        for erwartet in ("DOMAIN", "TUNNEL_TOKEN", "absoluter Pfad", "KDM_EMAIL", "SMTP_HOST"):
            self.assertIn(erwartet, text)
        self.assertIn("ERREICHBARKEIT", " ".join(i.pruefe_conf({**CONF, "ERREICHBARKEIT": "ftp"})))

    def test_lan_ohne_https(self):
        self.assertEqual(i.basis_url(CONF), "https://app.musterstadt.de")
        lan = {**CONF, "ERREICHBARKEIT": "lan", "DOMAIN": "192.168.1.20:8080"}
        self.assertEqual(i.basis_url(lan), "http://192.168.1.20:8080")


class Compose(unittest.TestCase):
    def test_je_erreichbarkeit_genau_eine_zusatzdatei(self):
        for art in i.ERREICHBARKEITEN:
            self.assertEqual(
                i.compose_dateien(art, False), ["docker-compose.yml", f"compose/{art}.yml"]
            )
        self.assertEqual(i.compose_dateien("lan", True)[-1], "compose/test.yml")

    def test_env_traegt_zusammenstellung_und_adressen(self):
        env = i.lies_env(i.env_inhalt(CONF, i.neue_geheimnisse(False, 1), False))
        self.assertEqual(env["COMPOSE_FILE"], "docker-compose.yml:compose/caddy.yml")
        self.assertEqual(env["API_EXTERNAL_URL"], "https://app.musterstadt.de")
        self.assertEqual(env["SITE_URL"], env["API_EXTERNAL_URL"])
        self.assertEqual(env["NAME"], "Feuerwehr Musterstadt")

    def test_anfuehrungszeichen_brechen_ab_statt_still_falsch(self):
        with self.assertRaises(i.Abbruch):
            i.env_inhalt({**CONF, "SMTP_PASS": 'ab"c'}, i.neue_geheimnisse(False, 1), False)


class Migrationen(unittest.TestCase):
    def test_nur_offene_in_zeitlicher_reihenfolge(self):
        offen = i.offene_migrationen(
            ["20260923_c.sql", "20260713_a.sql", "20260801_b.sql"], {"20260713_a.sql"}
        )
        self.assertEqual(offen, ["20260801_b.sql", "20260923_c.sql"])

    def test_bei_aktuellem_stand_nichts(self):
        self.assertEqual(i.offene_migrationen(["a.sql"], {"a.sql"}), [])


class Ersetzen(unittest.TestCase):
    def test_das_verzeichnis_bleibt_dasselbe(self):
        """Der Bind-Mount eines laufenden Containers hängt am Verzeichnis
        selbst; ein neu angelegtes sähe er nie."""
        import os
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as tmp:
            quelle, ziel = Path(tmp, "neu"), Path(tmp, "ziel")
            (quelle / "admin-users").mkdir(parents=True)
            (quelle / "admin-users/index.ts").write_text("neu")
            (ziel / "weg").mkdir(parents=True)
            (ziel / "alt.txt").write_text("alt")
            inode = os.stat(ziel).st_ino
            i.Server._ersetze(quelle, ziel)
            self.assertEqual(os.stat(ziel).st_ino, inode)
            self.assertEqual(sorted(p.name for p in ziel.iterdir()), ["admin-users"])
            self.assertEqual((ziel / "admin-users/index.ts").read_text(), "neu")


class ReleaseBuendel(unittest.TestCase):
    """Das Server-Bündel, das release.yml an jedes Release hängt. Fehlt
    darin eine Datei, merkt es erst das nächtliche Update einer fremden
    Wehr — deshalb wird hier ein echtes gebaut und ausgepackt."""

    def test_enthaelt_alles_was_der_installer_anfasst(self):
        import tarfile
        import tempfile
        from pathlib import Path

        import fwapp_buendel as b

        with tempfile.TemporaryDirectory() as tmp:
            archiv = b.baue(i.REPO, "v9.9.9", Path(tmp))
            self.assertEqual(archiv.name, "fwapp-server-v9.9.9.tar.gz")
            with tarfile.open(archiv) as tar:
                tar.extractall(Path(tmp, "x"), filter="data")
            wurzel = Path(tmp, "x")
            self.assertEqual(i.buendel_version(wurzel), "v9.9.9")
            installer = wurzel / "tool/installer"
            for pfad in (
                "docker-compose.yml", "kong.yml", "Caddyfile", "fwapp_check.py",
                "fwapp_install.py", "fwapp_update.py", "db/roles.sql", "db/jwt.sql",
                "compose/lan.yml", "compose/caddy.yml", "compose/tunnel.yml", "compose/test.yml",
            ):
                self.assertTrue((installer / pfad).is_file(), pfad)
            for pfad in (
                "tool/vm/fwapp-web-nginx.conf", "tool/vm/fwapp_kopplung.sh",
                "tool/vm/fwapp_betreiber.sh", "supabase/functions/main/index.ts",
                "supabase/functions/admin-users/index.ts",
            ):
                self.assertTrue((wurzel / pfad).is_file(), pfad)
            self.assertEqual(
                len(list((wurzel / "supabase/migrations").glob("*.sql"))),
                len(list((i.REPO / "supabase/migrations").glob("*.sql"))),
            )
            # Nichts, was auf einem fremden Server nichts verloren hat.
            namen = [p.name for p in wurzel.rglob("*")]
            self.assertFalse([n for n in namen if n.startswith("test_")])
            self.assertNotIn("fwapp_autodeploy.sh", namen)
            self.assertNotIn("__pycache__", namen)

    def test_aus_dem_repo_heisst_der_stand_entwicklung(self):
        self.assertEqual(i.buendel_version(i.REPO), "entwicklung")


class Buendel(unittest.TestCase):
    def test_images_sind_gepinnt(self):
        """Marcus 2026-09-23: Server-Images je Release fest — kein `latest`,
        sonst zöge ein Update ungetestete Versionen."""
        import re
        from pathlib import Path

        for datei in [i.HIER / "docker-compose.yml", *sorted((i.HIER / "compose").glob("*.yml"))]:
            for image in re.findall(r"image:\s*(\S+)", datei.read_text()):
                self.assertIn(":", image, f"{datei.name}: {image} ohne Version")
                self.assertNotRegex(image, r":(latest|stable|alpine)$", f"{datei.name}: {image}")

    def test_kong_yml_uebersteht_das_eval(self):
        """Der Einstieg von Kong setzt die Schlüssel per eval und echo ein.
        Ein doppeltes Anführungszeichen darin machte aus '1.1' die Zahl 1.1
        (Kong startet nicht), ein Backtick führte Befehle aus."""
        text = (i.HIER / "kong.yml").read_text()
        for zeichen in ('"', "`", "$("):
            self.assertNotIn(zeichen, text)
        import re

        self.assertEqual(
            set(re.findall(r"\$\w+", text)), {"$SUPABASE_ANON_KEY", "$SUPABASE_SERVICE_KEY"}
        )

    def test_postgres_bleibt_bei_17(self):
        text = (i.HIER / "docker-compose.yml").read_text()
        self.assertIn("image: public.ecr.aws/supabase/postgres:17.", text)


if __name__ == "__main__":
    unittest.main()
