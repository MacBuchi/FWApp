/// zustellung.dart – Ist die Einladung überhaupt angekommen? (Issue #121)
///
/// Der Anlass aus dem Feld: Zwei Einladungen, eine kam an, die andere wurde
/// von Brevo mit `softBounces` („Internal Error: DKIM Bad request")
/// verworfen. In der App sahen **beide gleich aus** — „wartet auf
/// Bestätigung". Der Kommandant wartet damit auf etwas, das nie kommt, und
/// der Eingeladene weiß nicht einmal, dass er eingeladen wurde.
///
/// Die Einordnung steht hier und nicht in der Edge Function, obwohl die
/// Daten von dort kommen: Sie ist die einzige Stelle mit einem Urteil, und
/// ein Urteil gehört dorthin, wo es sich prüfen lässt. Die Function macht
/// nur das Mechanische — Adressen aus `einladungen` lesen, Brevo fragen,
/// Unbrauchbares wegwerfen.
library;

/// Was Brevo über eine verschickte Mail meldet, auf das Nötige gekürzt.
///
/// ⚠️ `opened` und `clicks` kommen hier bewusst NICHT an. Gemessen: acht
/// Sekunden nach dem Versand meldete Brevo `opened`, während der Empfänger
/// nachweislich nicht las — das war der Scanner des Postfachs. „Gelesen"
/// wäre also gelogen, und schlimmer: Es sähe aus, als hätte jemand die
/// Einladung gesehen und liegen lassen. (Derselbe Scanner ist der Grund,
/// warum die Einladungsmail einen Code trägt und keinen Link.)
class Zustellereignis {
  /// Brevos Schlüssel, unverändert: `delivered`, `softBounces`, …
  final String art;
  final DateTime zeit;

  /// Brevos Klartext-Begründung, falls vorhanden. Bleibt englisch und
  /// technisch — sie ist der Beweis, den man dem Anbieter vorhalten kann;
  /// übersetzt wäre sie nur noch eine Meinung.
  final String? grund;

  const Zustellereignis({required this.art, required this.zeit, this.grund});
}

enum Zustellzustand {
  /// Kein Ereignis in unserem Zeitfenster — der Server weiß es schlicht
  /// nicht. Ausdrücklich NICHT dasselbe wie „alles in Ordnung".
  unbekannt,

  /// Angenommen und unterwegs, aber noch nicht zugestellt.
  unterwegs,

  /// Beim Postfach des Empfängers angekommen.
  zugestellt,

  /// Verworfen. Hier wartet niemand mehr — hier muss jemand handeln.
  gescheitert,
}

/// Ereignisarten, die ein Scheitern bedeuten.
///
/// `softBounces` steht bewusst dabei, obwohl es „vorübergehend" heißt: Wenn
/// ein späterer Versuch durchkommt, meldet Brevo dafür ein eigenes
/// `delivered` — und das gewinnt unten. Bleibt der Soft Bounce das letzte
/// Wort, ist die Mail genauso weg wie bei einem harten. Genau dieser Fall
/// ist im Feld aufgetreten.
const kZustellFehlerArten = <String>{
  'softBounces',
  'hardBounces',
  'blocked',
  'invalid',
  'spam',
  'error',
};

/// Deutsche Kurzform je Art — für den Fall, dass Brevo keinen Grund
/// mitschickt.
const kZustellArtText = <String, String>{
  'softBounces': 'vorübergehend abgelehnt',
  'hardBounces': 'Adresse existiert nicht',
  'blocked': 'vom Anbieter blockiert',
  'invalid': 'Adresse ungültig',
  'spam': 'als Spam gemeldet',
  'error': 'Fehler beim Versand',
};

class Zustellung {
  final Zustellzustand zustand;

  /// Nur bei [Zustellzustand.gescheitert] gesetzt.
  final String? grund;

  /// Zeitpunkt des Ereignisses, das den Zustand bestimmt hat.
  final DateTime? zeit;

  const Zustellung(this.zustand, {this.grund, this.zeit});

  static const unbekannt = Zustellung(Zustellzustand.unbekannt);
}

/// Ordnet die Ereignisse einer Einladung ein.
///
/// Die Regel ist **das jüngste Wort zählt**, und zwar nur zwischen
/// „zugestellt" und „gescheitert":
///
/// - Ein Soft Bounce, dem ein erfolgreicher Wiederholungsversuch folgt,
///   ist kein Ausfall — das spätere `delivered` gewinnt.
/// - Ein erneuter Versand („Erneut senden"), der diesmal scheitert, ist
///   sehr wohl einer — das spätere Scheitern gewinnt gegen das alte
///   `delivered`. Eine Regel „einmal zugestellt, immer zugestellt" würde
///   genau den Fall verschweigen, für den es den Knopf gibt.
/// - Bei exakt gleicher Zeit gewinnt das Scheitern. Warnen und danebenliegen
///   kostet einen Blick; nicht warnen kostet die Einladung.
Zustellung zustellungAus(List<Zustellereignis> ereignisse) {
  Zustellereignis? bestesGut;
  Zustellereignis? bestesSchlecht;
  var gabEsUeberhaupt = false;

  for (final e in ereignisse) {
    gabEsUeberhaupt = true;
    if (e.art == 'delivered') {
      if (bestesGut == null || e.zeit.isAfter(bestesGut.zeit)) bestesGut = e;
    } else if (kZustellFehlerArten.contains(e.art)) {
      if (bestesSchlecht == null || e.zeit.isAfter(bestesSchlecht.zeit)) {
        bestesSchlecht = e;
      }
    }
  }

  if (bestesSchlecht != null &&
      (bestesGut == null || !bestesGut.zeit.isAfter(bestesSchlecht.zeit))) {
    return Zustellung(
      Zustellzustand.gescheitert,
      grund: _grundText(bestesSchlecht),
      zeit: bestesSchlecht.zeit,
    );
  }
  if (bestesGut != null) {
    return Zustellung(Zustellzustand.zugestellt, zeit: bestesGut.zeit);
  }
  // `requests` und `deferred`: angenommen bzw. der Anbieter lässt warten.
  // Beides ist kein Ergebnis, aber auch kein Grund zur Sorge.
  return gabEsUeberhaupt
      ? const Zustellung(Zustellzustand.unterwegs)
      : Zustellung.unbekannt;
}

String _grundText(Zustellereignis e) {
  final art = kZustellArtText[e.art] ?? e.art;
  final grund = e.grund?.trim();
  return grund == null || grund.isEmpty ? art : '$art ($grund)';
}

/// Die Zeile unter der Adresse in der Einladungsliste — ohne Zeitangabe,
/// die hängt der Bildschirm mit seinem eigenen Format an.
String zustellungText(Zustellung z) => switch (z.zustand) {
      Zustellzustand.gescheitert => 'unzustellbar: ${z.grund}',
      Zustellzustand.zugestellt => 'zugestellt',
      Zustellzustand.unterwegs => 'unterwegs',
      Zustellzustand.unbekannt => 'Zustellung nicht prüfbar',
    };
