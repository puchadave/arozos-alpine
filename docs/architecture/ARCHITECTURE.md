# webOwie_nodeOS Architektur- und Funktionsanalyse

**Repository:** `puchadave/arozos-alpine`  
**Dokument:** `docs/architecture/ARCHITECTURE.md`  
**Status:** Architekturentscheidung / Integrationsgrundlage  
**Zielsystem:** Proxmox VE, Alpine Linux LXC, OpenRC, ArozOS als Upstream-Engine  
**Produktname:** `webOwie_nodeOS`

---

## 1. TARGET

`webOwie_nodeOS` wird als Alpine-native, ressourcenschonende Node-Oberfläche in unseren Stack übernommen, weil es vorhandene ArozOS-Funktionalität nutzt, statt eine komplette Web-Desktop-, Datei-, Benutzer-, Modul- und Verwaltungsumgebung selbst nachzucoden.

Das Ziel ist nicht, ArozOS zu ersetzen. Das Ziel ist, ArozOS kontrolliert, schlank, LXC-sicher und webOwie-konform als Basis für NodeOS zu verwenden.

**Kernentscheidung:**

> Wir bauen nicht alles nach. Wir kapseln, härten, branden, paketieren und erweitern gezielt.

Alles andere wäre klassische Entwickler-Selbstüberschätzung mit Commit-Historie. Also genau die Sorte Wahnsinn, die später als „technische Schuld“ wiederkommt und sich für Architektur hält.

---

## 2. Ausgangslage

Das Repository liefert bereits eine produktionsnahe Alpine-native Verpackung:

- ArozOS-Upstream wird im Buildprozess geholt.
- Der Code wird für Alpine gebaut.
- webOwie-Branding wird angewendet.
- Ein runtime-only APK wird erzeugt.
- Das APK wird in einem frischen Alpine-Container getestet.
- OpenRC-Service wird gestartet.
- HTTP-Smoke-Test gegen Port `8080` validiert die Laufzeit.
- Release-Asset heißt stabil `webowie-nodeos-x86_64.apk`.

Der Runtime-Pfad ist in der aktuellen Architektur nicht irgendein Docker-Volume-Friedhof, sondern klar definiert:

```text
/var/lib/webowie-nodeos
/usr/bin/webowie-nodeos
/etc/init.d/webowie-nodeos
/etc/conf.d/webowie-nodeos
```

Die Service-Konfiguration setzt bewusst restriktive LXC-kompatible Optionen:

```text
-host=0.0.0.0
-port=8080
-hostname=webOwie-nodeOS
-allow_pkg_install=false
-enable_hwman=false
-enable_pwman=false
-enable_docker=false
-allow_upnp=false
-arozcast_turn=false
-max_upload_size=1024
-buffpool_size=256
-upload_buf=25
-root=/var/lib/webowie-nodeos/files
-tmp=/var/lib/webowie-nodeos/tmp
```

Diese Werte sind kein Zufall, sondern die wichtigste Grenze zwischen „läuft stabil im LXC“ und „versucht heimlich, Host-Betriebssystem zu spielen“. Letzteres ist genau die Art Design, die auf Proxmox-Clustern für nächtliche Wutausbrüche sorgt.

---

## 3. ANALYSIS

### 3.1 Was webOwie_nodeOS funktional liefert

`webOwie_nodeOS` liefert eine browserbasierte Node-Oberfläche mit folgenden Funktionsgruppen:

| Bereich | Funktion | Mehrwert für unseren Stack |
|---|---|---|
| Web-Desktop | Browserbasierte Oberfläche | Einheitlicher Zugriff auf Nodes ohne lokalen Desktop |
| Dateioberfläche | Dateiansicht, Upload, Download, Verwaltung | Ersetzt einfache Filebrowser-Container |
| User-Kontext | Benutzer- und Arbeitsbereichslogik | Grundlage für NodeOS-Sitzungen |
| Storage-Einstieg | Lokale und gemountete Speicherpfade | Bind-Mounts aus Proxmox werden über UI nutzbar |
| Service-Kapselung | OpenRC-Dienst | Kein systemd, kein Docker-Daemon nötig |
| Branding-Layer | webOwie-Identität | Produktisierbar ohne Upstream zu forken |
| APK-Paketierung | Installierbares Alpine-Paket | Reproduzierbare Installation, Update-Pfad, CI-fähig |
| Live-ISO-Bezug | Recovery/Installationspfad | Passt zum Netboot-/PXE-Rettungskonzept |

