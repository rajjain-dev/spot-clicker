/**
 * Spot Clicker backend — Google Apps Script web app.
 *
 * The iPhone app POSTs JSON here. For each click this script:
 *   1. asks the Google Places API (New) for the places nearest the phone's location,
 *   2. asks Claude which one the person most likely meant, plus a category, tags and a note,
 *   3. writes one row to the "Spots" tab of the Google Sheet this script is bound to.
 *
 * Script properties (Project Settings > Script properties):
 *   PLACES_API_KEY     Google Cloud key with "Places API (New)" enabled
 *   ANTHROPIC_API_KEY  Claude API key
 *   SHARED_SECRET      any long random string; the app must send the same one
 *
 * Actions (field "action" in the POST body):
 *   ping    -> { ok }
 *   save    -> { ok, spot }    body: clientId, list ("Liked" | "Want to go"), lat, lng, accuracy, pressedAt
 *   list    -> { ok, spots }   newest first
 *   update  -> { ok, spot }    body: id, and list and/or placeId (one of the spot's alternatives)
 *   delete  -> { ok }          body: id
 */

const SHEET_NAME = 'Spots';
const HEADERS = [
  'id', 'clientId', 'createdAt', 'list', 'name', 'address', 'lat', 'lng',
  'category', 'tags', 'note', 'placeId', 'mapsUrl', 'alternatives',
  'pressLat', 'pressLng', 'accuracy'
];
const LISTS = ['Liked', 'Want to go'];
const CATEGORIES = [
  'Restaurant', 'Coffee', 'Bar', 'Thrift or Vintage', 'Bookstore',
  'Gallery or Museum', 'Park or View', 'Shop', 'Other'
];
const CLAUDE_MODEL = 'claude-haiku-5-5';
const SEARCH_RADIUS_M = 60;      // first try: places within 60 m of the phone
const WIDE_RADIUS_M = 150;       // fallback if nothing is that close
const MAX_CANDIDATES = 3;        // how many nearby places Claude chooses between

// Place types that are never what a walker means to save.
const IGNORED_TYPES = ['route', 'street_address', 'political', 'locality', 'neighborhood',
  'sublocality', 'administrative_area_level_1', 'administrative_area_level_2',
  'postal_code', 'premise', 'subpremise', 'intersection', 'transit_station',
  'bus_station', 'subway_station', 'parking', 'atm'];

// ---------------------------------------------------------------------------
// Web app entry points
// ---------------------------------------------------------------------------

function doGet() {
  return json_({ ok: true, service: 'Spot Clicker backend' });
}

