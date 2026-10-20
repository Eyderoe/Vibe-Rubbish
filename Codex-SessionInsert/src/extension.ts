import * as vscode from 'vscode';

const CODEX_DEFAULT_FOCUS_COMMANDS = ['codex.chat.focusInput', 'chatgpt.openSidebar'];
const CODEX_DEFAULT_PASTE_COMMAND = 'editor.action.clipboardPasteAction';
const DEFAULT_FOCUS_DELAY_MS = 80;
const RESTORE_CLIPBOARD_DELAY_MS = 150;

type ReferenceStyle = 'simplified' | 'standard';

async function executeFirstAvailableCommand(commandIds: string[]): Promise<boolean> {
  const commands = await vscode.commands.getCommands(true);
  const command = commandIds.find((commandId) => commands.includes(commandId));

  if (!command) {
    return false;
  }

  await vscode.commands.executeCommand(command);
  return true;
}

function selectionCoversWholeFile(editor: vscode.TextEditor): boolean {
  const selection = editor.selection;
  const lastLine = editor.document.lineAt(editor.document.lineCount - 1);
  const fileStart = new vscode.Position(0, 0);
  const fileEnd = lastLine.range.end;

  return selection.start.isEqual(fileStart) && selection.end.isEqual(fileEnd);
}

function linkTarget(uri: vscode.Uri, suffix = ''): string {
  const target = `${uri.fsPath}${suffix}`;
  // 路径含空格或括号时用尖括号包裹，保证 Markdown 链接可解析
  return /[\s()]/.test(target) ? `<${target}>` : target;
}

function getReferenceStyle(): ReferenceStyle {
  return vscode.workspace
    .getConfiguration('codexSessionInsert')
    .get<ReferenceStyle>('referenceStyle', 'standard');
}

function buildWholeFileReference(uri: vscode.Uri, style: ReferenceStyle): string {
  if (style === 'simplified') {
    // 简化风格：无选区引用整个文件 [@src/foo.ts]
    return `[@${vscode.workspace.asRelativePath(uri, false)}]`;
  }
  // 标准风格：无选区引用整个文件 [src/foo.ts](/abs/path/src/foo.ts)
  return `[${vscode.workspace.asRelativePath(uri, false)}](${linkTarget(uri)})`;
}

function buildReference(uri: vscode.Uri, selection: vscode.Selection, style: ReferenceStyle): string {
  if (selection.isEmpty) {
    return buildWholeFileReference(uri, style);
  }

  const startLine = selection.start.line + 1;
  const endLine = selection.end.line + 1;

  if (style === 'simplified') {
    const relativePath = vscode.workspace.asRelativePath(uri, false);
    if (startLine === endLine) {
      // 简化风格单行选区 [@src/foo.ts#10]
      return `[@${relativePath}#${startLine}]`;
    }
    // 简化风格多行选区 [@src/foo.ts#10-20]
    return `[@${relativePath}#${startLine}-${endLine}]`;
  }

  const label = vscode.workspace.asRelativePath(uri, false);
  if (startLine === endLine) {
    // 单行选区 [src/foo.ts (line 10)](/abs/path/src/foo.ts:10)
    return `[${label} (line ${startLine})](${linkTarget(uri, `:${startLine}`)})`;
  }

  // 多行选区 [src/foo.ts (line 10-20)](/abs/path/src/foo.ts:10-20)
  return `[${label} (line ${startLine}-${endLine})](${linkTarget(uri, `:${startLine}-${endLine}`)})`;
}

function buildMultiFileReference(uris: vscode.Uri[], style: ReferenceStyle): string {
  const references = uris.map((uri) => buildWholeFileReference(uri, style));

  if (style === 'simplified') {
    // 简化风格多文件固定 separate 样式 [@a][@b]
    return references.join('');
  }

  // 标准风格多文件逗号分隔 [a.ts](/abs/a.ts), [b.ts](/abs/b.ts)
  return references.join(', ');
}

export function activate(context: vscode.ExtensionContext): void {
  const disposable = vscode.commands.registerCommand(
    'codexSessionInsert.insert',
    async (uri?: vscode.Uri, selectedUris?: vscode.Uri[]) => {
      const editor = vscode.window.activeTextEditor;
      // 编辑器右键菜单会传入当前文档 URI，资源管理器右键会传入所选文件的 URI（多选时为数组）
      const isFromEditorContext = !!editor && !!uri && editor.document.uri.toString() === uri.toString();

      let reference: string;
      const referenceStyle = getReferenceStyle();

      if (isFromEditorContext) {
        // 编辑器内：按选区和引用样式生成引用
        reference = selectionCoversWholeFile(editor)
          ? buildWholeFileReference(uri, referenceStyle)
          : buildReference(uri, editor.selection, referenceStyle);
      } else if (selectedUris && selectedUris.length > 0) {
        // 资源管理器多选：按引用样式生成多文件引用
        reference = buildMultiFileReference(selectedUris, referenceStyle);
      } else if (uri) {
        // 资源管理器单选：引用整个文件/文件夹
        reference = buildWholeFileReference(uri, referenceStyle);
      } else if (editor) {
        reference = selectionCoversWholeFile(editor)
          ? buildWholeFileReference(editor.document.uri, referenceStyle)
          : buildReference(editor.document.uri, editor.selection, referenceStyle);
      } else {
        vscode.window.showWarningMessage('Codex Session Insert: Please open a file first');
        return;
      }

      const copyToClipboard = vscode.workspace
        .getConfiguration('codexSessionInsert')
        .get<boolean>('copyToClipboard', false);

      // 不复制到剪贴板时，先记住当前剪贴板内容，插入完成后恢复
      let previousClipboard: string | undefined;
      if (!copyToClipboard) {
        try {
          previousClipboard = await vscode.env.clipboard.readText();
        } catch {
          previousClipboard = undefined;
        }
      }

      await vscode.env.clipboard.writeText(reference);

      // 聚焦 Codex 输入框并粘贴 [label (line N)](/abs/path:N) 格式引用
      const didFocus = await executeFirstAvailableCommand(CODEX_DEFAULT_FOCUS_COMMANDS);

      if (!didFocus) {
        vscode.window.showWarningMessage(
          'Codex Session Insert: No available Codex focus command found. Please install the Codex VS Code extension.'
        );
        return;
      }

      await new Promise((resolve) => setTimeout(resolve, DEFAULT_FOCUS_DELAY_MS));

      try {
        await vscode.commands.executeCommand(CODEX_DEFAULT_PASTE_COMMAND);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        vscode.window.showWarningMessage(`Codex Session Insert: Paste failed: ${message}`);
      }

      if (previousClipboard !== undefined) {
        // 等 Codex 输入框完成粘贴后再恢复剪贴板，避免覆盖粘贴内容
        await new Promise((resolve) => setTimeout(resolve, RESTORE_CLIPBOARD_DELAY_MS));
        await vscode.env.clipboard.writeText(previousClipboard);
      }
    }
  );

  context.subscriptions.push(disposable);
}

export function deactivate(): void {}