### 3.2 Was bewusst deaktiviert wird

Die Runtime deaktiviert mehrere ArozOS-Funktionsbereiche bewusst:

| Option | Wert | Grund |
|---|---:|---|
| `allow_pkg_install` | `false` | Kein Paketmanagement aus der Web-App heraus |
| `enable_hwman` | `false` | Kein Hardwaremanagement aus unprivilegiertem LXC |
| `enable_pwman` | `false` | Kein Power-Management des Hosts aus Container heraus |
| `enable_docker` | `false` | Kein Docker-in-LXC, keine Container-Orchestrierung im Container |
| `allow_upnp` | `false` | Keine automatischen Portfreigaben |
| `arozcast_turn` | `false` | Kein TURN-Dienst als Nebenlast |
| `max_upload_size` | `1024` | Kontrollierter Upload-Rahmen |
| `buffpool_size` | `256` | Begrenzter Speicherpuffer |
| `upload_buf` | `25` | Kleine LXC-taugliche Upload-Pufferung |

**Bewertung:**

Diese Deaktivierungen sind korrekt. Sie reduzieren Angriffsfläche, Speicherverbrauch und Host-Kopplung. Gleichzeitig bleibt die eigentliche Stärke erhalten: Weboberfläche, Dateizugriff, Node-Bedienung, User-Erfahrung.

Die Architektur folgt damit einer sauberen Trennung:

```text
Proxmox Host  → Block/Netzwerk/Storage/Cluster
LXC Alpine    → Runtime, UI, User-Space-Funktion
ArozOS Engine → Web Desktop, Datei- und App-Schicht
webOwie Layer → Branding, Defaults, Integration, Produktlogik
```

Genau so muss das. Der Container soll keine kleine Diktatur über den Host errichten.

---

## 4. Warum wir NICHT alles nachcodieren sollen

### 4.1 Nachcodieren erzeugt keinen Mehrwert, sondern Wartungsschulden

Ein eigener Web-Desktop klingt reizvoll. In der Realität bedeutet er:

- Filemanager nachbauen
- Upload/Download nachbauen
- Benutzerlogik nachbauen
- Sessionmodell nachbauen
- WebSocket-/Eventsystem nachbauen
- Rechteverwaltung nachbauen
- Mobile UI nachbauen
- Fehlerzustände nachbauen
- Security-Patches selbst tragen
- Packaging selbst pflegen
- Updates selbst testen

Das ist kein Architekturvorteil. Das ist ein selbstgebautes Hamsterrad mit Logo.

### 4.2 ArozOS existiert bereits als funktionaler Upstream

ArozOS liefert bereits einen großen Teil der benötigten Basis:

- webbasierte Desktop-Metapher
- Dateizugriff
- modulare Weboberfläche
- Nutzererfahrung für Browsergeräte
- plattformübergreifende Go-Basis
- vorhandene Runtime-Struktur

Unsere Wertschöpfung liegt nicht darin, diese Basis stumpf zu kopieren.

Unsere Wertschöpfung liegt in:

1. Alpine-Native-Deployment
2. Proxmox-LXC-Integration
3. NodeOS-Branding
4. harte LXC-sichere Defaults
5. Storage-Fabric-Anbindung
6. Cluster-/PXE-/Recovery-Integration
7. Provider-unabhängige Erweiterungsschicht
8. kontrollierter Betrieb auf schwacher Hardware

Das ist der Mehrwert. Nicht der hundertste Filemanager, weil ein Entwickler nachts dachte: „Das baue ich mal schnell selbst.“ Nein, Kevin, baust du nicht.

### 4.3 Der richtige Code-Anteil

Wir codieren nur dort selbst, wo echter Differenzierungswert entsteht:

