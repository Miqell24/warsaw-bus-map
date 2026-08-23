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
mkdir -p data/gtfs-ztm data/gtfs-gpa data/gtfs-wkd data/osm web/vendor

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

# 2) OSM — roadways over the whole region (GTFS stops extent 51.92–52.49 N,
#    20.24–21.46 E plus margin: the ZTM zone-2 communes on every side and
#    the Grodzisk county in the south-west)
if [ ! -f data/osm/warsaw.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900][maxsize:1500000000];way(51.87,20.18,52.54,21.52)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/warsaw.json --data-urlencode "data=$Q" "$EP" \
       && ok_json "data/osm/warsaw.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/warsaw.json; echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2a) OSM — the eastern strip added for the Mińsk county lines (their stops
#     reach 21.86 E, the first extract stopped at 21.52). Merged with the main
#     extract at build time (cfg.osmFiles), so the big file is never refetched.
if [ ! -f data/osm/warsaw-east.json ]; then
  echo "== Overpass (roads, eastern strip) =="
  Q='[out:json][timeout:900][maxsize:1500000000];way(51.87,21.50,52.54,21.92)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/warsaw-east.json --data-urlencode "data=$Q" "$EP" \
       && ok_json "data/osm/warsaw-east.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/warsaw-east.json; echo "Overpass (east): all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — rails for the tram/metro/SKM+WKD modes: tram tracks, metro tunnels
#     (railway=subway) and rail/light_rail for the SKM and the WKD. Same bbox.
if [ ! -f data/osm/warsaw-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:600][maxsize:1000000000];way(51.87,20.18,52.54,21.52)["railway"~"^(subway|tram|light_rail|rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 300 -o data/osm/warsaw-rail.json --data-urlencode "data=$QT" "$EP" \
       && ok_json "data/osm/warsaw-rail.json" 40; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/warsaw-rail.json; echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/bucharest-region.zip data/osm/warsaw.json data/osm/warsaw-rail.json 2>/dev/null || true
