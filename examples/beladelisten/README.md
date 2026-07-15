# Beispiel-Beladelisten

Fiktive, aber plausible Beladelisten zum Ausprobieren des Import-Wizards
(**Mehr → Import** in der App). Alle Gerätenamen entsprechen dem
mitgelieferten Normgeräte-Katalog, sodass der Abgleich nahezu vollständig
automatisch klappt.

| Datei | Format | Inhalt |
| --- | --- | --- |
| `HLF20-Beispiel.csv` | `Gegenstand;Stückzahl;Lagerort` (ein Fahrzeug pro Datei) | 108 Positionen in 9 Fächern — identisch mit dem in der App vorinstallierten Demo-HLF 20 |
| `LF10-Beispiel.csv` | `Gegenstand;Stückzahl;Lagerort` | 40 Positionen in 6 Fächern |
| `MTW-Beispiel.csv` | `Fahrzeug;Fach;Gerät;Anzahl` (mit Fahrzeug-Spalte) | Minimalbeladung, 10 Positionen |

Eigene Listen funktionieren genauso: Excel oder CSV mit Spalten für
Gerät/Gegenstand, Fach/Lagerort, Stückzahl/Menge und optional Fahrzeug —
die Spaltenzuordnung erkennt der Wizard automatisch und lässt sich im
ersten Schritt korrigieren. Nicht erkannte Gerätenamen können beim Abgleich
manuell zugeordnet werden; die App merkt sich die Schreibweise für das
nächste Mal.
