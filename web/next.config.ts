import type { NextConfig } from 'next';
import { BASE_PATH } from './src/lib/basePath';

const nextConfig: NextConfig = {
  // The ingest route takes a base64 PDF or photo in the request body.
  experimental: { serverActions: { bodySizeLimit: '8mb' } },

  // This app is served at mikeveson.com/knight-life through a rewrite, so every asset URL it
  // emits has to already carry that prefix. Without this, the HTML arrives fine and every
  // stylesheet and script 404s against the portfolio, which looks like a broken deploy rather
  // than a routing mistake.
  //
  // Not read from the environment on purpose: if dev and production disagree about the base
  // path, the disagreement only shows up in production. Local dev runs at
  // http://localhost:3000/knight-life/admin, the same shape as the real address.
  //
  // Read from src/lib/basePath so the framework's prefix and the hand-written ones in the
  // layout are one value. They were two for about an hour, and the icon 404'd.
  basePath: BASE_PATH,
};

export default nextConfig;
