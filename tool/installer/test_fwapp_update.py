"""test_fwapp_update.py – Die Regeln des nächtlichen Updates (#241) ohne Netz.

Den ganzen Weg mit Docker beweist der Nachweis in docs/INSTALLATION.md
(Release-Stand installieren, Update auf ein neueres Bündel, dann alle
E2E-Tests). Hier steht, was dabei nicht auffiele: welches Release gewählt
wird, dass ein Archiv nicht aus seinem Ordner ausbricht, und was in der
Mail an den KreisDatenMeister steht.
"""
import io
import tarfile
import unittest

import fwapp_install as inst
import fwapp_update as u


def rel(tag, prerelease=False, draft=False, assets=True):
    namen = list(u.asset_namen(tag)) if assets else [f"fwapp-{tag}.apk"]
    return {
        "tag_name": tag,
        "prerelease": prerelease,
        "draft": draft,
        "assets": [{"name": n, "browser_download_url": f"https://x/{n}"} for n in namen],
    }


class Auswahl(unittest.TestCase):
    RELEASES = [
        rel("v1.66.0", prerelease=True),
        rel("v1.65.0"),
        rel("v1.64.0"),
        rel("v1.63.0", assets=False),
    ]

    def test_stabil_nimmt_das_neueste_freigegebene(self):
        """Marcus 2026-09-23: Standard = jedes freigegebene Release."""
        r = u.waehle_release(self.RELEASES, "stabil", "v1.64.0")
        self.assertEqual(r["tag_name"], "v1.65.0")

    def test_vorab_nimmt_auch_vorabversionen(self):
        r = u.waehle_release(self.RELEASES, "vorab", "v1.64.0")
        self.assertEqual(r["tag_name"], "v1.66.0")

    def test_aktuell_oder_neuer_heisst_nichts_tun(self):
        self.assertIsNone(u.waehle_release(self.RELEASES, "stabil", "v1.65.0"))
        # Wer von Hand auf eine Vorabversion ging, wird nicht zurückgestuft.
        self.assertIsNone(u.waehle_release(self.RELEASES, "stabil", "v1.66.0"))

    def test_aus_schaltet_ab(self):
        self.assertIsNone(u.waehle_release(self.RELEASES, "aus", "v1.0.0"))

    def test_release_ohne_buendel_kommt_nicht_in_frage(self):
        """So sieht jedes Release vor #241 aus — nur ein APK."""
        self.assertIsNone(u.waehle_release([rel("v2.0.0", assets=False)], "stabil", "v1.0.0"))

    def test_entwurf_zaehlt_nicht(self):
        self.assertIsNone(u.waehle_release([rel("v2.0.0", draft=True)], "vorab", "v1.0.0"))

    def test_zahlen_statt_text_vergleichen(self):
        # Als Text wäre 1.9 größer als 1.10.
        r = u.waehle_release([rel("v1.9.0"), rel("v1.10.0")], "stabil", "v1.8.0")
        self.assertEqual(r["tag_name"], "v1.10.0")

    def test_installation_aus_dem_repo_bekommt_das_release(self):
        r = u.waehle_release(self.RELEASES, "stabil", "entwicklung")
        self.assertEqual(r["tag_name"], "v1.65.0")


class Pruefsummen(unittest.TestCase):
    def test_format_von_sha256sum(self):
        s = u.lies_summen("ABC  fwapp-web-v1.tar.gz\ndef *fwapp-server-v1.tar.gz\n\nkaputt\n")
        self.assertEqual(s, {"fwapp-web-v1.tar.gz": "abc", "fwapp-server-v1.tar.gz": "def"})


def _tar(*eintraege):
    puffer = io.BytesIO()
    with tarfile.open(fileobj=puffer, mode="w:gz") as tar:
        for info in eintraege:
            daten = b"x" if info.isfile() else None
            if daten is not None:
                info.size = len(daten)
            tar.addfile(info, io.BytesIO(daten) if daten else None)
    puffer.seek(0)
    return tarfile.open(fileobj=puffer)


