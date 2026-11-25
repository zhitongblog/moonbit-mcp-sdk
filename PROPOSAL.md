# `moonbit-mcp-sdk` 项目申报书

## 基本信息

- **项目名称**：`moonbit-mcp-sdk` — 面向 WASM / JS / Native 的 MoonBit 原生 Model Context Protocol (MCP) 服务端 SDK
- **参赛者**：李向东（GitHub ID：`zhitongblog`）
- **联系方式**：`<请填写你的国内邮箱 / 手机号>`
- **GitHub 仓库链接**：`https://github.com/zhitongblog/moonbit-mcp-sdk`
- **项目方向**：基础协议库 / AI Agent 基础设施 / 云原生 WASM 工具链
- **是否为移植项目**：否（基于 Model Context Protocol 官方开放协议规范的 MoonBit 原生设计实现）

---

## 项目简介

`moonbit-mcp-sdk` 计划为 MoonBit 生态构建一套**零第三方依赖、强类型、原生面向 WebAssembly（WASM）与多后端（JS / Native）**的 **Model Context Protocol（MCP）协议服务端与安全治理 SDK**，面向需要在 MoonBit 中构建 AI Agent 工具服务、边缘端 WASM Agent 插件、浏览器端沙箱工具与开发者基础设施的库作者和应用开发者。

随着 Claude Code、Cursor、Gemini CLI 等 AI 编码与桌面 Agent 全面采用 MCP 作为「AI 应用的 USB-C」统一工具协议，目前主流 MCP SDK 高度依赖庞大的 Node.js / Python 运行时，存在冷启动慢、内存占用高、沙箱隔离弱、缺乏原生风险分级与写操作熔断等痛点。将 MCP 协议栈以纯 MoonBit 原生实现并编译为轻量化 WASM / JS 模块，不仅能够充分发挥 MoonBit 极小二进制体积、强类型代数数据类型（ADT）与确定性执行的优势，还能在协议层直接引入工业级 Agent 安全护栏（**Action Gateway 风险分级 + Session Write-Cap 写操作上限 + JSON Schema 确定性入参校验 + JSONL 审计轨迹**），填补 MoonBit 在 AI Agent 核心协议生态中的基础空白，让所有 MoonBit 工具库只需几十行代码即可直接被全球主流 AI 客户端调用。

---

## 核心功能范围

- **完整 JSON-RPC 2.0 与 MCP（2024-11-05 / 2025-03-26）协议栈**：
  - 完整实现生命周期与能力协商：`initialize`、`notifications/initialized`、`ping`；
  - 完整实现三大核心能力：`tools/list`、`tools/call`、`resources/list`、`resources/read`、`prompts/list`、`prompts/get`（原生支持 MCP Skills 参数化配方）；
  - 支持标准 **JSON-RPC 2.0 Batch 批量请求** 与通知静默语义（无 `id` 或 `notifications/*` 不回包）；
  - 严格对齐标准错误码体系（`-32700 Parse error`、`-32600 Invalid Request`、`-32601 Method not found`、`-32602 Invalid params`、`-32002 Resource not found`）。
- **强类型 JSON Schema 构建器与确定性入参校验器（`schema.mbt`）**：
  - 提供声明式 `PropSpec` / `build_object_schema` DSL 构建标准 Tool `inputSchema`；
  - 在调用业务 Handler 之前执行确定性运行时校验（必填字段检查 + 声明类型检查），从源头拦阻 LLM 幻觉传参。
- **工业级 Agent 安全治理护栏（Action Gateway + Write-Cap + 审计轨迹）**：
  - 每个 Tool 在注册期显式声明 `RiskTier`（`ReadOnly` / `SafeWrite` / `Privileged`），并自动映射为 MCP `annotations`（`readOnlyHint` / `destructiveHint`）；
  - 服务端默认设置风险上限（拦阻 `Privileged` 高危工具），支持运行时策略升降级；
  - 内置 **Session Write-Cap** 写操作熔断器（限制单会话最大变更次数，经人工审批节点后通过 `reset_write_count()` 解锁）；
  - 全链路记录每次调用与拦截决策，提供 `export_audit_jsonl()` 导出可重放审计日志。
- **多后端与传输层适配（本赛季持续演进规划）**：
  - 核心路由层采用纯函数式 `handle_json(raw : String) -> String?` 无 I/O 耦合设计，无缝运行于 `wasm`、`js`、`native` 三端；
  - 后续迭代补充：完整 MCP 客户端协议解析器（Client SDK）、Resource URI Template 匹配、Tool Annotations 扩展、Cursor/Pagination 分页游标、Node.js / Cloudflare Workers WASM 宿主桥接示例与 stdio 守护进程示例。
- **完整接口规范、文档与测试矩阵**：
  - 提供 `moon info` 生成的清晰 `.mbti` 公共接口文件、双语 README 与可直接运行的 `cmd/main` 演示程序；
  - 提供覆盖协议全路径、边界异常、安全拦截、批量请求与与官方 MCP Inspector/参考规范对照的一致性黑盒测试套件（目标 30+ 测试用例及高覆盖率分析报告）。

---

## 预期验收产物

1. **`zhitongblog/moonbit-mcp-sdk` 开源库与 `mooncakes.io` 可复用包**：
   - 支持直接通过 `moon add zhitongblog/moonbit-mcp-sdk` 引入项目使用其完整 MCP Server / Schema / Action Gateway API；
   - 零外部第三方依赖、零编译警告（0 warnings, 0 errors），通过 `moon build --target wasm` 与 `moon build --target js` 双目标构建。
2. **完整协议一致性与安全边界黑盒测试套件**：
   - 通过 `moon test` 全量绿灯（当前已完成首批 12 项核心黑盒测试，验收前扩充至 30+ 项并附带 `moon coverage analyze` 覆盖率报告）；
   - 覆盖 JSON-RPC 2.0 规范边界、Schema 校验、Action Gateway 拦截、Write-Cap 熔断、Resource/Prompt 渲染及 Batch 调度。
3. **跨运行时可复现演示工程（Demo & Host Bridge）**：
   - 内置 `cmd/main` 可直接 `moon run cmd/main` 复现完整 MCP 会话与安全拦截；
   - 提供 WASM / JS 宿主加载运行示例，演示真实 AI 客户端（如 Claude Code / MCP Inspector）一键接入由 MoonBit 编译产出的 MCP Server。
4. **规范化开源工程文档**：
   - 完整双语 `README.md` / `README.mbt.md`、`.mbti` 接口说明、GitHub Issues/Commit 持续演进记录及 Apache-2.0 开源合规声明。

---

## 移植或参考说明

- **参考协议规范名称**：Model Context Protocol (MCP) Specification（`2024-11-05` / `2025-03-26`）& JSON-RPC 2.0 Specification
- **官方规范链接**：https://github.com/modelcontextprotocol/modelcontextprotocol
- **参考规范许可证**：MIT License
- **本项目开源许可证**：Apache License 2.0