| Bereich | Nachcodieren? | Begründung |
|---|---:|---|
| Basis-Webdesktop | Nein | Upstream nutzen |
| Datei-UI | Nein | Upstream nutzen |
| Login-/Session-Basis | Nein, nur härten | Bestehende Mechanik erweitern |
| Alpine APK | Ja | Unser Deployment-Wert |
| OpenRC Integration | Ja | Alpine-/LXC-spezifisch |
| Proxmox Templates | Ja | Infrastrukturwert |
| NodeOS Branding | Ja | Produktwert |
| Storage Fabric Connector | Ja | Strategischer Kernwert |
| Google Drive / OneDrive / S3 Provider | Ja, als Plugins | Anbieterunabhängigkeit |
| PXE/Netboot Integration | Ja | Recovery- und Cluster-Wert |
| Host-Hardwareverwaltung aus UI | Nein | Risiko im LXC |
| Docker-Steuerung aus UI | Nein | falsche Schicht |

---

## 5. Mehrwertanalyse

### 5.1 Technischer Mehrwert

`webOwie_nodeOS` wird zur einheitlichen Node-Oberfläche:

```text
Browser → webOwie_nodeOS → ArozOS Engine → gemounteter Storage / Node-Funktionen
```

Damit kann ein Benutzer denselben Arbeitsplatz aufrufen von:

- Thin Client
- Smart TV mit Browser
- Notebook
- Tablet
- Rescue-VM
- Proxmox-LXC
- später NodeOS-Geräten

Die Oberfläche wird also nicht an ein Gerät gebunden, sondern an eine Adresse, Identität und Sitzung.

Das passt exakt zur NodeOS-Idee:

> Der Arbeitsplatz ist nicht mehr der Rechner. Der Arbeitsplatz ist eine erreichbare Oberfläche plus persistenter Speicherzustand.

### 5.2 Betrieblicher Mehrwert

| Problem heute | Wirkung durch webOwie_nodeOS |
|---|---|
| zu viele Einzelcontainer | Zentralisierte Web-Node-Oberfläche |
| kleine SSDs auf Thin Clients | Daten werden gemountet oder extern angebunden |
| keine einheitliche UI | Browserbasierte Oberfläche überall |
| Docker-Overhead | Alpine + OpenRC + APK ohne Docker-Daemon |
| Recovery-Chaos | Live-ISO / Netboot-Pfad integrierbar |
| manuelle Installationen | reproduzierbares APK |
| Anbieterabhängigkeit | später Storage-Provider-Plugins |
| Proxmox-Dateizugriff umständlich | UI auf Storage-Bind-Mounts |

### 5.3 Strategischer Mehrwert

Dieses Projekt ist nicht nur „ArozOS auf Alpine“.

Es ist der Einstieg in:

```text
webOwie_nodeOS
  ├─ Node UI
  ├─ Storage Fabric
  ├─ Proxmox Connector
  ├─ Netboot/Recovery Layer
  ├─ Cloud Drive Provider
  ├─ LXC-native App Runtime
  └─ später: NodeOS Session Persistence
```

Die aktuelle APK ist damit der kleinste sinnvolle Produktkern.

Nicht perfekt. Aber real. Und reale, kleine, wartbare Kerne schlagen Fantasie-Monolithen. Leider eine Erkenntnis, die die IT-Branche seit Jahrzehnten kollektiv ignoriert, vermutlich aus sportlichen Gründen.

---

## 6. Ressourcenanalyse

### 6.1 Aktuelle Zielwerte aus Repository

Aus den bestehenden Dateien ergeben sich folgende harte technische Werte:

| Wert | Quelle / Bedeutung |
|---|---|
| Alpine Linux 3.24 | Build- und Live-ISO-Ziel |
| x86_64 | aktuelles Ziel-Architekturformat |
| OpenRC | Init-System |
| Port `8080` | HTTP-Zugriff auf NodeOS |
| Runtime unter `/var/lib/webowie-nodeos` | persistenter Runtime-Ort |
| Binary unter `/usr/bin/webowie-nodeos` | systemweite Ausführung |
| `max_upload_size=1024` | Upload-Limit in MB |
| `buffpool_size=256` | begrenzter Buffer-Pool |
| `upload_buf=25` | kleiner Upload-Puffer |
| `enable_docker=false` | Docker-Verwaltung deaktiviert |
| `allow_pkg_install=false` | Web-Paketinstallation deaktiviert |

