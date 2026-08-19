import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // The ingest route takes a base64 PDF or photo in the request body.
  experimental: { serverActions: { bodySizeLimit: '8mb' } },
};

export default nextConfig;
