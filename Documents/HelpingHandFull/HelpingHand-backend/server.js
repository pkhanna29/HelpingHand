// HelpingHand data refresh worker.
// Every 12 hours, pulls humanitarian crisis data and writes it to Supabase.
// The iOS app reads crisis data and submits reports directly to Supabase,
// so this process doesn't serve an API.
//
// Sources:
//   UNHCR     - refugees & displaced people per country (wars, persecution). Always on, no key.
//   ReliefWeb - ongoing crises incl. conflicts. Only runs when RELIEFWEB_APPNAME is set
//               (needs an approved appname); severity comes from ACAPS.
//   TODO: make ACAPS the main crisis list once the ACAPS token is replaced.
require('dotenv').config();
const cron = require('node-cron');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws'); // WebSocket support for Node < 22
const COUNTRIES = require('./data/country-centroids.json'); // ISO3 -> { name, lat, lng }

for (const key of ['SUPABASE_URL', 'SUPABASE_SECRET_KEY']) {
  if (!process.env[key]) {
    console.error(`Missing ${key} in .env`);
    process.exit(1);
  }
}

// The secret key bypasses Row Level Security. Never ship it in the iOS app.
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
  realtime: { transport: ws }
});

const http = axios.create({ timeout: 30000, headers: { Accept: 'application/json' } });

// ---------------------------------------------------------------------------
// UNHCR: displacement crises by country of origin
// ---------------------------------------------------------------------------
const UNHCR_MIN_DISPLACED = 500000; // countries with fewer displaced people are left off the map

const toNumber = (v) => (/^\d+$/.test(String(v)) ? Number(v) : 0); // API uses "-" and "0" strings
const formatCount = (n) =>
  n >= 1e6 ? `${(n / 1e6).toFixed(1).replace(/\.0$/, '')} million` : n.toLocaleString('en-US');

// Placeholder severity from scale of displacement, until ACAPS severity is wired in
function displacementSeverity(total) {
  if (total >= 8e6) return 5;
  if (total >= 3e6) return 4;
  if (total >= 1e6) return 3;
  return 2;
}

async function fetchUnhcrYear(year) {
  const items = [];
  for (let page = 1, maxPages = 1; page <= maxPages; page++) {
    const res = await http.get('https://api.unhcr.org/population/v1/population/', {
      params: { year, coo_all: true, limit: 400, page }
    });
    maxPages = res.data.maxPages || 1;
    items.push(...(res.data.items || []));
  }
  return items;
}

async function fetchUnhcrCrises() {
  // Use the newest year UNHCR has published (current year is mid-year data when available)
  const thisYear = new Date().getUTCFullYear();
  let items = [];
  let year;
  for (year = thisYear; year >= thisYear - 3; year--) {
    items = await fetchUnhcrYear(year);
    if (items.length >= 150) break;
  }
  if (items.length < 150) throw new Error('UNHCR returned no complete year of data');

  const rows = [];
  for (const item of items) {
    const iso3 = item.coo_iso;
    const country = COUNTRIES[iso3];
    if (!country) continue; // e.g. "Unknown" origin

    const refugees = toNumber(item.refugees);
    const asylumSeekers = toNumber(item.asylum_seekers);
    const idps = toNumber(item.idps);
    const otherInNeed = toNumber(item.oip);
    const total = refugees + asylumSeekers + idps + otherInNeed;
    if (total < UNHCR_MIN_DISPLACED) continue;

    const bulletPoints = [
      `Refugees who fled abroad: ${formatCount(refugees)}`,
      `Displaced inside ${country.name}: ${formatCount(idps)}`,
      `Asylum seekers: ${formatCount(asylumSeekers)}`
    ];
    if (otherInNeed > 0) bulletPoints.push(`Others in need of international protection: ${formatCount(otherInNeed)}`);
    bulletPoints.push(`Figures: UNHCR, ${year}`);

    rows.push({
      region_id: `unhcr-${iso3}`,
      name: `${country.name} displacement crisis`,
      severity_level: displacementSeverity(total),
      center_lat: country.lat,
      center_lng: country.lng,
      understand: {
        headline: `${formatCount(total)} people from ${country.name} have been forced from their homes.`,
        bulletPoints,
        displacement: { year, refugees, asylumSeekers, idps, otherInNeed, total },
        sourceUrls: [{ name: 'UNHCR Refugee Data Finder', url: 'https://www.unhcr.org/refugee-statistics/' }]
      }
    });
  }
  console.log(`UNHCR ${year}: ${rows.length} countries with ${formatCount(UNHCR_MIN_DISPLACED)}+ displaced`);
  return rows;
}