### 6.2 Erwartete Ressourceneinsparung gegenüber Docker-Stacks

Exakte Werte müssen pro Zielnode gemessen werden. Aber die Architektur spart an den richtigen Stellen:

#### Wegfall Docker-Daemon

Ein typisches Docker/Compose-Setup bringt mindestens diese Systemlast mit:

| Komponente | Typische Idle-Last | Kommentar |
|---|---:|---|
| `dockerd` | ca. 80-180 MB RAM | je nach Setup, Images, Logs |
| `containerd` | ca. 40-100 MB RAM | Zusatzprozess |
| Docker shims | ca. 5-20 MB pro Container | multipliziert sich schnell |
| OverlayFS-Metadaten | variabel | I/O- und Speicher-Overhead |
| Compose-Netzwerke | gering bis mittel | zusätzliche NAT/Bridge-Komplexität |

Konservativ gerechnet spart ein Alpine-LXC ohne Docker-Daemon:

```text
RAM:     ca. 120-300 MB pro Node
CPU:     weniger Hintergrundprozesse, weniger Container-Shims
Disk:    ca. 500 MB bis mehrere GB weniger Image-/Layer-Daten
I/O:     weniger OverlayFS- und Log-Overhead
Boot:    schneller, weniger Dienste
```

Auf einem 4-GB-Node ist das nicht Kosmetik. Das ist Überlebensraum.

### 6.3 Alpine statt Debian-Container

Alpine bringt zusätzlich:

| Bereich | Wirkung |
|---|---|
| kleinere Basisschicht | weniger Disk-Verbrauch |
| musl + BusyBox | kleineres Userland |
| OpenRC | leichter als systemd in Container-Kontext |
| APK-Paket | reproduzierbare Installation |
| schneller Containerstart | wichtig für Recovery und kleine Nodes |

Konservativer Vergleich:

| Deployment | Typische Basisgröße | Bewertung |
|---|---:|---|
| Debian LXC + manuelle Installation | 500 MB bis 1.5 GB+ | solide, aber schwerer |
| Docker Compose Stack | 1 GB bis mehrere GB | viele Layer, viele Prozesse |
| Alpine LXC + runtime-only APK | ca. 300 MB bis 900 MB, abhängig von ffmpeg/tools | sinnvoller Zielkorridor |

`ffmpeg`, `git`, `curl`, `wget`, `nfs-utils`, `cifs-utils`, `fuse3` erhöhen die APK-Runtime bewusst. Das ist akzeptabel, weil sie reale NodeOS-Funktionen ermöglichen. Der Unterschied ist: diese Pakete sind explizit, sichtbar und reproduzierbar. Keine undurchsichtige Container-Lasagne.

### 6.4 Messmethode für reale Werte

Nach Installation werden Werte so ermittelt:

```sh
# RAM und Prozesslast
ps aux --sort=-rss | head -30
free -h

# Dienststatus
rc-service webowie-nodeos status
ss -tulpn | grep 8080

# Diskverbrauch
du -sh /var/lib/webowie-nodeos
apk info -s | sort -k2 -h

# LXC-Seite auf Proxmox
pct status <CTID>
pct exec <CTID> -- free -h
pct exec <CTID> -- du -sh /var/lib/webowie-nodeos
```

Für einen echten Gegencheck müssen mindestens drei Zustände gemessen werden:

```text
A) leerer Alpine LXC
B) Alpine LXC + webOwie_nodeOS APK idle
C) bisherige Docker/Compose-Alternative idle
```

Dann wird verglichen:

```text
Delta RAM = C - B
Delta Disk = C - B
Delta Prozesse = Prozessanzahl C - Prozessanzahl B
Delta Ports = offene Ports C - offene Ports B
Delta Dienste = Systemdienste C - Systemdienste B
```

Erst dann gibt es harte Zahlen. Alles andere ist Bauchgefühl mit Tabellenformatierung. Wir machen das nicht so, wir messen.

