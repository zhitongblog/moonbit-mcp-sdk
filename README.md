# moonbit-mcp-sdk

> **WASM-Native Model Context Protocol (MCP) Server & Client SDK for MoonBit**
> Built for **MoonBit 2026 Hackathon** & **WASM / JS / Native AI Agent Ecosystems**.

`moonbit-mcp-sdk` brings first-class **Model Context Protocol (JSON-RPC 2.0, `2024-11-05` & `2025-03-26`)** support to MoonBit with **zero third-party dependencies** (only `moonbitlang/core/json`), compiling cleanly to **WebAssembly (WASM)**, **JavaScript**, and **Native**.

## Key Features
- **Full MCP Protocol Lifecycle**: `initialize` (with `2024-11-05` / `2025-03-26` negotiation & server `instructions`), `notifications/initialized`, `ping`, JSON-RPC 2.0 Batch requests, `tools/list` (with cursor pagination), `tools/call`, `resources/list`, `resources/read`, `resources/templates/list`, `prompts/list`, `prompts/get`, and `logging/setLevel`.
- **Typed MCP Client Builders & Parser**: Build conformant `initialize`, `tools/call`, and paginated list requests, and decode JSON-RPC responses into `ClientResponse` (`Success` / `RpcError` / `ProtocolError`).
- **Deterministic Runtime Schema Validator**: Build JSON Schemas with `build_object_schema` and enforce required keys, primitive types, `enum`, `minLength`, and `maxLength` before any tool handler executes.
- **Built-in Action Gateway (Risk-Graded Safety)**:
  - Compile-time `RiskTier` (`ReadOnly` / `SafeWrite` / `Privileged`) with configurable risk ceiling (`Privileged` blocked by default).
  - Session-level `write_cap` circuit breaker with manual checkpoint reset (`reset_write_count`).
  - Dynamic per-tool runtime denylist (`deny_tool` / `allow_tool`), per-tool invocation counters (`get_tool_call_count`), and JSONL audit log export (`export_audit_jsonl`).
- **Dynamic URI Templates & Structured Logging**: Match `{param}` templates (`match_uri_template`) and filter severity thresholds (`LogLevel`, `should_emit_log`).
- **Host Transport Bridge**: Pure string-in / string-out router (`McpServer::handle_json`) plus a runnable Node.js stdio bridge example in `examples/node-stdio-bridge.mjs`.

## Quick Start

```bash
# Run all 19 blackbox conformance tests
moon test

# Run the live MCP JSON-RPC demo on WASM
moon run cmd/main

# Build WASM & JS targets
moon build --target wasm
moon build --target js
```

## Documentation
- Project Proposal: [PROPOSAL.md](./PROPOSAL.md)
- Node.js Stdio Bridge Example: [examples/node-stdio-bridge.mjs](./examples/node-stdio-bridge.mjs)

## License
Apache-2.0
