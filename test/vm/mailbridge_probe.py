"""mailbridge_probe.py – fährt die Zustellauskunft der Mail-Brücke an.

Läuft gegen die WIRKLICH AUSGELIEFERTE Datei (tool/vm/fwapp_mailbridge.py),
nicht gegen eine Abschrift. Zwei Kunstgriffe machen das ohne VM möglich:

  * `aiosmtpd` wird durch eine Attrappe ersetzt — das Paket steckt nur im
    SMTP-Teil, den diese Probe nicht anfasst, und ist auf Entwicklerrechnern
    normalerweise nicht installiert.
  * `urllib.request.urlopen` wird ersetzt, damit KEIN echter Brevo-Aufruf
    hinausgeht. Der Ersatz merkt sich stattdessen die Ziel-URL — genau die
    ist das Prüfobjekt: Aus der Auskunft darf kein allgemeiner Weiterleiter
    werden.

Die Anfragen an die Auskunft selbst laufen über `http.client`, damit sie vom
ersetzten `urlopen` unberührt bleiben.

Ausgabe: eine Zeile JSON mit dem Ergebnis je Fall, gelesen von
test/config/mailbridge_events_test.dart.
"""

import http.client
import importlib.util
import io
import json
import sys
import threading
import types
import urllib.error
import urllib.parse
import urllib.request
from http.server import ThreadingHTTPServer

QUELLE = sys.argv[1]
SCHLUESSELDATEI = sys.argv[2]

# ── Attrappe für aiosmtpd ────────────────────────────────────────────────
_ctrl = types.ModuleType("aiosmtpd.controller")


class _Controller:
    def __init__(self, *a, **k):
        pass

    def start(self):
        pass

    def stop(self):
        pass


_ctrl.Controller = _Controller
sys.modules["aiosmtpd"] = types.ModuleType("aiosmtpd")
sys.modules["aiosmtpd.controller"] = _ctrl

spec = importlib.util.spec_from_file_location("bridge", QUELLE)
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)
bridge.KEY_FILE = SCHLUESSELDATEI

# ── Ersatz für den Netzzugriff nach draußen ──────────────────────────────
gerufen = []


class _Antwort(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def _urlopen(req, timeout=None):
    gerufen.append({
        "url": req.full_url,
        "methode": req.get_method(),
        "schluessel": req.headers.get("Api-key"),
    })
    if "%40boom." in req.full_url or "@boom." in req.full_url:
        raise urllib.error.HTTPError(req.full_url, 401, "nope", None, None)
    return _Antwort(json.dumps({"events": [{"event": "delivered"}]}).encode())


urllib.request.urlopen = _urlopen

server = ThreadingHTTPServer(("127.0.0.1", 0), bridge.AuskunftHandler)
threading.Thread(target=server.serve_forever, daemon=True).start()
PORT = server.server_address[1]


def hole(pfad):
    verbindung = http.client.HTTPConnection("127.0.0.1", PORT, timeout=10)
    try:
        verbindung.request("GET", pfad)
        antwort = verbindung.getresponse()
        return antwort.status, antwort.read().decode()
    finally:
        verbindung.close()


ergebnis = {}

status, rumpf = hole("/events?email=max%40web.de&days=5")
ergebnis["gut"] = {"status": status, "rumpf": rumpf}
ergebnis["ziel"] = gerufen[-1] if gerufen else None

for name, pfad in [
    ("fremder_pfad", "/anderes?email=max%40web.de"),
    ("ohne_adresse", "/events"),
    ("adresse_ist_url", "/events?email=https%3A%2F%2Fboese.example%2Fx"),
    ("days_kein_wert", "/events?email=max%40web.de&days=viele"),
]:
    gerufen.clear()
    status, _ = hole(pfad)
    ergebnis[name] = {"status": status, "aufrufe": len(gerufen)}

gerufen.clear()
hole("/events?email=max%40web.de&days=9999")
ergebnis["days_gedeckelt"] = gerufen[-1]["url"] if gerufen else None

gerufen.clear()
status, rumpf = hole("/events?email=max%40boom.de&days=3")
ergebnis["brevo_lehnt_ab"] = {"status": status, "rumpf": rumpf}

server.shutdown()
print(json.dumps(ergebnis))