---

## 7. Welche Docker-/Compose-Services dadurch wegfallen können

Nicht jeder Dienst fällt automatisch weg. Aber mehrere typische Hilfscontainer werden überflüssig oder stark reduziert.

### 7.1 Direkt ersetzbar

| Bisheriger Diensttyp | Kann wegfallen? | Ersatz durch webOwie_nodeOS |
|---|---:|---|
| einfacher Web-Filebrowser | Ja | ArozOS/webOwie Dateioberfläche |
| statischer File-Download-Container | Ja | HTTP/UI-Zugriff über NodeOS |
| simpler Upload-Container | Ja | NodeOS Upload-Funktion |
| kleiner Admin-Webdesktop | Ja, teilweise | webOwie_nodeOS UI |
| temporärer HTTP-Share | Ja, meist | NodeOS Files / Reverse Proxy |
| eigener „Tools Dashboard“-Container | Ja, teilweise | NodeOS als Startoberfläche |

### 7.2 Teilweise ersetzbar

| Diensttyp | Bewertung |
|---|---|
| Nextcloud | Nicht vollständig ersetzen, wenn Kalender, Kontakte, Office, Gruppenfreigaben gebraucht werden. Für reine Dateiablage kann NodeOS reichen. |
| FileRun / FileBrowser / h5ai | Bei einfachem Datei-Webzugriff ersetzbar. |
| Cockpit | Nicht ersetzen, wenn echte Hostverwaltung gebraucht wird. In LXC bewusst nicht. |
| Portainer | Nicht ersetzen, wenn Docker-Management gewollt ist. Für NodeOS selbst aber unnötig. |
| Syncthing | Nicht ersetzen, wenn Peer-to-Peer-Sync benötigt wird. Später über Storage Fabric anders lösbar. |
| WebDAV-Container | Potenziell ersetzbar oder als Plugin anbinden. |
| Samba/NFS-Frontend-Container | Nicht blind ersetzen. Besser Storage auf Proxmox hostseitig mounten und in LXC binden. |

### 7.3 Soll NICHT ersetzt werden

| Dienst | Grund |
|---|---|
| Reverse Proxy wie Zoraxy/Caddy/Traefik | TLS, Routing und Public Exposure bleiben eigene Schicht |
| DNS/DHCP wie Technitium | Kritische Infrastruktur nicht in NodeOS verstecken |
| Proxmox selbst | Host-/Cluster-Steuerung bleibt Host-Ebene |
| Backup-System | NodeOS kann Oberfläche/Quelle sein, aber Backup bleibt eigene Sicherheitsdomäne |
| Monitoring | Muss unabhängig vom NodeOS laufen |

### 7.4 Docker-Compose-Reduktion als Zielbild

Vorher typischer Kleinstack:

```text
docker
containerd
compose
filebrowser
nginx-static-share
upload-service
admin-dashboard
helper-sidecar
optional webdav
optional sync
```

Nachher Zielbild:

```text
Alpine LXC
OpenRC
webOwie_nodeOS APK
Reverse Proxy extern
Storage hostseitig gemountet
```

Das reduziert die Schichten von:

```text
Host → Docker → Compose → Container → App → Volume
```

auf:

```text
Host → LXC → OpenRC → App → Bind Mount
```

Weniger Schichten. Weniger Fehler. Weniger „warum ist das Volume plötzlich leer?“. Manchmal ist Fortschritt einfach das Entfernen von Quatsch.

---

## 8. Logischer Gegencheck

### 8.1 These: „Wir sollten ArozOS komplett forken und umbauen.“

**Bewertung:** Falsch.

Ein harter Fork kostet dauerhaft:

- Merge-Aufwand
- Security-Backports
- Upstream-Konflikte
- Lizenzpflege
- Build-Fixes
- Testaufwand
- Dokumentationslast

**Bessere Lösung:**

```text
Upstream ArozOS unverändert halten
↓
Build-/Branding-Layer anwenden
↓
Alpine APK erzeugen
↓
webOwie-spezifische Module separat ergänzen
```

