import { getCountryInfo } from '../services/geoapi.service.js';
import { ok, fail } from '../utils/response.js';

// GET /api/meta/country?code=ET - reference facts from GeoAPI.info (cached
// server-side, which also avoids exposing the third party to the browser).
export const country = async (req, res) => {
  const info = await getCountryInfo(req.query.code || 'ET');
  if (!info) return fail(res, 'Country reference unavailable', 502);
  ok(res, info);
};
