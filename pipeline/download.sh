#!/usr/bin/env bash
# Downloads input data: three GTFS feeds, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# Warsaw & Grodzisk Mazowiecki on one sheet: ZTM Warszawa via mkuran.pl
# (buses 3, trams 0, metro 1, SKM 2 — shapes and official colours), GPA
# Grodzisk (cdn.zbiorkom.live, no shapes) and the WKD railway (cdn.zbiorkom.live).
# Modes are separated by route_type at build time.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs-ztm data/gtfs-gpa data/gtfs-wkd data/gtfs-pruszkow data/gtfs-legionowo data/osm web/vendor

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements. `grep -q '"elements"'` — the guard this family used
# everywhere — passes on a truncated response too: Brașov's roads arrived as a
# 65 kB fragment that still contained the string, was taken for complete, and
# silently skipped the city (16.08.2026).
# The minimum differs by extract: a road network runs to tens of thousands of
# ways, a city rail network to a few hundred, so the caller passes its own floor
# rather than sharing one.
# A rejected file is deleted rather than left behind — the `[ ! -f … ]` gates
# below only ask whether the file exists, so a fragment on disk would be taken
# for a finished download on the next run.
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# 1) GTFS — the regional bundle (stable URL, refreshed in place by TPBI)
fetch_gtfs () { # dir url
  if [ ! -f "$1/routes.txt" ]; then
    echo "== GTFS → $1 =="
    curl -fL --retry 3 --max-time 600 -o "$1.zip" "$2"
    unzip -o "$1.zip" -d "$1"
  fi
}
fetch_gtfs data/gtfs-ztm "https://mkuran.pl/gtfs/warsaw.zip"
fetch_gtfs data/gtfs-gpa "https://cdn.zbiorkom.live/gtfs/warsaw-gpa.zip"
fetch_gtfs data/gtfs-wkd "https://cdn.zbiorkom.live/gtfs/pkp-wkd.zip"

# 1b) the commune networks around Warsaw — files.girlc.at (CC0, regenerated
#     nightly from the operators' timetables). The host answers 403 to a bare
#     curl; a browser User-Agent is all it wants.
fetch_girlcat () { # dir slug
  if [ ! -f "$1/routes.txt" ]; then
    echo "== GTFS → $1 (files.girlc.at/gtfs/$2.zip) =="
    curl -fL --retry 3 --max-time 300 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" \
      -o "$1.zip" "https://files.girlc.at/gtfs/$2.zip"
    unzip -o "$1.zip" -d "$1"
  fi
}
fetch_girlcat data/gtfs-lomianki  lomianki       # KM Łomianki (1–3)
fetch_girlcat data/gtfs-otwock    otwock         # Otwock free city buses (M1–M3, W1)
fetch_girlcat data/gtfs-minsk     powiat_minski  # Mińsk county (P01–P13, C01)
fetch_girlcat data/gtfs-radzymin  radzymin       # Radzymin (R1–R38)
fetch_girlcat data/gtfs-sulejowek sulejowek      # Sulejówek A1/A2 + Wiązowna W3
fetch_girlcat data/gtfs-wieliszew wieliszew      # Wieliszew W1–W3
fetch_girlcat data/gtfs-zabki     zabki          # Ząbki Z1–Z4M (no shapes)

# 1z) Pruszków — the town's ten lines (1–10B). No producer GTFS exists: the
#     town publishes PDF sheets and points riders at kiedyPrzyjedzie, whose
#     data cdn.zbiorkom.live republishes as a plain feed. No shapes.
if [ ! -f data/gtfs-pruszkow/routes.txt ]; then
  echo "== Pruszków =="
  curl -fL --retry 3 --max-time 300 -o data/gtfs-pruszkow.zip "https://cdn.zbiorkom.live/gtfs/warsaw-pruszkow.zip"
  unzip -o data/gtfs-pruszkow.zip -d data/gtfs-pruszkow
fi

# 1y) Powiat legionowski — the county's six free lines 7P–12P. No GTFS
#     anywhere; pipeline/kp-legionowo-gtfs.py turns the county's own
#     KiedyPrzyjedzie instance into one. The ZTM lines that also serve
#     Legionowo (723, 731, 736, N63 and the L family) are already in the ZTM
#     feed above and are filtered out there.
if [ ! -f data/gtfs-legionowo/routes.txt ]; then
  echo "== Powiat legionowski via KiedyPrzyjedzie =="
  python3 pipeline/kp-legionowo-gtfs.py data/gtfs-legionowo
fi

# 2) OSM — from the Geofabrik mazowieckie extract, not Overpass. On 9.09.2026
#    every public mirror answered these queries with 504 for an hour (the wall
#    Berlin, London, São Paulo and Vienna hit before), so the cuts are made
#    locally: pipeline/pbf-cut.py (needs `pip3 install --user osmium`) writes
#    exactly the JSON Overpass would have returned, node ids included, for the
#    same three boxes — the region's roads, the eastern strip the Mińsk county
#    lines need, and the rails (tram, metro, and rail for the SKM and WKD).
if [ ! -f data/osm/warsaw.json ] || [ ! -f data/osm/warsaw-east.json ] || [ ! -f data/osm/warsaw-rail.json ]; then
  python3 -c "import osmium" 2>/dev/null || { echo "brak pakietu osmium — zainstaluj: pip3 install --user osmium" >&2; exit 1; }
  if [ ! -f data/mazowieckie-latest.osm.pbf ]; then
    echo "== Geofabrik mazowieckie-latest.osm.pbf =="
    curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o data/mazowieckie-latest.osm.pbf       "https://download.geofabrik.de/europe/poland/mazowieckie-latest.osm.pbf"
  fi
  echo "== cutting OSM out of the extract =="
  python3 pipeline/pbf-cut.py
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/bucharest-region.zip data/osm/warsaw.json data/osm/warsaw-rail.json 2>/dev/null || true