### 8.2 These: „Wir könnten einen eigenen NodeOS-Webdesktop bauen.“

**Bewertung:** Strategisch ineffizient.

Das wäre nur sinnvoll, wenn ArozOS architektonisch ungeeignet wäre. Aktuell ist es aber geeignet genug, um als Engine zu dienen. Der Engpass ist nicht der Webdesktop. Der Engpass ist Deployment, Storage, Clusterfähigkeit und Provider-Abstraktion.

Also bauen wir genau dort.

### 8.3 These: „Docker wäre einfacher.“

**Bewertung:** Kurzfristig ja, langfristig nein.

Docker ist bequem, aber auf kleinen Proxmox-Nodes mit 2-4 GB RAM und kleinen SSDs ist Docker oft unnötiger Ballast.

Für Entwicklungsumgebungen: okay.  
Für produktive Minimal-Nodes: schlechter Fit.

Alpine LXC + APK ist hier sauberer.

### 8.4 These: „ArozOS soll Host-Hardware verwalten.“

**Bewertung:** Nein.

In einem unprivilegierten LXC ist Host-Hardwareverwaltung falsch. Das muss Proxmox tun. NodeOS kann anzeigen, aber nicht unkontrolliert hostseitig schalten.

### 8.5 These: „Storage soll direkt aus NodeOS kommen.“

**Bewertung:** Nur abstrahiert.

NodeOS soll Storage sichtbar machen, aber nicht wild Blockdevices manipulieren.

Richtig:

```text
Proxmox mountet Storage
↓
LXC erhält Bind Mount
↓
NodeOS verwaltet Benutzerzugriff/UI
```

Später:

```text
NodeOS Storage Fabric
↓
Provider Plugins: Google Drive, OneDrive, S3, Nextcloud, IPFS, Storj
↓
lokaler Cache
↓
verschlüsselte Fragmente / Metadaten
```

Aber nicht:

```text
Web-App formatiert Festplatten im Container
```

Das wäre Architektur als Unfallbericht.

---

## 9. Integration in unseren Stack

### 9.1 Zielrolle im Stack

`webOwie_nodeOS` wird als **Node UI Layer** integriert.

```text
[User Browser]
      ↓
[Reverse Proxy / Zoraxy / Caddy]
      ↓
[webOwie_nodeOS LXC]
      ↓
[Proxmox Bind Mounts / Storage Fabric]
      ↓
[Local / Cloud / Cluster Storage]
```

### 9.2 Proxmox-LXC-Zielprofil

Empfohlenes Profil:

```text
OS:           Alpine Linux 3.24
Container:    unprivileged LXC
CPU:          1-2 vCPU
RAM:          512 MB minimal, 1024-2048 MB empfohlen
Disk:         4-8 GB root, persistent data extern
Network:      vmbr0 oder Management-Bridge
Port:         8080 intern
Reverse Proxy: extern
```

### 9.3 Storage-Anbindung

Kurzfristig:

```text
Proxmox Host Storage → pct bind mount → /srv/storage im LXC → NodeOS Storage Pool
```

Beispiel:

```sh
pct set <CTID> -mp0 /srv/storage,mp=/srv/storage
pct restart <CTID>
```

Langfristig:

```text
NodeOS Storage Fabric
  ├─ local-path provider
  ├─ Proxmox bind provider
  ├─ Google Drive provider
  ├─ OneDrive provider
  ├─ Nextcloud/WebDAV provider
  ├─ S3 provider
  ├─ Storj provider
  └─ IPFS/CID index provider
```

### 9.4 Netboot-/Recovery-Bezug

Die Live-ISO-Architektur passt zum Netboot-Konzept:

```text
PXE / netboot.xyz
      ↓
webOwie_nodeOS Live ISO
      ↓
Alpine Setup / Recovery
      ↓
APK Install
      ↓
Node online
```

Damit wird der Node nicht mehr manuell geflickt, sondern reproduzierbar wiederhergestellt.

---

## 10. Sicherheitsmodell

### 10.1 Sicherheitsprinzipien

