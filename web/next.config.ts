import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // The ingest route takes a base64 PDF or photo in the request body.
  experimental: { serverActions: { bodySizeLimit: '8mb' } },

  // This app is served at mikeveson.com/knight-life through a rewrite, so every asset URL it
  // emits has to already carry that prefix. Without this, the HTML arrives fine and every
  // stylesheet and script 404s against the portfolio, which looks like a broken deploy rather
  // than a routing mistake.
  //
  // Hardcoded rather than read from the environment on purpose: if dev and production disagree
  // about the base path, the disagreement only shows up in production. Local dev runs at
  // http://localhost:3000/knight-life/admin, which is the same shape as the real address.
  basePath: '/knight-life',
};

export default nextConfig;
