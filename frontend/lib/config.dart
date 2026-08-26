const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/v1',
);

const userTimezone = String.fromEnvironment(
  'USER_TIMEZONE',
  defaultValue: 'America/Recife',
);
