# Warsaw Region Public Transport — interactive map

Interactive, poster-grade map of the public transport of **Warsaw, the
Grodzisk Mazowiecki county and the towns and communes around the city on one
sheet**: ZTM Warszawa buses, trams, the metro M1/M2 and the SKM rapid rail, the
GPA Grodzisk buses, the WKD railway, seven commune networks (Łomianki, Otwock,
Mińsk county, Radzymin, Sulejówek & Wiązowna, Wieliszew, Ząbki) and — since
9.09.2026 — **Pruszków** and the free county lines of **Powiat legionowski**.
**449 lines / 15 771 km** drawn along the real street and track geometry,
weighted mean matching error 0.8 m.

## Live

**https://miqell24.github.io/warsaw-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8155 (`npm run serve`).

Twelve feeds, one picture:

| mode | feed · route_type | lines | graph |
|---|---|---|---|
| buses | ZTM Warszawa (mkuran.pl) · 3 + GPA Grodzisk · 3 + **Pruszków** · 3 + **Powiat legionowski** · 3 + seven commune feeds (files.girlc.at) · 3 | 413 | OSM roadways |
| trams | ZTM · 0 | 27 | `railway=tram` tracks |
| metro | ZTM · 1 — M1, M2 in official colours | 2 | `railway=subway` tunnels |
| SKM & WKD | ZTM · 2 (S1–S4, S40, official colours) + WKD feed · 2 | 6 | `railway=rail/light_rail` |

**Pruszków** (1, 2, 3, 4, 5, 6, 7, 9, 10, 10B) publishes PDF sheets and points
riders at kiedyPrzyjedzie; cdn.zbiorkom.live republishes that as a plain feed,
which is what this map reads. No shapes — the stop sequence is the observation.

**Powiat legionowski** (7P, 8P, 9P, 10P, 11P, 12P — free, paid for out of the
county budget) publishes no GTFS at all, so `pipeline/kp-legionowo-gtfs.py`
builds one from the county's own KiedyPrzyjedzie instance, the way the Kraków
map does for Wieliczka. That instance also answers for the ZTM lines serving
Legionowo — 723, 731, 736, N63 and the whole L family — and those are already
on this map from ZTM's own feed, so the scraper keeps the county's nP lines
only. (The link that started this, `mobilitydatabase.org/feeds/gbfs/gbfs-dott-legionowo`,
is Dott's scooter share, not a timetable.)

**Twelve operators mean repeated numbers**: Pruszków runs a 1 to 10B, Łomianki
a 1, 2 and 3, and ZTM's own trams are numbered 1–35. A number used by more than
one of them carries its operator's code in the KEY (`pru:1`, `lom:1`) and
prints bare on the street; ZTM is the home network and keeps its numbers as
they are. The panel groups its chips by operator, the way the Berlin and
Randstad maps do.

Build quirks worth knowing: the GPA and Ząbki feeds ship no shapes and none
of the commune feeds a direction_id, so their stop sequences are the matching
observations and the headsign is the direction key; all bus operators pour
into ONE bus cfg, so ground they share is drawn once with the union of their
numbers; line keys are the operators' own designations, with an
operator code where two of them use the same number — Otwock's W1 (to Metro
Imielin) and Wieliszew's W1 (to Legionowo) were one key drawn in two places
until 9.09.2026 and are now two, each printing "W1"; the Mińsk county lines needed an eastern strip
of OSM roads (`data/osm/warsaw-east.json`, merged at load via `cfg.osmFiles`);
the OSM now comes from the Geofabrik mazowieckie extract rather than Overpass,
which answered 504 for an hour on 9.09.2026 (`pipeline/pbf-cut.py`, same boxes); the WKD feed's second
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
