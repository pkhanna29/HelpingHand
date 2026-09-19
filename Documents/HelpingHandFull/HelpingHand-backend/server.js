require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const cron = require('node-cron');
const CrisisZone = require('./models/CrisisZone');

const app = express();
app.use(cors());
app.use(express.json());

mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('✓ Connected to MongoDB'))
  .catch((err) => console.error('MongoDB connection error:', err));

app.get('/api/crises', async (req, res) => {
  try {
    const crises = await CrisisZone.find({}, 'regionId name severityLevel location center lastUpdated');
    res.json(crises);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve crisis zones' });
  }
});

app.get('/api/crises/:id', async (req, res) => {
  try {
    const crisis = await CrisisZone.findOne({ regionId: req.params.id });
    if (!crisis) return res.status(404).json({ error: 'Crisis zone not found' });
    res.json(crisis);
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve crisis details' });
  }
});

cron.schedule('0 */12 * * *', async () => {
  console.log('Running 12-hour automated humanitarian API refresh...');
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`✓ Global Hand backend running at http://localhost:${PORT}`);
});