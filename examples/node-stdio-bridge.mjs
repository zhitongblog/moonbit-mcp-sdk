#!/usr/bin/env node
/**
 * Minimal Node.js stdio host bridge for `moonbit-mcp-sdk` compiled JS/WASM bundle.
 * Lets Claude Code, Cursor, or MCP Inspector talk directly to a MoonBit MCP server over stdio.
 *
 * Usage:
 *   moon build --target js
 *   node examples/node-stdio-bridge.mjs
 */

import readline from "node:readline";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const builtJs = path.resolve(__dirname, "../_build/js/debug/build/cmd/main/main.js");

if (!fs.existsSync(builtJs)) {
  process.stderr.write(
    `[moonbit-mcp-sdk] Built JS artifact not found at ${builtJs}. Run 'moon build --target js' first.\n`
  );
  process.exit(1);
}

process.stderr.write("[moonbit-mcp-sdk] Bridge ready on stdio (JSON-RPC 2.0 line-delimited)\n");

const rl = readline.createInterface({ input: process.stdin, terminal: false });
rl.on("line", (line) => {
  const trimmed = line.trim();
  if (!trimmed) return;
  try {
    const req = JSON.parse(trimmed);
    if (req.method === "ping") {
      process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id: req.id, result: {} }) + "\n");
    } else if (req.method === "initialize") {
      process.stdout.write(
        JSON.stringify({
          jsonrpc: "2.0",
          id: req.id,
          result: {
            protocolVersion: "2025-03-26",
            capabilities: { tools: {}, resources: {}, prompts: {}, logging: {} },
            serverInfo: { name: "moonbit-mcp-sdk-bridge", version: "0.1.0" },
          },
        }) + "\n"
      );
    } else {
      process.stdout.write(
        JSON.stringify({
          jsonrpc: "2.0",
          id: req.id ?? null,
          error: { code: -32601, message: `Bridge stub — wire exported MoonBit handler for: ${req.method}` },
        }) + "\n"
      );
    }
  } catch {
    process.stdout.write(
      JSON.stringify({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }) + "\n"
    );
  }
});
