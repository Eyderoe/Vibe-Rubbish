# 月历日程

macOS 桌面小组件：横向中尺寸（1×2），左侧月视图，右侧近期日程。

月历行高会按小组件实际高度调整，包括需要六周的月份；左右分栏按实际宽度分配。

## 构建与使用

1. 直接打开 `dist/MonthAgenda.app`。如需修改源码，可打开 `MonthAgenda.xcodeproj`，选择 `MonthAgenda` scheme 构建。
2. 在主 App 中依次点击「允许读取日历」和「允许读取提醒事项」。授予两项权限后，组件可同时显示日历事件和已安排日期的提醒事项。
3. 在桌面右键选择「编辑小组件」，搜索「月历日程」，添加中尺寸组件。之后可以关闭主 App，无需定时打开。

小组件扩展会自行读取日历和提醒事项，并向 WidgetKit 请求约一小时后重新获取数据；准确刷新时刻由 macOS 决定。主 App 中的「刷新日程」只是可选的手动刷新入口。未授权提醒事项时，组件会明确提示待办可能缺失。

## 项目结构

- `Shared/`：月历与日程视图、EventKit 数据读取。
- `MonthAgendaApp/`：权限入口与预览。
- `MonthAgendaWidget/`：WidgetKit 扩展。
- `project.yml`：XcodeGen 项目配置，可运行 `xcodegen generate` 重新生成项目。
