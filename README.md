# Warsaw Region Public Transport — interactive map

Interactive, poster-grade map of the public transport of **Warsaw, the
Grodzisk Mazowiecki county and the communes around the city on one sheet**:
ZTM Warszawa buses, trams, the metro M1/M2 and the SKM rapid rail, the GPA
Grodzisk buses, the WKD railway and — since 23.08.2026 — seven commune
networks (Łomianki, Otwock, Mińsk county, Radzymin, Sulejówek & Wiązowna,
Wieliszew, Ząbki) — 416 lines / 15 025 km drawn along the real street and
track geometry.

## Live

**https://miqell24.github.io/warsaw-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8155 (`npm run serve`).

Ten feeds, one picture:

| mode | feed · route_type | lines | graph |
|---|---|---|---|
| buses | ZTM Warszawa (mkuran.pl) · 3 + GPA Grodzisk · 3 + seven commune feeds (files.girlc.at) · 3 | 381 | OSM roadways |
| trams | ZTM · 0 | 27 | `railway=tram` tracks |
| metro | ZTM · 1 — M1, M2 in official colours | 2 | `railway=subway` tunnels |
| SKM & WKD | ZTM · 2 (S1–S4, S40, official colours) + WKD feed · 2 | 6 | `railway=rail/light_rail` |

Build quirks worth knowing: the GPA and Ząbki feeds ship no shapes and none
of the commune feeds a direction_id, so their stop sequences are the matching
observations and the headsign is the direction key; all bus operators pour
into ONE bus cfg, so ground they share is drawn once with the union of their
numbers; line keys are the operators' own designations — Otwock's W1 (to
Metro Imielin) and Wieliszew's W1 (to Legionowo) are one key drawn in two
places, and the frontend tells cross-mode twins (bus 1 / tram 1, Otwock's M1 /
the metro's M1) apart by mode; the Mińsk county lines needed an eastern strip
of OSM roads (`data/osm/warsaw-east.json`, merged at load via `cfg.osmFiles`); the WKD feed's second
route ("WKD ZKA", the rail-replacement bus) stays out by the route-type filter;
the representative variant of every line+direction is the LONGEST pattern
still worked by ≥15% of the busiest pattern's trips.

## Two views and a diagram

The panel's **Corridors / Lines** switch redraws the network line by line (up to
four coloured strands side by side, busier roadways as one grey trunk with its
numbers beside it; `npm run lines`, checked by `npm run audit`). **/schematic/**
is the automatic network diagram: stop order, branches and shared segments from
the ten feeds, octilinear layout, buses navy, trams red, metro / SKM / WKD in
their own colours (`npm run schematic`, `pipeline/schematic/`). 383 + 27 + 8
lines, 5 152 stations, crossings 1 701 → 580.

## Pipeline

`npm run download` fetches the three feeds, OSM roadways and rails (Overpass,
bbox 51.87–52.54 N / 20.18–21.52 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8155.

Data: ZTM Warszawa via mkuran.pl (Mikołaj Kuranowski) · GPA · WKD ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
