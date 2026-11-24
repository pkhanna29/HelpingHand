// HelpingHand data refresh worker.
// Pulls live crises from ReliefWeb + severity scores from ACAPS every 12 hours
// and writes them to Supabase. The iOS app reads crisis data and submits
// reports directly to Supabase, so this process no longer serves an API.
require('dotenv').config();
const cron = require('node-cron');
const axios = require('axios');
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws'); // WebSocket support for Node < 22

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

async function fetchAcapsSeverity() {
  if (!process.env.ACAPS_TOKEN) {
    console.warn('ACAPS_TOKEN not set; defaulting severity to 3');
    return [];
  }
  try {
    const res = await axios.get('https://api.acaps.org/api/v1/inform-severity-index/', {
      headers: { Authorization: `Token ${process.env.ACAPS_TOKEN}` }
    });
    return res.data.results || res.data || [];
  } catch (err) {
    console.error('Failed to fetch ACAPS data, defaulting severity to 3:', err.message);
    return [];
  }
}

async function fetchReliefWebDisasters() {
  // ReliefWeb blocks some default client user agents
  const res = await axios.get(
    `https://api.reliefweb.int/v2/reports?appname=${encodeURIComponent(process.env.RELIEFWEB_APPNAME || 'globalhand')}&profile=full&limit=10&sort[]=date:desc`,
    {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        Accept: 'application/json'
      }
    }
  );
  return res.data.data || [];
}

function severityFor(fields, acapsList) {
  const iso3 = fields.primary_country?.iso3?.toLowerCase();
  const country = fields.primary_country?.name?.toLowerCase();
  const match = acapsList.find(
    (item) => (iso3 && item.iso3?.toLowerCase() === iso3) || (country && item.country?.toLowerCase() === country)
  );
  const severity = Math.round(Number(match?.severity));
  return severity >= 1 && severity <= 5 ? severity : 3;
}

async function fetchRealEmergencyData() {
  try {
    console.log('Fetching live data from ReliefWeb and ACAPS...');
    const [acapsList, disasters] = await Promise.all([fetchAcapsSeverity(), fetchReliefWebDisasters()]);

    const rows = disasters.map(({ id, fields }) => ({
      region_id: String(id),
      name: fields.name || fields.title || 'Unnamed crisis',
      severity_level: severityFor(fields, acapsList),
      center_lat: fields.primary_country?.location?.lat ?? null,
      center_lng: fields.primary_country?.location?.lon ?? null,
      understand: {
        headline: fields.description ? fields.description.substring(0, 100) + '...' : 'Ongoing crisis operations.',
        bulletPoints: [
          `Crisis Type: ${fields.primary_type?.name || 'Unknown'}`,
          `Current Status: ${fields.status || 'Active'}`,
          `Primary Region: ${fields.primary_country?.name || 'Unknown'}`
        ],
        sourceUrls: [{ name: 'ReliefWeb (UN OCHA)', url: fields.url }]
      },
      last_updated: new Date().toISOString()
    }));

    if (rows.length === 0) {
      console.log('No disasters returned; nothing to update');
      return;
    }

    // Insert new crises, update existing ones (matched by region_id).
    // `act` is left out so hand-entered donation/volunteer info isn't overwritten.
    const { error } = await supabase.from('crisis_zones').upsert(rows, { onConflict: 'region_id' });
    if (error) throw error;
    console.log(`✓ Updated ${rows.length} crisis zones in Supabase`);
  } catch (err) {
    console.error('Failed to refresh emergency data:', err.message);
  }
}

if (process.argv.includes('--once')) {
  // `npm run refresh`: run a single refresh and exit
  fetchRealEmergencyData().then(() => process.exit(0));
} else {
  cron.schedule('0 */12 * * *', async () => {
    console.log('Running 12-hour automated humanitarian API refresh...');
    await fetchRealEmergencyData();
  });
  console.log('✓ HelpingHand refresh worker running (every 12 hours)');
  fetchRealEmergencyData();
}
