# Codex Session Insert

右键菜单一键将代码引用复制并粘贴到 Codex 对话输入框。支持两种引用样式：标准风格（Codex 行号 Markdown 链接）与简化风格（`[@file]` / `[@file#行号]`），可通过设置切换。

## 使用

在编辑器中选中代码或停光标，右键 → **插入Codex**（按选区生成引用）；
或在资源管理器中右键文件/文件夹（支持多选），→ **插入Codex**（引用整个路径）。

## 引用格式

| 场景 | 标准风格（默认） | 简化风格 |
| --- | --- | --- |
| 无选区 | `[src/foo.ts](/abs/path/src/foo.ts)` | `[@src/foo.ts]` |
| 单行 | `[src/foo.ts (line 10)](/abs/path/src/foo.ts:10)` | `[@src/foo.ts#10]` |
| 多行 | `[src/foo.ts (line 10-20)](/abs/path/src/foo.ts:10-20)` | `[@src/foo.ts#10-20]` |
| 多文件 | `[src/a.ts](/abs/a.ts), [src/b.ts](/abs/b.ts)` | `[@src/a.ts][@src/b.ts]` |

两种风格的标签/路径均相对工作区根（`workspace.asRelativePath`），链接目标为文件绝对路径，行号后缀与 Codex 渲染出的标准格式一致。

## 设置

引用样式可通过设置 `codexSessionInsert.referenceStyle` 切换（设置 UI 中为下拉框）：

| 值 | 样式 |
| --- | --- |
| `standard`（默认） | 标准风格：Markdown 链接 + 行号，多文件逗号分隔 |
| `simplified` | 简化风格：`[@file]` / `[@file#行号]`，多文件固定 separate 样式 |

是否在插入 Codex 的同时把引用复制到剪贴板，可通过 `codexSessionInsert.copyToClipboard` 控制：

| 值 | 行为 |
| --- | --- |
| `false`（默认） | 只插入引用，不改变剪贴板内容 |
| `true` | 插入引用，并同时复制到剪贴板 |

## 打包为 VSIX

```bash
npm install
npm run compile
npx @vscode/vsce package
```

生成 `codex-session-insert-0.1.5.vsix` 文件，在 VS Code 扩展面板中通过「… → 从 VSIX 安装…」即可安装。

## License

MIT