class Entpacken(unittest.TestCase):
    def test_normale_dateien_gehen_durch(self):
        tar = _tar(tarfile.TarInfo("tool/installer/fwapp_install.py"))
        self.assertEqual(len(u.sichere_mitglieder(tar)), 1)

    def test_ausbruch_wird_abgewiesen(self):
        for name in ("../etc/cron.d/x", "/etc/passwd", "a/../../b"):
            with self.subTest(name=name), self.assertRaises(inst.Abbruch):
                u.sichere_mitglieder(_tar(tarfile.TarInfo(name)))

    def test_verweise_werden_abgewiesen(self):
        link = tarfile.TarInfo("web/index.html")
        link.type = tarfile.SYMTYPE
        link.linkname = "/etc/shadow"
        with self.assertRaises(inst.Abbruch):
            u.sichere_mitglieder(_tar(link))


class Images(unittest.TestCase):
    def test_aus_allen_dateien_ohne_doppelte(self):
        a = "services:\n  db:\n    image: pg:17.6\n  web:\n    image: nginx:1\n"
        b = "services:\n  caddy:\n    image: caddy:2\n  web:\n    image: nginx:1\n"
        self.assertEqual(u.images_aus_compose([a, b]), ["pg:17.6", "nginx:1", "caddy:2"])

    def test_passt_zum_echten_buendel(self):
        text = (inst.HIER / "docker-compose.yml").read_text()
        images = u.images_aus_compose([text])
        self.assertEqual(len(images), 7)
        self.assertTrue(all(":" in i for i in images))


class Aufraeumen(unittest.TestCase):
    def test_die_neuesten_bleiben(self):
        namen = [f"2026092{i}-030000-vor-v1.{i}.0.dump" for i in range(9)]
        weg = u.aelteste(namen, 7)
        self.assertEqual(weg, namen[:2])
        self.assertEqual(u.aelteste(namen[:3], 7), [])


class Mail(unittest.TestCase):
    CONF = {
        "DATA_DIR": "/srv/fwapp", "KDM_EMAIL": "kdm@x.de", "MAIL_ABSENDER": "app@x.de",
        "NAME": "Feuerwehr X", "DOMAIN": "app.x.de",
    }

    def test_sagt_was_geschah_und_wie_es_weitergeht(self):
        m = u.fehler_mail(self.CONF, "v1.64.0", "v1.65.0", "Probelauf der Migrationen", "42P01")
        self.assertEqual(m["To"], "kdm@x.de")
        self.assertIn("v1.65.0", m["Subject"])
        text = m.get_content()
        for erwartet in ("42P01", "läuft unverändert weiter auf v1.64.0",
                         "rm /srv/fwapp/update.blocked", "/srv/fwapp/backups/"):
            self.assertIn(erwartet, text)

    def test_nach_dem_einspielen_kein_versprechen(self):
        """Ab Schritt 6 ist der Server angefasst — ob der Rückweg geklappt
        hat, steht in der Meldung, nicht als Behauptung darüber."""
        m = u.fehler_mail(self.CONF, "v1.64.0", "v1.65.0", "Einspielen", "zurückgeholt")
        self.assertNotIn("unverändert", m.get_content())


class Installer(unittest.TestCase):
    def test_timer_laeuft_nachts_und_holt_nach(self):
        from pathlib import Path

        units = inst.update_units(Path("/srv/fwapp/server"))
        timer = units["fwapp-update.timer"]
        self.assertIn("OnCalendar=*-*-* 03:00", timer)
        self.assertIn("Persistent=true", timer)
        self.assertIn(
            "/srv/fwapp/server/fwapp_update.py --conf /srv/fwapp/server/fwapp.conf",
            units["fwapp-update.service"],
        )

    def test_abgelegte_conf_liest_sich_gleich(self):
        """Der Updater liest server/fwapp.conf wieder ein — auch Werte mit
        Leerzeichen und das Passwort, das beim Installieren aus der Umgebung
        kam."""
        conf = {"NAME": "Feuerwehr Muster Stadt", "SMTP_PASS": "a=b c", "DATA_DIR": "/srv/f"}
        self.assertEqual(inst.lies_conf(inst.conf_inhalt(conf), {}), conf)


if __name__ == "__main__":
    unittest.main()
