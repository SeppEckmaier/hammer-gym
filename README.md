# Hammer-Gym 💪

Widerstandsband-Training mit Wochenplan, Satz-Tracking und integriertem Trainings-Kalender — für Ubuntu Touch.

![Ubuntu Touch](https://img.shields.io/badge/Ubuntu%20Touch-24.04-blue) ![License](https://img.shields.io/badge/License-GPLv3-green)

## Features

- **Wochenplan** — Übungen pro Wochentag mit Sätzen, Ziel-Wiederholungen und Notizen
- **Band/Gewicht-Umschaltung** — Widerstandsbänder nach Farbe (gelb, orange, rot, schwarz, lila, grün, blau, grau) oder frei wählbares Gewicht in kg
- **Satz-Tracking** — Sätze abhaken, tatsächliche Wiederholungen und Puls notieren
- **Trainingsuhr** — Dauer der Einheit messen
- **Progressive Überlastung** — Ziel-Wiederholungen werden nach abgeschlossenem Trainingstag automatisch erhöht
- **Trainings-Kalender** — Monatsansicht mit Trainingszeit und Puls-Statistik (min/Ø/max) pro Trainingstag; nachträglich ergänzte Übungen lassen sich dem Kalendereintrag hinzufügen
- **100 % lokal** — alle Daten bleiben auf dem Gerät, kein Konto, keine Cloud

## Installation

Die App ist als Click-Paket im [OpenStore](https://open-store.io/) verfügbar.

### Manuell (Entwickler)

Voraussetzungen: [clickable](https://clickable-ut.dev/)

```bash
clickable build --skip-review --arch arm64
clickable install --arch arm64
```

## Entwicklung

Der Desktop-Quick-Build zum lokalen Testen:

```bash
./build-desktop.sh
env HAMMERGYM_QML=qml/Main.qml ./build-desktop/hammer-gym
```

## Struktur

- `src/` — Backend (C++/Qt): Trainingsplan, Fortschritt, Kalender, Stoppuhr, Persistenz (`progress.json`)
- `qml/` — Frontend (QML): Übungsliste, Satz/Fokus-Ansicht, Kalender, Formulare

## Daten

Alle Trainingsdaten liegen als JSON in `~/.local/share/hammer-gym/progress.json` (bzw. `$XDG_DATA_HOME/hammer-gym`). Kalendereinträge sind Teil derselben Datei.

## Lizenz

GNU General Public License v3.0 — siehe [LICENSE](LICENSE).