function handler(event) {
  var response = event.response;
  var h = response.headers;

  h['strict-transport-security'] = { value: 'max-age=63072000; includeSubDomains; preload' };
  h['x-content-type-options']    = { value: 'nosniff' };
  h['x-frame-options']           = { value: 'DENY' };
  h['referrer-policy']           = { value: 'strict-origin-when-cross-origin' };
  h['permissions-policy']        = { value: 'camera=(), microphone=(), geolocation=()' };

  return response;
}