function doPost(e) {
  try {
    const body = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    if (!body.secret || body.secret !== prop_('SHARED_SECRET')) {
      return json_({ ok: false, error: 'Wrong or missing secret' });
    }
    switch (body.action) {
      case 'ping':   return json_({ ok: true });
      case 'save':   return json_({ ok: true, spot: saveSpot_(body) });
      case 'list':   return json_({ ok: true, spots: listSpots_() });
      case 'update': return json_({ ok: true, spot: updateSpot_(body) });
      case 'delete': deleteSpot_(String(body.id)); return json_({ ok: true });
      default:       return json_({ ok: false, error: 'Unknown action: ' + body.action });
    }
  } catch (err) {
    console.error(err);
    return json_({ ok: false, error: String((err && err.message) || err) });
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function saveSpot_(b) {
  const lat = Number(b.lat);
  const lng = Number(b.lng);
  if (!isFinite(lat) || !isFinite(lng)) throw new Error('lat and lng are required');
  const list = LISTS.indexOf(b.list) >= 0 ? b.list : 'Liked';
  const clientId = String(b.clientId || Utilities.getUuid());

  // A retry from the app's offline queue: return the row we already saved.
  const existing = findRow_('clientId', clientId);
  if (existing) return rowToSpot_(existing.obj);

  let places = nearbyPlaces_(lat, lng, SEARCH_RADIUS_M);
  if (places.length === 0) places = nearbyPlaces_(lat, lng, WIDE_RADIUS_M);
  places = places.slice(0, MAX_CANDIDATES);

  let chosen = null;
  let info = { category: 'Other', tags: [], note: '' };
  if (places.length > 0) {
    const pick = classify_(places, lat, lng, list);
    chosen = places[pick.index];
    info = pick;
  }

  const row = {
    id: Utilities.getUuid(),
    clientId: clientId,
    createdAt: b.pressedAt ? new Date(b.pressedAt).toISOString() : new Date().toISOString(),
    list: list,
    name: chosen ? chosen.name : 'Unknown spot',
    address: chosen ? chosen.address : '',
    lat: chosen ? chosen.lat : lat,
    lng: chosen ? chosen.lng : lng,
    category: info.category,
    tags: info.tags.join(', '),
    note: info.note,
    placeId: chosen ? chosen.placeId : '',
    mapsUrl: chosen ? chosen.mapsUrl : mapsSearchUrl_(lat, lng, ''),
    alternatives: JSON.stringify(places.filter(function (p) { return p !== chosen; })),
    pressLat: lat,
    pressLng: lng,
    accuracy: Number(b.accuracy) || ''
  };

  withLock_(function () {
    // Check again inside the lock in case two retries raced each other.
    const again = findRow_('clientId', clientId);
    if (again) { row.id = again.obj.id; return; }
    sheet_().appendRow(HEADERS.map(function (h) { return row[h]; }));
  });
  const saved = findRow_('id', row.id);
  return rowToSpot_(saved ? saved.obj : row);
}

function listSpots_() {
  return rows_()
    .map(function (r) { return rowToSpot_(r.obj); })
    .sort(function (a, b) { return a.createdAt < b.createdAt ? 1 : -1; });
}

function updateSpot_(b) {
  const id = String(b.id || '');
  const found = findRow_('id', id);
  if (!found) throw new Error('Spot not found');
  const o = found.obj;

  if (b.list && LISTS.indexOf(b.list) >= 0) o.list = b.list;

  if (b.placeId && b.placeId !== o.placeId) {
    const alts = parseJson_(o.alternatives, []);
    const pick = alts.filter(function (p) { return p.placeId === b.placeId; })[0];
    if (!pick) throw new Error('That place is not one of this spot\'s alternatives');
    // The current place becomes an alternative, the picked one becomes the spot.
    const current = o.placeId ? {
      placeId: o.placeId, name: o.name, address: o.address, lat: Number(o.lat), lng: Number(o.lng),
      types: [], primaryType: '', mapsUrl: o.mapsUrl
    } : null;
    const rest = alts.filter(function (p) { return p.placeId !== b.placeId; });
    if (current) rest.unshift(current);

    const info = classify_([pick], Number(o.pressLat) || pick.lat, Number(o.pressLng) || pick.lng, o.list);
    o.name = pick.name;
    o.address = pick.address;
    o.lat = pick.lat;
    o.lng = pick.lng;
    o.placeId = pick.placeId;
    o.mapsUrl = pick.mapsUrl;
    o.category = info.category;
    o.tags = info.tags.join(', ');
    o.note = info.note;
    o.alternatives = JSON.stringify(rest);
  }

  withLock_(function () {
    const fresh = findRow_('id', id);
    if (!fresh) throw new Error('Spot was deleted');
    sheet_().getRange(fresh.rowNumber, 1, 1, HEADERS.length)
      .setValues([HEADERS.map(function (h) { return o[h] === undefined ? '' : o[h]; })]);
  });
  return rowToSpot_(o);
}

function deleteSpot_(id) {
  withLock_(function () {
    const found = findRow_('id', id);
    if (found) sheet_().deleteRow(found.rowNumber);
  });
}

// ---------------------------------------------------------------------------
// Google Places API (New): nearby search
// ---------------------------------------------------------------------------

function nearbyPlaces_(lat, lng, radius) {
  const res = UrlFetchApp.fetch('https://places.googleapis.com/v1/places:searchNearby', {
    method: 'post',
    contentType: 'application/json',
    muteHttpExceptions: true,
    headers: {
      'X-Goog-Api-Key': prop_('PLACES_API_KEY'),
      'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,' +
        'places.location,places.types,places.primaryType,places.googleMapsUri'
    },
    payload: JSON.stringify({
      maxResultCount: 10,
      rankPreference: 'DISTANCE',
      locationRestriction: { circle: { center: { latitude: lat, longitude: lng }, radius: radius } }
    })
  });
  if (res.getResponseCode() !== 200) {
    throw new Error('Places API error ' + res.getResponseCode() + ': ' + res.getContentText().slice(0, 300));
  }
  const data = JSON.parse(res.getContentText() || '{}');
  return (data.places || [])
    .filter(function (p) {
      const types = p.types || [];
      return !types.some(function (t) { return IGNORED_TYPES.indexOf(t) >= 0; });
    })
    .map(function (p) {
      const pLat = p.location ? p.location.latitude : lat;
      const pLng = p.location ? p.location.longitude : lng;
      const name = (p.displayName && p.displayName.text) || 'Unnamed place';
      return {
        placeId: p.id,
        name: name,
        address: p.formattedAddress || '',
        lat: pLat,
        lng: pLng,
        types: p.types || [],
        primaryType: p.primaryType || '',
        mapsUrl: p.googleMapsUri || mapsSearchUrl_(pLat, pLng, p.id)
      };
    });
}

// ---------------------------------------------------------------------------
// Claude: pick the place and categorize it
// ---------------------------------------------------------------------------

function classify_(places, lat, lng, list) {
  const fallback = { index: 0, category: guessCategory_(places[0]), tags: [], note: '' };
  const key = PropertiesService.getScriptProperties().getProperty('ANTHROPIC_API_KEY');
  if (!key) return fallback;

  const lines = places.map(function (p, i) {
    const d = Math.round(distanceM_(lat, lng, p.lat, p.lng));
    return i + ') ' + p.name + ' | types: ' + (p.types.slice(0, 5).join(', ') || 'unknown') +
      ' | ' + p.address + ' | ' + d + ' m away';
  }).join('\n');

  const prompt =
    'Someone walking through a city pressed a button on their keychain to save a place they just walked past. ' +
    'They saved it to their "' + list + '" list. Nearby places, closest first:\n' + lines + '\n\n' +
    'Pick the place they most likely meant. Prefer places a pedestrian would notice from the sidewalk ' +
    '(restaurants, cafes, bars, shops, galleries, parks) over offices, banks, gyms or services, ' +
    'and prefer closer places when it is a toss-up.\n' +
    'Then give:\n' +
    '- category: exactly one of ' + CATEGORIES.join(', ') + '\n' +
    '- tags: 2 to 4 short lowercase tags (for example "cheap eats", "date night", "vintage denim")\n' +
    '- note: one short sentence on why it might be worth a visit, based only on its name and type. Do not invent facts.\n' +
    'Reply with only JSON, no other text: {"index": 0, "category": "...", "tags": ["..."], "note": "..."}';

  try {
    const res = UrlFetchApp.fetch('https://api.anthropic.com/v1/messages', {
      method: 'post',
      contentType: 'application/json',
      muteHttpExceptions: true,
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01' },
      payload: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 300,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    if (res.getResponseCode() !== 200) {
      console.warn('Claude error ' + res.getResponseCode() + ': ' + res.getContentText().slice(0, 300));
      return fallback;
    }
    const data = JSON.parse(res.getContentText());
    const text = (data.content || []).map(function (c) { return c.text || ''; }).join('');
    const match = text.match(/\{[\s\S]*\}/);
    if (!match) return fallback;
    const out = JSON.parse(match[0]);

    let index = parseInt(out.index, 10);
    if (!(index >= 0 && index < places.length)) index = 0;
    const category = CATEGORIES.indexOf(out.category) >= 0 ? out.category : guessCategory_(places[index]);
    const tags = (Array.isArray(out.tags) ? out.tags : [])
      .map(function (t) { return String(t).toLowerCase().replace(/,/g, ' ').trim(); })
      .filter(function (t) { return t; })
      .slice(0, 4);
    const note = String(out.note || '').slice(0, 200);
    return { index: index, category: category, tags: tags, note: note };
  } catch (err) {
    console.warn('Claude call failed: ' + err);
    return fallback;
  }
}

/** Category from Google's place types, used when Claude is unavailable. */
function guessCategory_(place) {
  const t = (place && place.types) || [];
  const has = function (list) { return t.some(function (x) { return list.indexOf(x) >= 0; }); };
  if (has(['cafe', 'coffee_shop', 'tea_house'])) return 'Coffee';
  if (has(['bar', 'night_club', 'pub', 'wine_bar', 'cocktail_bar'])) return 'Bar';
  if (has(['book_store'])) return 'Bookstore';
  if (has(['art_gallery', 'museum'])) return 'Gallery or Museum';
  if (has(['park', 'tourist_attraction', 'scenic_spot', 'garden'])) return 'Park or View';
  if (has(['restaurant', 'food', 'bakery', 'meal_takeaway', 'pizza_restaurant', 'fast_food_restaurant'])) return 'Restaurant';
  if (has(['clothing_store', 'store', 'shopping_mall', 'shoe_store', 'jewelry_store', 'gift_shop'])) return 'Shop';
  return 'Other';
}

// ---------------------------------------------------------------------------
// Sheet helpers
// ---------------------------------------------------------------------------

function sheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(SHEET_NAME);
  if (!sh) {
    sh = ss.insertSheet(SHEET_NAME);
    sh.appendRow(HEADERS);
    sh.setFrozenRows(1);
  }
  return sh;
}

function rows_() {
  const values = sheet_().getDataRange().getValues();
  if (values.length < 2) return [];
  const head = values[0];
  return values.slice(1).map(function (r, i) {
    const obj = {};
    head.forEach(function (h, j) { obj[h] = r[j]; });
    return { rowNumber: i + 2, obj: obj };
  });
}

function findRow_(field, value) {
  if (!value) return null;
  const all = rows_();
  for (let i = 0; i < all.length; i++) {
    if (String(all[i].obj[field]) === String(value)) return all[i];
  }
  return null;
}

function rowToSpot_(o) {
  const created = o.createdAt instanceof Date ? o.createdAt : new Date(o.createdAt);
  return {
    id: String(o.id),
    createdAt: isNaN(created.getTime()) ? new Date().toISOString() : created.toISOString(),
    list: LISTS.indexOf(o.list) >= 0 ? o.list : 'Liked',
    name: String(o.name || 'Unknown spot'),
    address: String(o.address || ''),
    lat: Number(o.lat),
    lng: Number(o.lng),
    category: CATEGORIES.indexOf(o.category) >= 0 ? o.category : 'Other',
    tags: String(o.tags || '').split(',').map(function (t) { return t.trim(); }).filter(function (t) { return t; }),
    note: String(o.note || ''),
    placeId: String(o.placeId || ''),
    mapsUrl: String(o.mapsUrl || mapsSearchUrl_(Number(o.lat), Number(o.lng), o.placeId)),
    alternatives: parseJson_(o.alternatives, []).map(function (p) {
      return {
        placeId: String(p.placeId), name: String(p.name), address: String(p.address || ''),
        lat: Number(p.lat), lng: Number(p.lng), mapsUrl: String(p.mapsUrl || ''), types: p.types || []
      };
    })
  };
}

// ---------------------------------------------------------------------------
// Small utilities
// ---------------------------------------------------------------------------

function prop_(name) {
  const v = PropertiesService.getScriptProperties().getProperty(name);
  if (!v) throw new Error('Missing script property ' + name);
  return v;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function withLock_(fn) {
  const lock = LockService.getScriptLock();
  lock.waitLock(20000);
  try { return fn(); } finally { lock.releaseLock(); }
}

function parseJson_(s, fallback) {
  if (!s) return fallback;
  try { return JSON.parse(s); } catch (e) { return fallback; }
}

function mapsSearchUrl_(lat, lng, placeId) {
  let url = 'https://www.google.com/maps/search/?api=1&query=' + lat + ',' + lng;
  if (placeId) url += '&query_place_id=' + encodeURIComponent(placeId);
  return url;
}

function distanceM_(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = function (d) { return d * Math.PI / 180; };
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * R * Math.asin(Math.sqrt(a));
}

// ---------------------------------------------------------------------------
// Run these from the Apps Script editor
// ---------------------------------------------------------------------------

/** Creates the Spots tab with its header row. */
function setup() {
  sheet_();
}

/** Saves a test spot outside Housing Works Bookstore Cafe in SoHo and logs the result. */
function testSave() {
  const spot = saveSpot_({ clientId: 'test-' + Date.now(), list: 'Want to go', lat: 40.72467, lng: -73.99727, accuracy: 10 });
  console.log(JSON.stringify(spot, null, 2));
}
