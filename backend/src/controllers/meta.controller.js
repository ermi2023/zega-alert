import { getCountryInfo } from '../services/geoapi.service.js';
import { ok } from '../utils/response.js';

// GET /api/meta/country?code=ET - reference facts from GeoAPI.info (cached
// server-side). Returns 200 with null when the upstream is unavailable so the
// client can degrade gracefully instead of showing an error.
export const country = async (req, res) => {
  ok(res, await getCountryInfo(req.query.code || 'ET'));
};
