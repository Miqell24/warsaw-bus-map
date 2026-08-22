# Warsaw & Grodzisk Mazowiecki Public Transport — interactive map

Interactive, poster-grade map of the public transport of **Warsaw and the
Grodzisk Mazowiecki county on one sheet**: ZTM Warszawa buses, trams, the
metro M1/M2 and the SKM rapid rail, the GPA Grodzisk buses and the WKD
railway — 379 lines / 13 568 km drawn along the real street and track
geometry, weighted mean matching error 1.54 m.

## Live

**https://miqell24.github.io/warsaw-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8155 (`npm run serve`).

Three feeds, one picture:

| mode | feed · route_type | lines | graph |
|---|---|---|---|
| buses | ZTM Warszawa (mkuran.pl) · 3 + GPA Grodzisk · 3 | 344 | OSM roadways |
| trams | ZTM · 0 | 27 | `railway=tram` tracks |
| metro | ZTM · 1 — M1, M2 in official colours | 2 | `railway=subway` tunnels |
| SKM & WKD | ZTM · 2 (S1–S4, S40, official colours) + WKD feed · 2 | 6 | `railway=rail/light_rail` |

Build quirks worth knowing: the GPA feed ships no shapes and no direction_id,
so its stop sequences are the matching observations and the headsign is the
direction key; the two bus operators pour into ONE bus cfg, so ground they
share is drawn once with the union of their numbers; the WKD feed's second
route ("WKD ZKA", the rail-replacement bus) stays out by the route-type filter;
the representative variant of every line+direction is the LONGEST pattern
still worked by ≥15% of the busiest pattern's trips.

## Two views and a diagram

The panel's **Corridors / Lines** switch redraws the network line by line (up to
four coloured strands side by side, busier roadways as one grey trunk with its
numbers beside it; `npm run lines`, checked by `npm run audit`). **/schematic/**
is the automatic network diagram: stop order, branches and shared segments from
the three feeds, octilinear layout, buses navy, trams red, metro / SKM / WKD in
their own colours (`npm run schematic`, `pipeline/schematic/`). 344 + 27 + 8
lines, 4 344 stations, 3 298 corridors, crossings 1 604 → 541.

## Pipeline

`npm run download` fetches the three feeds, OSM roadways and rails (Overpass,
bbox 51.87–52.54 N / 20.18–21.52 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8155.

Data: ZTM Warszawa via mkuran.pl (Mikołaj Kuranowski) · GPA · WKD ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
