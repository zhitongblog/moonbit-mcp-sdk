# moonbit-mcp-sdk

> **WASM-Native Model Context Protocol (MCP) Server SDK for MoonBit**
> Built for **MoonBit 2026 Hackathon** & **WASM/AI Agent Ecosystems**.

`moonbit-mcp-sdk` brings first-class **Model Context Protocol (JSON-RPC 2.0)** support to MoonBit with **zero external third-party dependencies**, compiling cleanly to **WebAssembly (WASM)**, **JavaScript**, and **Native**.

## Key Features
- **Full MCP Server Lifecycle**: `initialize`, `notifications/initialized`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/read`, `prompts/list`, `prompts/get`.
- **Built-in Action Gateway (Risk-Graded Safety)**: Every registered tool declares a compile-time `RiskTier` (`ReadOnly` / `SafeWrite` / `Privileged`). The server enforces a configurable risk ceiling (blocking `Privileged` tools by default) and records every invocation into an inspectable `AuditEntry` trail.
- **Native MCP Skills (`prompts/*`)**: Register reusable parameterized agent skills directly inside your MCP server with required-argument validation.
- **Pure String-In / String-Out Router**: `McpServer::handle_json` works seamlessly across WASM edge workers, Node.js/Bun, browsers, and native stdio transports.

## Quick Start

```bash
# Run blackbox test suite
moon test

# Run the live MCP JSON-RPC demo on WASM
moon run cmd/main

# Build release WASM target
moon build --target wasm
```

## License
Apache-2.0