// ---------------------------------------------------------------------------
// ReliefWeb (+ ACAPS severity): ongoing crises. Disabled until RELIEFWEB_APPNAME is set.
// Untested: written against ReliefWeb's v2 API docs; check output once an appname is approved.
// ---------------------------------------------------------------------------
async function fetchAcapsSeverity() {
  if (!process.env.ACAPS_TOKEN) return [];
  try {
    const res = await http.get('https://api.acaps.org/api/v1/inform-severity-index/', {
      headers: { Authorization: `Token ${process.env.ACAPS_TOKEN}` }
    });
    return res.data.results || res.data || [];
  } catch (err) {
    console.error('ACAPS fetch failed, defaulting severity to 3:', err.message);
    return [];
  }
}

function acapsSeverityFor(country, acapsList) {
  const iso3 = country?.iso3?.toLowerCase();
  const name = country?.name?.toLowerCase();
  const match = acapsList.find(
    (item) => (iso3 && item.iso3?.toLowerCase() === iso3) || (name && item.country?.toLowerCase() === name)
  );
  const severity = Math.round(Number(match?.severity));
  return severity >= 1 && severity <= 5 ? severity : 3;
}

async function fetchReliefWebCrises() {
  const [acapsList, res] = await Promise.all([
    fetchAcapsSeverity(),
    // "disasters" in ReliefWeb includes conflicts (type "Complex Emergency")
    http.post(
      `https://api.reliefweb.int/v2/disasters?appname=${encodeURIComponent(process.env.RELIEFWEB_APPNAME)}`,
      {
        profile: 'full',
        limit: 100,
        filter: { field: 'status', value: ['alert', 'ongoing'] },
        sort: ['date.created:desc']
      }
    )
  ]);

  return (res.data.data || []).map(({ id, fields }) => ({
    region_id: `reliefweb-${id}`,
    name: fields.name || 'Unnamed crisis',
    severity_level: acapsSeverityFor(fields.primary_country, acapsList),
    center_lat: fields.primary_country?.location?.lat ?? null,
    center_lng: fields.primary_country?.location?.lon ?? null,
    understand: {
      headline: fields.description ? fields.description.substring(0, 140).trim() + '...' : 'Ongoing crisis.',
      bulletPoints: [
        `Crisis type: ${(fields.type || []).map((t) => t.name).join(', ') || fields.primary_type?.name || 'Unknown'}`,
        `Status: ${fields.status || 'ongoing'}`,
        `Country: ${fields.primary_country?.name || 'Unknown'}`
      ],
      sourceUrls: [{ name: 'ReliefWeb (UN OCHA)', url: fields.url }]
    }
  }));
}

// ---------------------------------------------------------------------------
// Refresh
// ---------------------------------------------------------------------------
const SOURCES = [
  { prefix: 'unhcr', label: 'UNHCR', fetch: fetchUnhcrCrises, enabled: () => true },
  {
    prefix: 'reliefweb',
    label: 'ReliefWeb',
    fetch: fetchReliefWebCrises,
    enabled: () => Boolean(process.env.RELIEFWEB_APPNAME)
  }
];

async function refreshSource(source) {
  if (!source.enabled()) {
    console.log(`- ${source.label}: skipped (not configured)`);
    return;
  }
  const runStartedAt = new Date().toISOString();
  try {
    const rows = (await source.fetch()).map((row) => ({ ...row, last_updated: new Date().toISOString() }));
    if (rows.length === 0) {
      console.log(`- ${source.label}: no crises returned; leaving existing data alone`);
      return;
    }

    // Insert new crises, update existing ones (matched by region_id).
    // `act` is left out so hand-entered donation/volunteer info isn't overwritten.
    const { error } = await supabase.from('crisis_zones').upsert(rows, { onConflict: 'region_id' });
    if (error) throw error;

    // Remove this source's crises that no longer appear (e.g. a crisis that ended)
    const { error: cleanupError, count } = await supabase
      .from('crisis_zones')
      .delete({ count: 'exact' })
      .like('region_id', `${source.prefix}-%`)
      .lt('last_updated', runStartedAt);
    if (cleanupError) throw cleanupError;

    console.log(`✓ ${source.label}: ${rows.length} crises saved${count ? `, ${count} outdated removed` : ''}`);
  } catch (err) {
    // One source failing shouldn't stop the others
    console.error(`✗ ${source.label} refresh failed:`, err.message);
  }
}

async function refreshAll() {
  console.log(`Refreshing crisis data (${new Date().toISOString()})...`);
  for (const source of SOURCES) await refreshSource(source);
}

if (process.argv.includes('--once')) {
  // `npm run refresh`: run a single refresh and exit
  refreshAll().then(() => process.exit(0));
} else {
  cron.schedule('0 */12 * * *', refreshAll);
  console.log('✓ HelpingHand refresh worker running (every 12 hours)');
  refreshAll();
}
