#!/usr/bin/env python3
"""fwapp_install.py – Einen FWApp-Server einrichten (Issue #241).

    ./fwapp_install.py --conf fwapp.conf --web <Web-Bündel>

Richtet auf einem Pi oder einer VM mit Docker den kompletten Server ein:
Vorab-Prüfung (#240) → Dateien → Schlüssel → Dienste starten → Migrationen
→ Einrichtungs-Datei (#238) → KreisDatenMeister-Konto (#101) →
Abschlussprüfung. Am Ende steht, wie es weitergeht.

**Idempotent.** Ein zweiter Lauf behält Schlüssel und Daten, spielt nur
neue Migrationen ein und ersetzt Web-App, Functions und Konfiguration. Das
ist Absicht: Derselbe Ablauf ist der Kern des Updates (#241, zweiter Teil)
— zwei Wege, einen Server in einen Stand zu bringen, liefen auseinander.

Aufteilung auf dem Rechner:
    DATA_DIR/server/   Compose-Dateien, .env (Schlüssel, chmod 600)
    DATA_DIR/db/       Postgres-Daten
    DATA_DIR/storage/  Fotos und Anhänge
    DATA_DIR/web/      Web-App
    DATA_DIR/functions/ Edge Functions
    DATA_DIR/kopplung/ /.well-known/fwapp.json

Nur Python-Standardbibliothek. Die reine Logik (Schlüssel, .env, Auswahl
der Compose-Dateien, offene Migrationen) steht in Funktionen ohne Docker
und wird von test_fwapp_install.py geprüft; alles mit Docker steht in
`Server`.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import secrets
import shutil
import string
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fwapp_check import lies_conf  # noqa: E402

HIER = Path(__file__).resolve().parent
REPO = HIER.parent.parent


def buendel_version(repo: Path) -> str:
    """Der Stand, den dieser Installer einrichtet: `VERSION` legt
    fwapp_buendel.py ins Release-Bündel. Aus dem Repo heraus gibt es keins."""
    datei = repo / "VERSION"
    return datei.read_text().strip() if datei.exists() else "entwicklung"

ERREICHBARKEITEN = ("lan", "caddy", "tunnel")

# Die Demo-Werte des lokalen Supabase-Stacks. NUR für --testmodus: Dann
# laufen die E2E-Tests (die genau diese Schlüssel fest eingebaut haben)
# unverändert gegen den vom Installer gebauten Server.
DEMO_JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
DEMO_ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6"
    "ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
)
DEMO_SERVICE = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6"
    "InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
)


class Abbruch(Exception):
    """Ein Schritt ist gescheitert; der Text sagt, was zu tun ist."""


# ── Reine Logik ───────────────────────────────────────────────────────────


def zufall(laenge: int) -> str:
    """Nur Buchstaben und Ziffern: Ein `$` oder Anführungszeichen im Passwort
    würde in .env und in Verbindungs-URLs still etwas anderes bedeuten."""
    zeichen = string.ascii_letters + string.digits
    return "".join(secrets.choice(zeichen) for _ in range(laenge))


def _b64(daten: bytes) -> str:
    return base64.urlsafe_b64encode(daten).rstrip(b"=").decode()


def jwt(geheimnis: str, rolle: str, jetzt: int, jahre: int = 10) -> str:
    """HS256-Token für anon bzw. service_role — dieselbe Form, die Supabase
    self-hosted mit utils/generate-keys.sh erzeugt."""
    kopf = _b64(json.dumps({"alg": "HS256", "typ": "JWT"}, separators=(",", ":")).encode())
    nutz = _b64(
        json.dumps(
            {"role": rolle, "iss": "supabase", "iat": jetzt, "exp": jetzt + jahre * 365 * 86400},
            separators=(",", ":"),
        ).encode()
    )
    sig = hmac.new(geheimnis.encode(), f"{kopf}.{nutz}".encode(), hashlib.sha256).digest()
    return f"{kopf}.{nutz}.{_b64(sig)}"


def neue_geheimnisse(testmodus: bool, jetzt: Optional[int] = None) -> dict[str, str]:
    if testmodus:
        return {
            "JWT_SECRET": DEMO_JWT_SECRET,
            "ANON_KEY": DEMO_ANON,
            "SERVICE_ROLE_KEY": DEMO_SERVICE,
            "POSTGRES_PASSWORD": "postgres",
        }
    geheim = zufall(48)
    jetzt = jetzt or int(time.time())
    return {
        "JWT_SECRET": geheim,
        "ANON_KEY": jwt(geheim, "anon", jetzt),
        "SERVICE_ROLE_KEY": jwt(geheim, "service_role", jetzt),
        "POSTGRES_PASSWORD": zufall(32),
    }


def pruefe_conf(conf: dict[str, str]) -> list[str]:
    """Was in fwapp.conf fehlt oder nicht passt — als Sätze."""
    fehler = []
    art = conf.get("ERREICHBARKEIT", "")
    if art not in ERREICHBARKEITEN:
        fehler.append(f"ERREICHBARKEIT muss eins von {', '.join(ERREICHBARKEITEN)} sein.")
    if not conf.get("DOMAIN"):
        fehler.append("DOMAIN fehlt (bei ERREICHBARKEIT=lan: die IP-Adresse des Rechners).")
    if art == "tunnel" and not conf.get("TUNNEL_TOKEN"):
        fehler.append("TUNNEL_TOKEN fehlt (Cloudflare-Dashboard → Tunnel → Token).")
    data = conf.get("DATA_DIR", "")
    if not data.startswith("/"):
        fehler.append("DATA_DIR muss ein absoluter Pfad sein, z. B. /srv/fwapp.")
    if "@" not in conf.get("KDM_EMAIL", ""):
        fehler.append("KDM_EMAIL fehlt — das Konto des KreisDatenMeisters.")
    for k in ("MAIL_ABSENDER", "SMTP_HOST"):
        if not conf.get(k):
            fehler.append(f"{k} fehlt — ohne Mail keine Einladungen.")
    return fehler


def basis_url(conf: dict[str, str]) -> str:
    """Web-App und API liegen unter derselben Adresse (nginx leitet
    /auth, /rest, /storage, /functions an Kong weiter)."""
    schema = "http" if conf.get("ERREICHBARKEIT") == "lan" else "https"
    return f"{schema}://{conf['DOMAIN']}"


def compose_dateien(art: str, testmodus: bool) -> list[str]:
    dateien = ["docker-compose.yml", f"compose/{art}.yml"]
    if testmodus:
        dateien.append("compose/test.yml")
    return dateien


def env_inhalt(conf: dict[str, str], geheim: dict[str, str], testmodus: bool) -> str:
    """Die .env für docker compose. COMPOSE_FILE steht mit drin — so startet
    ein späteres `docker compose up -d` im selben Verzeichnis dieselbe
    Zusammenstellung, ohne dass sich jemand die Profile merken muss."""
    url = basis_url(conf)
    werte = {
        "COMPOSE_FILE": ":".join(compose_dateien(conf["ERREICHBARKEIT"], testmodus)),
        "DATA_DIR": conf["DATA_DIR"],
        "DOMAIN": conf["DOMAIN"],
        "NAME": conf.get("NAME", "FWApp"),
        "API_EXTERNAL_URL": url,
        "SITE_URL": url,
        "LAN_PORT": conf.get("LAN_PORT", "80"),
        "TUNNEL_TOKEN": conf.get("TUNNEL_TOKEN", ""),
        "MAIL_ABSENDER": conf.get("MAIL_ABSENDER", ""),
        "SMTP_HOST": conf.get("SMTP_HOST", ""),
        "SMTP_PORT": conf.get("SMTP_PORT", "587"),
        "SMTP_USER": conf.get("SMTP_USER", ""),
        "SMTP_PASS": conf.get("SMTP_PASS", ""),
        **geheim,
    }
    zeilen = ["# .env – vom Installer erzeugt (#241). Enthält Schlüssel: chmod 600."]
    for k, v in werte.items():
        if "\n" in v or '"' in v:
            raise Abbruch(f"{k} enthält ein Zeichen, das in .env nicht geht.")
        zeilen.append(f'{k}="{v}"')
    return "\n".join(zeilen) + "\n"


def lies_env(text: str) -> dict[str, str]:
    werte = {}
    for zeile in text.splitlines():
        if "=" in zeile and not zeile.lstrip().startswith("#"):
            k, v = zeile.split("=", 1)
            werte[k.strip()] = v.strip().strip('"')
    return werte


GEHEIM_SCHLUESSEL = ("JWT_SECRET", "ANON_KEY", "SERVICE_ROLE_KEY", "POSTGRES_PASSWORD")


def geheimnisse_behalten(alte_env: Optional[str], testmodus: bool) -> dict[str, str]:
    """⚠️ Ein zweiter Lauf darf die Schlüssel NIE neu erzeugen: Das
    Postgres-Passwort steckt in der Datenbank, der Anon-Key in jeder App und
    im Einrichtungs-QR. Neue Werte hießen, alle Handys neu zu koppeln — oder
    ein Server, der gar nicht mehr hochkommt."""
    if alte_env:
        alt = lies_env(alte_env)
        if all(alt.get(k) for k in GEHEIM_SCHLUESSEL):
            return {k: alt[k] for k in GEHEIM_SCHLUESSEL}
    return neue_geheimnisse(testmodus)


def conf_inhalt(conf: dict[str, str]) -> str:
    """Die wirksame Konfiguration für server/fwapp.conf — dort liest der
    nächtliche Updater sie wieder. Wirksam heißt: samt der Werte, die beim
    Installieren aus Umgebungsvariablen kamen (SMTP_PASS), sonst verlöre das
    erste Update die Mail."""
    zeilen = ["# fwapp.conf – vom Installer abgelegt (#241); enthält Passwörter: chmod 600."]
    for k, v in conf.items():
        if "\n" in v:
            raise Abbruch(f"{k} enthält einen Zeilenumbruch.")
        zeilen.append(f"{k}={v}")
    return "\n".join(zeilen) + "\n"


def update_units(server: Path) -> dict[str, str]:
    """systemd-Einheiten für das nächtliche Update (Marcus, 2026-09-23:
    automatisch nachts). Persistent: Ein Pi, der um 3 Uhr aus war, holt den
    Lauf nach dem Einschalten nach."""
    return {
        "fwapp-update.service": (
            "[Unit]\n"
            "Description=FWApp: auf das nächste Release aktualisieren (#241)\n"
            "After=network-online.target docker.service\n"
            "Wants=network-online.target\n\n"
            "[Service]\n"
            "Type=oneshot\n"
            f"ExecStart=/usr/bin/env python3 {server}/fwapp_update.py --conf {server}/fwapp.conf\n"
        ),
        "fwapp-update.timer": (
            "[Unit]\n"
            "Description=FWApp: nächtliches Update\n\n"
            "[Timer]\n"
            "OnCalendar=*-*-* 03:00\n"
            "RandomizedDelaySec=45min\n"
            "Persistent=true\n\n"
            "[Install]\n"
            "WantedBy=timers.target\n"
        ),
    }


def offene_migrationen(dateien: list[str], angewandt: set[str]) -> list[str]:
    """In Namensreihenfolge (Zeitstempel vorn), ohne die schon angewandten —
    dieselbe Buchführung wie der Autodeploy (deploy.applied_migrations)."""
    return [d for d in sorted(dateien) if d not in angewandt]


def sha256_datei(pfad: Path) -> str:
    return hashlib.sha256(pfad.read_bytes()).hexdigest()


# ── Alles mit Docker ──────────────────────────────────────────────────────


class Server:
    def __init__(self, conf: dict[str, str], testmodus: bool):
        self.conf = conf
        self.testmodus = testmodus
        self.data = Path(conf["DATA_DIR"])
        self.server = self.data / "server"
        self.docker = os.environ.get("DOCKER", "docker").split()

    def lauf(self, *befehl: str, eingabe: Optional[str] = None, pruefen: bool = True) -> str:
        r = subprocess.run(
            [*befehl], input=eingabe, capture_output=True, text=True, cwd=self.server
        )
        if pruefen and r.returncode != 0:
            raise Abbruch(f"{' '.join(befehl[:4])} …: {r.stderr.strip() or r.stdout.strip()}")
        return r.stdout

    def versuch(self, *befehl: str) -> tuple[int, str]:
        """Wie lauf, aber ohne Abbruch: Rückgabecode und alle Ausgaben."""
        r = subprocess.run([*befehl], capture_output=True, text=True, cwd=self.server)
        return r.returncode, r.stdout + r.stderr

    def psql(self, sql: str) -> str:
        return self.lauf(
            *self.docker, "exec", "-i", "supabase-db",
            "psql", "-U", "supabase_admin", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-Atq",
            eingabe=sql,
        )

    # Schritt 1: Dateien
    def dateien(self, web: Path) -> None:
        for sub in ("server", "db", "storage", "web", "functions", "kopplung", "backups"):
            (self.data / sub).mkdir(parents=True, exist_ok=True)
        # fwapp_install.py und fwapp_update.py liegen mit im Server-Ordner:
        # Dort startet der Timer den Updater, und der braucht beide.
        for name in (
            "docker-compose.yml", "kong.yml", "Caddyfile",
            "fwapp_check.py", "fwapp_install.py", "fwapp_update.py", "fwapp_sicherung.py",
        ):
            shutil.copy2(HIER / name, self.server / name)
        for sub in ("compose", "db"):
            shutil.copytree(HIER / sub, self.server / sub, dirs_exist_ok=True)
        # Dieselbe nginx-Konfiguration wie auf unserer VM — keine Kopie mit
        # Abweichungen (Cache-Regeln, Kopplungs-Datei, API-Weiterleitung).
        shutil.copy2(REPO / "tool/vm/fwapp-web-nginx.conf", self.server / "nginx.conf")
        if not (web / "index.html").exists():
            raise Abbruch(f"{web} ist kein Web-Bündel (index.html fehlt).")
        self._ersetze(web, self.data / "web")
        self._ersetze(REPO / "supabase/functions", self.data / "functions")

    @staticmethod
    def _ersetze(quelle: Path, ziel: Path) -> None:
        """Ersetzt den INHALT, nie das Verzeichnis selbst: Ein laufender
        Container hängt per Bind-Mount am Verzeichnis. Neu angelegt, sähe er
        weiter das alte, gelöschte — beim ersten Update waren Web-App und
        Functions darin leer (`function "admin-users" not available`)."""
        ziel.mkdir(parents=True, exist_ok=True)
        for alt in ziel.iterdir():
            if alt.is_dir() and not alt.is_symlink():
                shutil.rmtree(alt)
            else:
                alt.unlink()
        shutil.copytree(quelle, ziel, dirs_exist_ok=True)

    def conf_ablegen(self) -> None:
        pfad = self.server / "fwapp.conf"
        pfad.write_text(conf_inhalt(self.conf))
        pfad.chmod(0o600)

    def installation_merken(self, version: str) -> None:
        """Erst ganz am Ende eines erfolgreichen Laufs: Der Updater hält den
        hier eingetragenen Stand für eingerichtet."""
        (self.server / "installation.json").write_text(
            json.dumps(
                {"version": version, "testmodus": self.testmodus,
                 "eingerichtet": time.strftime("%Y-%m-%dT%H:%M:%S%z")},
                indent=2,
            ) + "\n"
        )

    # Schritt 2: Schlüssel
    def env(self) -> dict[str, str]:
        pfad = self.server / ".env"
        alt = pfad.read_text() if pfad.exists() else None
        geheim = geheimnisse_behalten(alt, self.testmodus)
        pfad.write_text(env_inhalt(self.conf, geheim, self.testmodus))
        pfad.chmod(0o600)
        return geheim

    # Schritt 3: Dienste
    def starten(self) -> None:
        self.lauf(*self.docker, "compose", "up", "-d", "--remove-orphans")
        # up startet einen unveränderten Container nicht neu — die Edge
        # Runtime hielte dann den Code des alten Stands.
        self.lauf(*self.docker, "compose", "restart", "functions")
        for dienst in ("supabase-db", "supabase-auth", "supabase-storage"):
            self._warte_gesund(dienst)

    def _warte_gesund(self, container: str, sekunden: int = 180) -> None:
        ende = time.time() + sekunden
        while time.time() < ende:
            zustand = self.lauf(
                *self.docker, "inspect", "-f", "{{.State.Health.Status}}", container, pruefen=False
            ).strip()
            if zustand == "healthy":
                return
            time.sleep(3)
        raise Abbruch(f"{container} wird nicht bereit — `docker logs {container}` ansehen.")

    # Schritt 4: Migrationen
    def migrationen(self, ordner: Optional[Path] = None) -> int:
        self.psql(
            "create schema if not exists deploy;"
            "create table if not exists deploy.applied_migrations ("
            " name text primary key, sha256 text not null,"
            " applied_at timestamptz not null default now(),"
            " source text not null default 'auto' check (source in ('seed','auto','manual')));"
        )
        angewandt = set(self.psql("select name from deploy.applied_migrations;").split())
        ordner = ordner or REPO / "supabase/migrations"
        offen = offene_migrationen([p.name for p in ordner.glob("*.sql")], angewandt)
        for name in offen:
            pfad = ordner / name
            try:
                self.psql(pfad.read_text())
            except Abbruch as e:
                raise Abbruch(f"Migration {name} gescheitert: {e}") from e
            self.psql(
                "insert into deploy.applied_migrations (name, sha256, source) "
                f"values ('{name}', '{sha256_datei(pfad)}', 'auto');"
            )
        if offen:
            self.psql("notify pgrst, 'reload schema';")
        return len(offen)

    # Schritt 5: Einrichtungs-Datei
    def kopplung(self) -> None:
        """Dasselbe Skript wie auf unserer VM, nur mit den Pfaden dieser
        Installation — der Anon-Key kommt aus der eben geschriebenen .env."""
        env = dict(os.environ)
        env.update(
            ENV_DATEI=str(self.server / ".env"),
            ZIEL=str(self.data / "kopplung/fwapp.json"),
        )
        r = subprocess.run(
            ["bash", str(REPO / "tool/vm/fwapp_kopplung.sh"), basis_url(self.conf), self.conf.get("NAME", "")],
            env=env, capture_output=True, text=True,
        )
        if r.returncode != 0:
            raise Abbruch(f"Einrichtungs-Datei: {r.stderr.strip() or r.stdout.strip()}")

    # Schritt 6: KreisDatenMeister
    def kreisdatenmeister(self, geheim: dict[str, str]) -> Optional[str]:
        """Legt das Konto an, falls es noch keins gibt, und gibt das
        Startpasswort zurück (sonst None). Beim ersten Anmelden muss es
        geändert werden (profiles.must_change_password)."""
        mail = self.conf["KDM_EMAIL"].strip().lower()
        vorhanden = self.psql(
            "select 1 from public.betreiber b join auth.users u on u.id = b.user_id "
            f"where lower(u.email) = '{mail}';"
        ).strip()
        if vorhanden:
            return None
        passwort = zufall(14)
        daten = json.dumps({"email": mail, "password": passwort, "email_confirm": True})
        self.lauf(
            *self.docker, "exec", "fwapp-web", "wget", "-qO-",
            "--header", f"apikey: {geheim['SERVICE_ROLE_KEY']}",
            "--header", f"Authorization: Bearer {geheim['SERVICE_ROLE_KEY']}",
            "--header", "Content-Type: application/json",
            "--post-data", daten,
            "http://supabase-kong:8000/auth/v1/admin/users",
        )
        self.psql(
            "update public.profiles set must_change_password = true "
            f"where id = (select id from auth.users where lower(email) = '{mail}');"
        )
        env = dict(os.environ, DOCKER=" ".join(self.docker), DB_CONTAINER="supabase-db")
        # Im Testmodus ohne Kontaktzeile: Der E2E-Test zur Konsole setzt seine
        # eigene und erwartet genau die (installation_kontakt nimmt die erste).
        kontakt = "" if self.testmodus else self.conf.get("KDM_KONTAKT", "")
        r = subprocess.run(
            ["bash", str(REPO / "tool/vm/fwapp_betreiber.sh"), "setzen", mail, kontakt],
            env=env, capture_output=True, text=True,
        )
        if r.returncode != 0:
            raise Abbruch(f"KreisDatenMeister setzen: {r.stderr.strip()}")
        return passwort


    # Schritt 7: nächtliches Update
    def update_timer(self) -> str:
        """Richtet den Timer ein, wo das geht, und sagt sonst, wie."""
        if self.testmodus:
            return "Testmodus — kein Timer."
        if not Path("/run/systemd/system").exists():
            return "Kein systemd — Updates von Hand: fwapp_update.py (siehe INSTALLATION.md)."
        if os.geteuid() != 0:
            return "Timer braucht root — den Installer mit sudo wiederholen."
        for name, inhalt in update_units(self.server).items():
            Path("/etc/systemd/system", name).write_text(inhalt)
        self.lauf("systemctl", "daemon-reload")
        self.lauf("systemctl", "enable", "--now", "fwapp-update.timer")
        return "Timer aktiv: jede Nacht gegen 3 Uhr."


# ── Ablauf ────────────────────────────────────────────────────────────────


def schritt(text: str) -> None:
    print(f"\n▶ {text}", flush=True)


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description="FWApp-Server einrichten (#241)")
    p.add_argument("--conf", default="fwapp.conf")
    p.add_argument("--web", required=True, help="Verzeichnis des Web-Bündels (flutter build web)")
    p.add_argument("--ohne-pruefung", action="store_true", help="Vorab-Prüfung überspringen")
    p.add_argument(
        "--testmodus", action="store_true",
        help="NUR Entwicklung: Demo-Schlüssel und Ports des lokalen Stacks, Mailpit",
    )
    a = p.parse_args(argv)

    try:
        conf = lies_conf(Path(a.conf).read_text(encoding="utf-8"), dict(os.environ))
    except OSError:
        print(f"❌ {a.conf} nicht gefunden (Vorlage: fwapp.conf.example).")
        return 1
    if a.testmodus:
        conf.update(ERREICHBARKEIT="lan", SMTP_HOST="fwapp-mailpit", SMTP_PORT="1025",
                    SMTP_USER="", SMTP_PASS="")
    probleme = pruefe_conf(conf)
    if probleme:
        print("❌ fwapp.conf ist nicht vollständig:")
        for x in probleme:
            print(f"   → {x}")
        return 1

    server = Server(conf, a.testmodus)
    try:
        if not a.ohne_pruefung:
            schritt("Vorab-Prüfung")
            if subprocess.run([sys.executable, str(HIER / "fwapp_check.py"), "--conf", a.conf, "--vorher"]).returncode:
                raise Abbruch("Die Vorab-Prüfung blockiert — erst die ❌-Punkte beheben.")
        schritt(f"Dateien ({buendel_version(REPO)})")
        server.dateien(Path(a.web).resolve())
        server.conf_ablegen()
        schritt("Schlüssel")
        geheim = server.env()
        schritt("Dienste starten (beim ersten Mal werden die Images geladen)")
        server.starten()
        schritt("Datenbank einrichten")
        print(f"   {server.migrationen()} Migration(en) eingespielt")
        schritt("Einrichtungs-Datei für die App")
        server.kopplung()
        schritt("KreisDatenMeister")
        passwort = server.kreisdatenmeister(geheim)
        schritt("Nächtliches Update")
        print(f"   {server.update_timer()}")
        server.installation_merken(buendel_version(REPO))
    except Abbruch as e:
        print(f"\n❌ {e}")
        return 1

    url = basis_url(conf)
    print("\n✅ Der Server läuft.\n")
    print(f"   Web-App:            {url}")
    if passwort:
        print(f"   KreisDatenMeister:  {conf['KDM_EMAIL']}")
        print(f"   Startpasswort:      {passwort}   ← jetzt notieren, es erscheint nicht wieder")
    print(
        "\n   Weiter: In der Web-App anmelden (das Passwort wird dabei geändert),\n"
        "   Einstellungen → KreisDatenMeister → „Wehr anlegen\". Der erste\n"
        "   Feuerwehrkommandant bekommt eine Einladung per Mail. Handys verbinden\n"
        "   sich über Einstellungen → „Weiteres Gerät verbinden\".\n"
        f"   Prüfen, jederzeit: python3 {server.server}/fwapp_check.py --conf {Path(a.conf).resolve()}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
