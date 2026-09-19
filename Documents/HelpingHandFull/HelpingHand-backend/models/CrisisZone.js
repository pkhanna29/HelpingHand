const mongoose = require('mongoose');

const crisisZoneSchema = new mongoose.Schema({
  regionId: { type: String, required: true, unique: true },
  name: { type: String, required: true },
  severityLevel: { 
    type: Number, 
    required: true, 
    min: 1, 
    max: 5 
  },
  location: {
    type: { type: String, enum: ['Polygon'], default: 'Polygon' },
    coordinates: { type: [[[Number]]], required: true }
  },
  center: { latitude: Number, longitude: Number },
  understand: {
    headline: String,
    bulletPoints: [String],
    sourceUrls: [{ name: String, url: String }]
  },
  act: {
    donationUrl: String,
    verifiedOrg: String,
    suppliesNeeded: [String],
    volunteerOpportunities: [String]
  },
  lastUpdated: { type: Date, default: Date.now }
});

crisisZoneSchema.index({ location: '2dsphere' });
module.exports = mongoose.model('CrisisZone', crisisZoneSchema);