| Prinzip | Umsetzung |
|---|---|
| Least Privilege | unprivileged LXC |
| Keine Host-Kontrolle aus UI | hwman/pwman/docker deaktiviert |
| Kein automatisches Port-Mapping | UPnP deaktiviert |
| Reproduzierbarkeit | APK statt manueller Bastelinstallation |
| Reverse Proxy getrennt | TLS und Exposure außerhalb NodeOS |
| Storage getrennt | Proxmox bindet Speicher, NodeOS sieht Pfade |
| Keine stillen Cloud-Zugriffe | Provider später nur per explizitem Opt-in |

### 10.2 Risiken

| Risiko | Bewertung | Gegenmaßnahme |
|---|---:|---|
| Upstream ArozOS Bug | Mittel | Upstream pinned releases, Smoke Tests |
| Web UI Exposure | Mittel bis hoch | Reverse Proxy, Auth, Firewall |
| Upload-Missbrauch | Mittel | Upload-Limits, Quotas, User-Rollen |
| LXC Escape | Niedrig bis kritisch | unprivileged LXC, keine Host-Mounts mit root Schreibrechten |
| Storage-Rechte falsch gemappt | Hoch | UID/GID-Mapping dokumentieren |
| Cloud Provider Lock-in | Mittel | Plugin-Abstraktion |
| Docker-in-LXC Versuchung | Hoch, weil Menschen | bleibt deaktiviert |

### 10.3 Harte Grenze

NodeOS darf nicht zur versteckten Host-Control-Plane werden.

Erlaubt:

```text
anzeigen, bedienen, Dateien verwalten, Sessions halten, Storage abstrahieren
```

Nicht erlaubt:

```text
Host-Pakete installieren, Host rebooten, Docker verwalten, block devices formatieren, Ports automatisch öffnen
```

---

## 11. Roadmap

### Phase 1: Stabiler Runtime-Kern

- APK weiter verwenden
- OpenRC-Service validieren
- LXC-Profil dokumentieren
- Reverse-Proxy-Beispiel ergänzen
- Storage-Bind-Mount-Beispiel produktionsreif machen

### Phase 2: Stack-Integration

- Proxmox Helper Script für LXC-Erstellung
- Netboot-Installationspfad
- Standard-CT-Profil:
  - 1-2 vCPU
  - 512-2048 MB RAM
  - 4-8 GB root disk
  - bind mount für Daten
- Healthcheck:
  - `GET /` auf Port `8080`
  - OpenRC Service Status

### Phase 3: NodeOS Storage Fabric

- Provider-Interface definieren
- lokaler Cache
- Metadatenkatalog
- optional verschlüsselte Chunk-Verteilung
- Google Drive als erster Prototyp nur für:
  - ISOs
  - Templates
  - Backups
  - Snippets
- keine VM-Disks direkt auf Cloud Drive

### Phase 4: Proxmox UI/Storage Plugin

Ziel:

```text
Proxmox → Storage hinzufügen → NodeOS Drive / Google Drive → lokale Cache-Policy → sichtbar für ISO/Templates/Backups
```

Nicht Ziel:

```text
laufende VM-Disks direkt auf Google Drive
```

Das wäre kein Storage, das wäre ein Verfügbarkeitsgebet mit OAuth.

### Phase 5: Session Persistence

- Benutzer-Sitzung speichern
- Arbeitsflächenzustand versionieren
- Dateien und Session-State trennen
- später über Storage Fabric synchronisieren

---

## 12. Welche konkreten Werte wir ermittelt haben

### 12.1 Aus Repository/Config fest ermittelt

| Parameter | Wert |
|---|---|
| Produktname | `webOwie_nodeOS` |
| Base Engine | ArozOS |
| Host OS | Alpine Linux |
| Init | OpenRC |
| Runtime-Port | `8080` |
| Runtime-Root | `/var/lib/webowie-nodeos/files` |
| Runtime-TMP | `/var/lib/webowie-nodeos/tmp` |
| Paketname | `webowie-nodeos` |
| Architektur | `x86_64` |
| Lizenz | `GPL-3.0-only` |
| Docker Integration | deaktiviert |
| Hardware Management | deaktiviert |
| Power Management | deaktiviert |
| UPnP | deaktiviert |
| Arozcast TURN | deaktiviert |
| Uploadlimit | `1024 MB` |
| Bufferpool | `256` |
| Upload Buffer | `25` |

