# Project Overview: Codex Session Insert

## 1. Summary
VS Code 扩展：通过编辑器/资源管理器右键菜单，一键生成 Codex 文件引用并自动粘贴到 Codex 对话输入框。支持两种引用样式，由设置 `codexSessionInsert.referenceStyle` 切换：
- 标准风格（默认）：Markdown 行号链接 `[相对路径 (line N)](/绝对路径:N)`，与新版 Codex 渲染出的行号链接格式一致，多文件逗号分隔
- 简化风格：`[@file]` / `[@file#行号]`，路径相对工作区根，多文件固定 separate 拼接

当前版本 0.1.5。技术栈为 TypeScript + VS Code Extension API，无运行时依赖，编译产物为 CommonJS。

## 2. Directory Map
- `src/extension.ts` - 唯一源码入口：命令注册、两种引用样式的引用构建、剪贴板与粘贴流程编排
- `scripts/build.sh` / `build.ps1` - 跨平台 VSIX 打包脚本（内部调用 vsce）
- `out/` - `tsc` 编译产物（`extension.js` + sourcemap），即 `package.json` 的 `main` 入口；被 `.gitignore` 忽略
- `package.json` - 扩展清单：命令/菜单/配置项声明、编译与打包脚本、VS Code 引擎版本
- `tsconfig.json` - TypeScript 编译配置（strict、CommonJS、ES2020）
- `.vscodeignore` - VSIX 打包排除规则（排除源码、tsconfig、node_modules 等）
- `README.md` - 使用说明与引用格式规范文档
- `meta.md` - 本文件：面向 LLM/AI 的项目索引
- `LICENSE` - MIT 协议
- `codex-session-insert-<version>.vsix` - 根目录下的打包产物（被 `.gitignore` 忽略，可随时重建）

## 3. Tech Stack & Standards
- **Core Tech**: TypeScript ^5.0.0；VS Code Extension API ^1.74.0；@vscode/vsce ^3.9.2（仅打包用）；无运行时依赖
- **Coding Rules**:
  - 开启 `strict` 严格模式；模块格式 CommonJS，目标 ES2020
  - 两种风格的标签/路径均经 `workspace.asRelativePath` 转为工作区相对路径；标准风格链接目标使用文件绝对路径（`uri.fsPath`）
  - 常量使用模块级 UPPER_SNAKE_CASE 命名；注释与 UI 文案使用中文
  - 业务逻辑集中在单一入口文件，不拆分模块
- **Commands**:
  - 安装依赖：`npm install`
  - 编译：`npm run compile`（`tsc -p ./`）
  - 监听编译：`npm run watch`
  - 打包 VSIX：`npx @vscode/vsce package`（或 `scripts/build.sh`）

## 4. Architecture & Data Flow
编辑器/资源管理器右键菜单 → `codexSessionInsert.insert` 命令 → 读取 `referenceStyle` 并按触发来源（编辑器选区 / 整文件 / 资源管理器多选）构建引用串 → 写入剪贴板（默认先备份原内容）→ 聚焦 Codex 输入框（`codex.chat.focusInput` 或 `chatgpt.openSidebar`，取第一个可用命令）→ 执行粘贴（`editor.action.clipboardPasteAction`）→ 延迟恢复剪贴板。全程为客户端命令编排，无后端、无持久化状态。

## 5. Key Interfaces & Models
- **命令** - `codexSessionInsert.insert`：唯一入口，注册于 `src/extension.ts`；`package.json` 声明编辑器/资源管理器右键菜单与 `onCommand` 激活事件
- **配置项**（定义于 `package.json`）:
  - `codexSessionInsert.referenceStyle`（`standard` / `simplified`，默认 `standard`）：引用样式
  - `codexSessionInsert.copyToClipboard`（boolean，默认 `false`）：插入时是否同时复制引用到剪贴板
- **引用格式模型**:

| 场景 | 标准风格 | 简化风格 |
| --- | --- | --- |
| 整文件 | `[src/foo.ts](/abs/path)` | `[@src/foo.ts]` |
| 单行 | `[src/foo.ts (line 10)](/abs/path:10)` | `[@src/foo.ts#10]` |
| 多行 | `[src/foo.ts (line 10-20)](/abs/path:10-20)` | `[@src/foo.ts#10-20]` |
| 多文件 | `[src/a.ts](/abs/a.ts), [src/b.ts](/abs/b.ts)` | `[@src/a.ts][@src/b.ts]` |

- **关键函数**:
  - `getReferenceStyle()` - 读取当前引用样式
  - `linkTarget()` - 标准风格链接目标（绝对路径，含空格/括号时用 `<>` 包裹）
  - `buildWholeFileReference()` / `buildReference()` / `buildMultiFileReference()` - 按样式构建整文件/选区/多文件引用
  - `selectionCoversWholeFile()` - 判断选区是否覆盖整个文件
  - `executeFirstAvailableCommand()` - 按序执行第一个可用的 VS Code 命令
