// Schematic mode configuration. Every numeric knob of the layout cost lives
// here and can be overridden from the CLI: npm run schematic -- --iters=80 --w4=8
// Weights follow the agreed cost specification (w1…w8).
// ZTM Warszawa: stop_id = 4-digit complex + 2-digit pole ("100101" → 1001);
// stop_code carries only the pole, so the id is the complex key
const ZTM_GROUP = (s) => String(s.stop_id || '').slice(0, 4);

export const CONFIG = {
  // GTFS intake — mirrors the MODES of pipeline/build.mjs, minus everything OSM
  feeds: [
    // Warsaw & Grodzisk: one ZTM bundle (mkuran.pl) split by route_type, the
    // GPA buses and the WKD — six entries, five drawing modes. The rail modes
    // (metro, skm, wkd) are drawn in their own colours, never merged with the
    // tram stroke.
    { mode: 'bus', label: 'ZTM Warszawa — buses', gtfsDir: 'data/gtfs-ztm', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => (/^Z-?\d/.test(sn) ? null : sn), groupOf: ZTM_GROUP },
    { mode: 'bus', label: 'GPA Grodzisk — buses', gtfsDir: 'data/gtfs-gpa', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => (/^Z-?\d/.test(sn) ? null : sn) },
    // the commune networks (files.girlc.at) — same keys as the geographic map
    { mode: 'bus', label: 'KM Łomianki', gtfsDir: 'data/gtfs-lomianki', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn },
    { mode: 'bus', label: 'Otwock', gtfsDir: 'data/gtfs-otwock', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => (/^\./.test(sn) ? null : sn) },
    { mode: 'bus', label: 'Powiat miński', gtfsDir: 'data/gtfs-minsk', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn },
    { mode: 'bus', label: 'Radzymin', gtfsDir: 'data/gtfs-radzymin', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn, nameFix: (n) => n.replace(/^([^,]+),\s+/, '$1 ') },
    { mode: 'bus', label: 'Sulejówek & Wiązowna', gtfsDir: 'data/gtfs-sulejowek', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn },
    { mode: 'bus', label: 'Wieliszew', gtfsDir: 'data/gtfs-wieliszew', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn, titleCase: true },
    { mode: 'bus', label: 'Ząbki', gtfsDir: 'data/gtfs-zabki', color: '#0059a9', colorDark: '#00294f',
      routeTypes: ['3'], mapKey: (sn) => sn },
    { mode: 'tram', label: 'Tramwaje Warszawskie', gtfsDir: 'data/gtfs-ztm', color: '#d6212b', colorDark: '#7c1116',
      routeTypes: ['0'], mapKey: (sn) => sn, groupOf: ZTM_GROUP },
    { mode: 'metro', label: 'Metro', gtfsDir: 'data/gtfs-ztm', color: '#0000BB', colorDark: '#000060',
      routeTypes: ['1'], mapKey: (sn) => sn, groupOf: ZTM_GROUP },
    { mode: 'skm', label: 'SKM', gtfsDir: 'data/gtfs-ztm', color: '#2E8EC8', colorDark: '#174a68',
      routeTypes: ['2'], mapKey: (sn) => sn, groupOf: ZTM_GROUP },
    { mode: 'wkd', label: 'WKD', gtfsDir: 'data/gtfs-wkd', color: '#a518a3', colorDark: '#5a0c59',
      routeTypes: ['2'], mapKey: (sn) => sn },
  ],

  // variants: a stop-sequence pattern of a line+direction is a real branch when
  // it carries a meaningful share of service — depot runs and rare short-turns
  // must not become diagram branches (rule 8)
  variantMinShare: 0.15, // of the dominant variant's trip count
  variantMinTrips: 3,
  variantMax: 4, // per line+direction

  // limited-stop services (Kraków's 7xx): a GTFS hop longer than this is treated
  // as an express skipping stops, and is redrawn along the local corridor when
  // one runs under it within expressDetourMax of the direct distance
  expressHopM: 1200,
  expressDetourMax: 1.7,
  expressBridgeM: 400, // m — gap between corridors the express search may step over

  // poles → stations: the stop_code group ("835-03" → "835") is shared between
  // the bus and tram feeds, so cross-feed merging is data-driven
  groupMergeM: 300, // poles of one feed+group cluster only within this radius (ZTP reuses group numbers)
  crossFeedMergeM: 400, // same group number in two feeds merges within this radius
  nameMergeM: 150, // fallback: identical normalized name across feeds

  // ---------- layout (Etap 2) ----------
  grid: 140, // m — FLOOR of meters-per-grid-unit; the real scale is fitted from data
  // Which corridor sets the scale (see the note in layout.mjs). Swept on
  // crossings / reversed / strained bearings out of 861 corridors:
  //   0.5 → 97 / 9 / 67   0.35 → 87 / 5 / 49
  //   0.25 → 87 / 4 / 43  0.15 → 89 / 5 / 22
  // Crossings are flat from 0.35 down, so the low percentile is close to free
  // and buys back most of the direction errors. 0.2 keeps the diagram compact.
  scalePercentile: 0.2,
  iters: 20, // improvement rounds (each sweeps all nodes; stops early when nothing moves)
  // the finished drawing is inflated by this factor (see build-schematic.mjs):
  // Warsaw's 4 300 stations needed air between them (user request 22.08.2026)
  spread: 1.5,
  radialGamma: 0.5, // sub-linear (√) radial compression of the initial positions
  radialR0: 2500, // m — inner radius kept uncompressed (the city core keeps proportions)
  // Corridors are deliberately LONGER here than on the Kraków sheet. This region
  // is drawn at a scale where a corridor carries many stops, and every stop wants
  // its name, while every corridor wants its line numbers and its terminus plate
  // — at Kraków's spacing (beadLen 0.55, max 6) the plates lost every collision
  // and never appeared on the export (user report). Stretching the diagram buys
  // the room back; it costs sheet area, which on an exported poster is free.
  // Doubled again on 8.08: stop-to-stop spacing was still tight enough that the
  // names crowded the corridors they belong to. Every length term is scaled by
  // the same factor so the diagram grows uniformly rather than changing shape —
  // the sheet gets bigger, which on an exported poster costs nothing.
  beadLen: 2.0, // extra grid units of target edge length per intermediate stop
  geoLenRefM: 150, // m mapping to one grid unit of length via sqrt — gives non-stop hops room
  edgeLenMin: 3.2, // grid units
  edgeLenMax: 22,
  majorShare: 0.12, // top share of stations by importance frozen hardest (w8)
  anchorSoft: 6, // units of geographic drift costing one w1 unit
  bearFullTrustM: 700, // m — below this the geographic bearing of a corridor is noise
  nodeMin: 4.4, // units — soft node-pair separation (1 grid cell is the hard floor)
  edgeClear: 0.75, // units — a node this close to a foreign corridor reads as a false interchange
  freeR: 2, // units a major node may drift before w8 starts charging
  octantSwitchPen: 0.18, // extra cost for settling into an octant other than the geographic one
  moveRadius: [4, 3, 3, 2, 2, 1, 1, 1], // candidate radius per round (last value repeats)
  cellSize: 3, // units — spatial-hash bucket for corridors and nodes
  bendCost: 1.5, // charged per bend when routing a corridor, so it stays straight when it can

  // ---------- the Vistula as a layout constraint ----------
  // OFF for Kraków (user decision 21.08.2026: the band looked terrible on this
  // sheet). The machinery stays — flip to true and re-run to get it back.
  river: false,
  riverClipM: 4000, // m from the nearest station — beyond that the river constrains nothing
  riverBinM: 500, // m per centerline bin when collapsing braided channels
  riverPoints: 14, // control points of the schematic river (bridges are added on top)
  riverBandM: 8, // grid units — stations within this band are checked when the river moves
  riverSmooth: 1.2, // cost of a river vertex deviating from a straight run of the band
  riverClearU: 0.9, // grid units — stations should not sit inside the band
  bridgeReachU: 2.5, // grid units — how far a crossing may sit from its bridge before it hurts
  regionMinR: 6, // grid units from the centre below which a compass sector is meaningless

  // cost weights, per the agreed specification
  weights: {
    // geographic_distortion: soft GPS anchor + graded bearing fidelity. Swept
    // against the diagram's own numbers (crossings / reversed bearings):
    //   0.25 → 97 crossings, 39 reversed, 133 strained  (the setting that
    //          produced the east-pointing Tor Kajakowy spur the user caught)
    // Re-swept after the scale fix, on crossings / reversed / strained:
    //   10 → 82 / 2 / 31    20 → 91 / 1 / 20    35 → 97 / 1 / 13
    // 20 still beats the original 101 crossings while cutting bad bearings
    // from 172 to 21 — the diagram may bend geography, not invert it.
    w1: 20,
    w2: 1.0, // edge_length_variation
    w3: 2.5, // angle_deviation from the octant nearest the true bearing
    w4: 9.0, // line_crossings (raised from 6 for the Warsaw sheet — fewer crossings, calmer picture)
    w5: 4.0, // node_overlap (node–node and node–foreign-edge)
    w6: 1.0, // label_overlap (coarse boxes)
    w7: 1.5, // unnecessary_bends along each line's path
    w8: 3.0, // displacement_of_major_nodes
    // Beyond the eight agreed terms: two corridors leaving one node on the same
    // heading merge into a single stroke on screen and their stops interleave
    // (the Kolna/Tor Kajakowy case). w5 does not catch it — that one guards
    // node-to-node and node-to-edge distance, not the angle between branches.
    // Off by default, and measured: pushing branches apart by the straight v→u
    // heading misses the point, because a bent corridor leaves the node along
    // its FIRST LEG, so it only trades crossings away (101 → 111…116 at w9 =
    // 1…6) for a handful of overlaps. The heading-reservation pass in
    // layout.mjs does the real work (254 → 223 overlaps at w9 = 0). Left as a
    // knob: `npm run schematic -- --w9=6`.
    w9: 0, // angular separation of the branches at a node

    // ---------- the Vistula constraint ----------
    w10: 60, // river_side_violation — a stop on the wrong bank is a lie about the city
    w11: 8, // bridge_displacement — bridges are anchors: they hold their place and their order
    w12: 12, // river_crossing_displacement — a line must cross the river AT its bridge
    w13: 3, // geographic_region_distortion — districts keep their compass sector around the centre
  },
  branchSepDeg: 45, // below this angle two branches at a node start being charged

  // NOTE: trams are ONE family-red corridor stroke like the printed KMK map
  // (user decision, 7.08) — no per-line strand colors.
};

// --key=value / --flag CLI overrides onto a deep copy of CONFIG
export function applyCliOverrides(config, argv) {
  // NOT a JSON round-trip of the whole config: that silently dropped every
  // feed FUNCTION (mapKey, groupOf, skipRoute) — depot runs and replacement
  // lines came back in and the station grouping fell through to the fallback.
  const { feeds, ...rest } = config;
  const cfg = JSON.parse(JSON.stringify(rest));
  cfg.feeds = feeds.map((f) => ({ ...f }));
  cfg.debug = false;
  for (const a of argv) {
    const m = a.match(/^--([\w-]+)(?:=(.*))?$/);
    if (!m) continue;
    const [, key, raw] = m;
    const val = raw === undefined ? true : (raw === '' || isNaN(Number(raw)) ? raw : Number(raw));
    if (/^w\d+$/.test(key)) cfg.weights[key] = val;
    else cfg[key] = val;
  }
  return cfg;
}
