/**
 * Where this server points and who it acts as.
 *
 * Two values, both from the environment, because an MCP server is configured by a JSON
 * file the user edits by hand and every extra field is a chance to get it wrong.
 */

export interface Config {
  /** Base URL of the deployed admin tool, no trailing slash. */
  baseUrl: string;
  /** A Firebase refresh token belonging to a Knight Life admin. */
  refreshToken: string;
  /** The project's public web API key. Needed to trade a refresh token for an ID token. */
  webApiKey: string;
}

const DEFAULT_BASE_URL = 'https://mikeveson.com/knight-life';

/**
 * The Firebase Web API key for bbn-daily. Not a secret: it ships inside every copy of the
 * iOS app and every page of the web tool. It names the project; it grants nothing. Access
 * is decided by the Firestore rules and the `admins` collection.
 */
const DEFAULT_WEB_API_KEY = 'AIzaSyA9pHC7kuzpjY8J8d_B48p073jabftSqkY';

export class ConfigError extends Error {}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const refreshToken = (env.KNIGHT_LIFE_REFRESH_TOKEN ?? '').trim();
  if (!refreshToken) {
    throw new ConfigError(
      'KNIGHT_LIFE_REFRESH_TOKEN is not set. Sign in at the admin tool, open "Link an agent", ' +
        'and copy the token it shows into this server\'s env.',
    );
  }
  return {
    baseUrl: (env.KNIGHT_LIFE_URL ?? DEFAULT_BASE_URL).trim().replace(/\/+$/, ''),
    refreshToken,
    webApiKey: (env.KNIGHT_LIFE_WEB_API_KEY ?? DEFAULT_WEB_API_KEY).trim(),
  };
}