### 12.2 Noch zu messen

Diese Werte müssen nach Deployment gemessen werden:

| Wert | Befehl |
|---|---|
| Idle RAM | `free -h`, `ps aux --sort=-rss` |
| Runtime Disk | `du -sh /var/lib/webowie-nodeos` |
| APK Paketgröße | `apk info -s webowie-nodeos` |
| offene Ports | `ss -tulpn` |
| Startzeit | `time rc-service webowie-nodeos restart` |
| HTTP Smoke | `curl -I http://127.0.0.1:8080/` |
| Container Overhead | `pct exec <CTID> -- ps aux` |

### 12.3 Erwarteter Einsparrahmen

Konservative Zielannahme pro Node gegenüber Docker/Compose-Variante:

```text
RAM-Einsparung:       120-300 MB
Disk-Einsparung:      500 MB bis mehrere GB
Prozessreduktion:     dockerd + containerd + shims fallen weg
Komplexitätsreduktion: kein Compose-Netz, keine Container-Layer, weniger Volumes
Angriffsfläche:       weniger Daemons, weniger privilegierte Steuerpfade
```

Die Zahlen werden nach realem Deployment verifiziert. Bis dahin gelten sie als Planwert, nicht als Marketing-Märchen. Wir sind hier nicht im SaaS-Vertrieb.

---

## 13. Entscheidung

### RECOMMENDATION

`webOwie_nodeOS` wird in den Stack übernommen.

Aber nicht als unkontrollierter Fork und nicht als Docker-Schrankwand, sondern als:

```text
Alpine-native APK
OpenRC Service
unprivileged Proxmox LXC
ArozOS Upstream Engine
webOwie Branding Layer
Proxmox Bind-Mount Storage
später Storage Fabric Plugins
```

Das ist der richtige Pfad, weil er:

1. sofort nutzbaren Funktionsumfang bringt,
2. Entwicklungszeit spart,
3. RAM und Disk schont,
4. Docker-Overhead vermeidet,
5. Alpine/Proxmox sauber nutzt,
6. Recovery/Netboot-fähig bleibt,
7. später zu NodeOS Storage Fabric erweitert werden kann.

---

## 14. NEXT STEPS

### Sofort

1. Aktuelles APK in Alpine-LXC testen.
2. Speicherverbrauch messen.
3. Port `8080` per Reverse Proxy anbinden.
4. Bind-Mount für `/srv/storage` testen.
5. Filebrowser-/Upload-Ersatz gegen vorhandene Docker-Container vergleichen.

### Danach

1. Proxmox-LXC-Helper-Script bauen.
2. Healthcheck-Script ergänzen.
3. Storage-Fabric-Design als eigenes Dokument anlegen.
4. Google-Drive-Provider als read/cache-only Prototyp entwerfen.
5. Liste der ersetzten Docker-Services aus realem Compose-Stack ableiten.

### Harte Regel

Erst messen, dann behaupten.

```text
Messen → vergleichen → entfernen → dokumentieren → automatisieren
```

Nicht:

```text
fühlen → umbauen → hoffen → fluchen
```

Menschen haben schon genug Infrastruktur so betrieben. Wir müssen das Elend nicht ehrenamtlich fortsetzen.

---

## 15. Kurzfazit

`webOwie_nodeOS` ist kein Nebenprojekt. Es ist der kleinste stabile Kern für eine eigene NodeOS-Oberfläche.

Die Stärke liegt nicht darin, ArozOS zu kopieren, sondern darin, ArozOS als Engine zu verwenden und darum herum eine saubere webOwie-Infrastruktur zu bauen:

```text
leichtgewichtig
Alpine-native
Proxmox-tauglich
LXC-sicher
storage-erweiterbar
browserbasiert
wartbar
```

Damit ist die Architekturentscheidung eindeutig:

> **Wir übernehmen das in den Stack. Wir bauen nicht alles nach. Wir bauen die strategischen Schichten darum herum.**
