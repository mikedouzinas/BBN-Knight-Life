#!/usr/bin/env node
/**
 * Entry point. Reads the config, connects over stdio, and stays out of the way.
 *
 * Config problems are reported to stderr and exit non-zero, because an MCP client shows
 * stderr when a server fails to start and shows nothing at all when it starts broken.
 */
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ConfigError, loadConfig } from './config.js';
import { KnightLifeClient } from './client.js';
import { createServer } from './server.js';

async function main(): Promise<void> {
  let config;
  try {
    config = loadConfig();
  } catch (error) {
    if (error instanceof ConfigError) {
      console.error(`knight-life-mcp: ${error.message}`);
      process.exit(1);
    }
    throw error;
  }

  const server = createServer(new KnightLifeClient(config));
  await server.connect(new StdioServerTransport());
  console.error(`knight-life-mcp: ready, pointing at ${config.baseUrl}`);
}

main().catch((error) => {
  console.error('knight-life-mcp: failed to start:', error);
  process.exit(1);
});
