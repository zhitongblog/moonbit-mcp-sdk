# moonbit-mcp-sdk 项目申报书

## 1. 项目名称
`moonbit-mcp-sdk` —— 面向 WASM / JS / Native 的纯 MoonBit Model Context Protocol（MCP）开发套件

## 2. 项目简介
Model Context Protocol（MCP）已成为 Claude Code、Cursor、Windsurf 等 AI 编程与智能体工具接入外部能力的通用标准，但目前官方及主流 SDK 集中在 TypeScript 与 Python，依赖较重的宿主运行时，且默认缺少工具调用的安全隔离机制。本项目用纯 MoonBit 实现一套零第三方依赖的 MCP 服务端与客户端核心库，采用无状态字符串输入/输出路由，一次编写可编译为轻量化 WebAssembly、JavaScript 或 Native 产物，并在协议层内置工具参数校验、风险分级熔断与审计日志导出能力。

## 3. 项目方向与通用性说明
- **项目方向**：开发者工具 / AI Agent 基础设施 / WebAssembly 协议基础库。
- **通用性**：SDK 核心仅依赖 `moonbitlang/core/json`，不绑定具体传输层（stdio、SSE、HTTP、WASM 宿主函数桥接均可直接接入）。任何 MoonBit 开发者只需注册工具、资源或提示词回调函数，即可把现有算法库或业务能力接入所有兼容 MCP `2024-11-05` / `2025-03-26` 的 AI 客户端。

## 4. 预期使用场景（3 个完整场景）
1. **浏览器与边缘节点内的安全 AI 插件运行**：开发者将文本处理、数据解析或规则计算逻辑写成 MoonBit MCP Server 并编译为 `.wasm`（体积极小、冷启动毫秒级），在浏览器 Worker 或边缘函数里直接响应前端 AI 助手的工具调用。借助 WASM 沙箱与 SDK 内置的 `ReadOnly` 权限上限，无需部署后端即可安全执行本地工具。
2. **MoonBit 开源库一键暴露给 AI 编程助手**：现有 MoonBit 工具库（如解析器、格式校验器、静态分析器）通过 `register_tool` 与 `register_resource_template` 封装接口，配合项目自带的 Node.js stdio 桥接脚本，几分钟内即可接入 Claude Code 或 Cursor，让 AI 在编码时直接调用本地确定性校验工具而非靠模型猜测。
3. **企业内部敏感工具的分级熔断与审计**：研发或运维团队用本 SDK 封装内部查询、工单写入与高危脚本工具，分别为其标记 `ReadOnly`、`SafeWrite`、`Privileged` 风险等级，并配置会话写操作上限（`set_write_cap`）与动态黑名单（`deny_tool`）。AI 超限调用或越权操作会被协议层直接拦截，同时以 JSONL 格式记录完整审计流水供排查。

## 5. 拟实现的核心功能
- **完整 MCP 协议支持**：实现 JSON-RPC 2.0 单请求与批处理（Batch）、`initialize` 版本协商（`2024-11-05` / `2025-03-26`）与 `instructions` 下发、`ping`、`tools/list`（含游标分页）、`tools/call`、`resources/list`、`resources/read`、`resources/templates/list`、`prompts/list`、`prompts/get`、`logging/setLevel`。
- **类型安全客户端构建与解析**：提供请求构造器与响应解析器，支持 MoonBit 应用作为 MCP Client 发起调用及端到端回归测试。
- **确定性参数校验**：内置 JSON Schema 构建器与运行时校验器，在调用业务函数前检查必填字段、基础类型、`enum`、`minLength` 与 `maxLength`。
- **Action Gateway 安全治理**：支持三级风险上限、会话级写操作次数熔断、单工具动态拉黑/放行、调用频次统计及 JSONL 审计日志导出。
- **多目标产物与宿主桥接**：同步验证 WASM 与 JS 双目标编译输出，提供 Node.js stdio 桥接示例与完整黑盒测试套件。

## 6. 原创与参考说明
本项目为**原创 MoonBit 实现**，参照开放的 Model Context Protocol 协议规范独立设计与编码，未直接复制或翻译其他语言的 SDK 源码。

## 7. 参考协议与许可证
- **参考规范名称**：Model Context Protocol Specification（`2024-11-05` / `2025-03-26`）
- **来源链接**：https://github.com/modelcontextprotocol/modelcontextprotocol
- **规范许可证**：MIT License（本项目采用 Apache-2.0 License）

## 8. GitHub 仓库链接
- **仓库地址**：https://github.com/zhitongblog/moonbit-mcp-sdk
- **仓库状态**：公开仓库，包含 12 个按功能模块逐步演进的有效 commits、19 项黑盒协议一致性测试（全部通过）及 WASM / JS 双目标编译验证。
