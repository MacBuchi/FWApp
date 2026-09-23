"""test_fwapp_sicherung.py – Die Regeln der vollständigen Sicherung ohne Docker.

Dass Sicherung und automatisches Zurückspielen wirklich funktionieren —
Datenbank, Fotos samt Inhaltstyp, Schlüssel —, beweist der Docker-Nachweis
in docs/INSTALLATION.md. Hier steht, WAS gesichert wird: Fehlt ein Volume in
der Liste, fällt das erst beim Zurückspielen auf, also dann, wenn es zu
spät ist.
"""
import unittest

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

    def test_namen_sind_dateinamen_und_eindeutig(self):
        namen = [z.name for z in s.ziele_aus_inspect(self.INSPECT)]
        self.assertEqual(len(namen), len(set(namen)))
        self.assertIn("supabase_db_var_lib_postgresql_data", namen)
        for n in namen:
            self.assertRegex(n, r"^[A-Za-z0-9_]+$")

    def test_geteiltes_volume_nur_einmal(self):
        inspect = [
            container("a", vol("v", "/x")),
            container("b", vol("v", "/y")),
        ]
        self.assertEqual(len(s.ziele_aus_inspect(inspect)), 1)


class Werkzeug(unittest.TestCase):
    def test_helfer_ist_das_edge_runtime_image_des_buendels(self):
        """GNU tar mit --xattrs — busybox-tar (fast alle anderen Images)
        verlöre den Inhaltstyp jedes Fotos."""
        text = (inst.HIER / "docker-compose.yml").read_text()
        self.assertIn("edge-runtime", s.helfer_image([text]))

    def test_ohne_helfer_keine_sicherung(self):
        with self.assertRaises(inst.Abbruch):
            s.helfer_image(["services:\n  web:\n    image: nginx:1\n"])

    def test_xattrs_sind_dabei(self):
        self.assertIn("--xattrs", s.GNU_TAR)
        self.assertIn("--xattrs-include=*", s.GNU_TAR)


class Platz(unittest.TestCase):
    def test_sicherung_plus_luft(self):
        gib = 1024**3
        self.assertTrue(s.platz_reicht(5 * gib, 3 * gib))
        self.assertFalse(s.platz_reicht(3 * gib + 1, 3 * gib))


if __name__ == "__main__":
    unittest.main()
