#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cuts the OSM extracts out of the Geofabrik voivodeship .pbf files — the same
JSON shape Overpass returns ('elements': ways with tags, node ids and
geometry), so build.mjs cannot tell the difference.

Three cuts, the three boxes download.sh asks Overpass for:
  data/osm/warsaw.json       roads over the ZTM zone and the communes
  data/osm/warsaw-east.json  the eastern strip added for the Minsk county lines
  data/osm/warsaw-rail.json  tram, metro (subway) and rail for the SKM and WKD

Written 9.09.2026, when every public Overpass mirror answered 504 for an hour
(the wall Berlin, London, Sao Paulo and Vienna hit before).
"""
import json, os, re, sys
import osmium

ROOT = os.path.join(os.path.dirname(__file__), '..')
PBFS = [os.path.join(ROOT, 'data', 'mazowieckie-latest.osm.pbf')]
ROAD_BOX = (51.87, 20.18, 52.54, 21.52)   # S, W, N, E — as download.sh
TRAM_BOX = (51.87, 21.50, 52.54, 21.92)   # the eastern road strip, same filter
RAIL_BOX = (51.87, 20.18, 52.54, 21.52)
HW = re.compile(r'^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$')
TRAM = None  # the second cut here is roads, not track
RAIL = re.compile(r'^(subway|tram|light_rail|rail)$')

road_file = os.path.join(ROOT, 'data/osm/warsaw.json')
tram_file = os.path.join(ROOT, 'data/osm/warsaw-east.json')
rail_file = os.path.join(ROOT, 'data/osm/warsaw-rail.json')
need_road = not os.path.exists(road_file)
need_tram = not os.path.exists(tram_file)
need_rail = not os.path.exists(rail_file)
print('drogi:', need_road, '| pas wschodni:', need_tram, '| szyny:', need_rail, flush=True)
if not (need_road or need_tram or need_rail):
    sys.exit(0)
os.makedirs(os.path.join(ROOT, 'data/osm'), exist_ok=True)
out_road, out_tram, out_rail = [], [], []


def inside(box, la0, lo0, la1, lo1):
    return la1 >= box[0] and la0 <= box[2] and lo1 >= box[1] and lo0 <= box[3]


class H(osmium.SimpleHandler):
    def way(self, w):
        tags = w.tags
        hw, rw = tags.get('highway'), tags.get('railway')
        is_road = need_road and hw is not None and HW.match(hw)
        is_tram = need_tram and hw is not None and HW.match(hw)
        is_rail = need_rail and rw is not None and RAIL.match(rw)
        if not (is_road or is_tram or is_rail):
            return
        geom, ids = [], []
        la0, la1, lo0, lo1 = 90.0, -90.0, 180.0, -180.0
        for n in w.nodes:
            try:
                lo, la = n.lon, n.lat
            except osmium.InvalidLocationError:
                continue
            # node ids ride along: buildGraph() builds topology from el.nodes
            # and SILENTLY skips ways without them (the London t13 hole)
            ids.append(n.ref)
            geom.append({'lat': la, 'lon': lo})
            if la < la0: la0 = la
            if la > la1: la1 = la
            if lo < lo0: lo0 = lo
            if lo > lo1: lo1 = lo
        if len(geom) < 2:
            return
        el = {'type': 'way', 'id': w.id, 'nodes': ids,
              'tags': {t.k: t.v for t in tags}, 'geometry': geom}
        if is_road and inside(ROAD_BOX, la0, lo0, la1, lo1):
            out_road.append(el)
        if is_tram and inside(TRAM_BOX, la0, lo0, la1, lo1):
            out_tram.append(el)
        if is_rail and inside(RAIL_BOX, la0, lo0, la1, lo1):
            out_rail.append(el)


for pbf in PBFS:
    if not os.path.exists(pbf):
        sys.exit('brak ' + pbf + ' — pobierz go (pipeline/download.sh)')
    print('czytam', os.path.basename(pbf), flush=True)
    H().apply_file(pbf, locations=True, idx='flex_mem')

GEN = 'pbf-cut.py (Geofabrik mazowieckie)'
seen = set()
for need, path, els, what in ((need_road, road_file, out_road, 'drogi'),
                              (need_tram, tram_file, out_tram, 'drogi (wschód)'),
                              (need_rail, rail_file, out_rail, 'tory kolejowe')):
    if not need:
        continue
    uniq, ids = [], set()
    for e in els:                      # a way on a voivodeship border is in both
        if e['id'] in ids:
            continue
        ids.add(e['id'])
        uniq.append(e)
    json.dump({'version': 0.6, 'generator': GEN, 'elements': uniq}, open(path, 'w'))
    print(f'{what}: {len(uniq)}', flush=True)
print('gotowe', flush=True)
