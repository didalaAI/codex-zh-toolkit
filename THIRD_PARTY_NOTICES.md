# 来源与许可证

- 本项目沿用 v1.7 工具包的 Windows 安装流程、商店检测、文件复制回退和元数据处理代码。社区发行的安装、卸载、构建和中文卡片配置按根目录 LICENSE 提供。
- `launcher/` 基于 [shibaweidu/codex-desktop-zh](https://github.com/shibaweidu/codex-desktop-zh) 的 Windows 启动器。本地上游快照 82136f5，v1.7 对应 v0.7.7 系列，已包含对无控制台输出的修复。原版权声明与 MIT 许可证位于 [launcher/LICENSE](launcher/LICENSE)，上游声明见 [launcher/THIRD_PARTY_NOTICES.md](launcher/THIRD_PARTY_NOTICES.md)。`bin/` 的 EXE 由随附源码构建，本版将安装器识别的商店路径传给启动器，并识别新版内置中文菜单，按可见页面控件验证启动结果。源码中保留上游启动器自身的版本标识。
- 本发行包提供自主编写的中文卡片文案与启动器随附的菜单词表。Codex 客户端、商店资源、官方系统技能正文和图标由用户已有安装提供，各自权利归相应权利人。Codex、OpenAI、Microsoft 等名称用于说明兼容对象。
- 主界面与菜单功能使用本机调试端口、内部语言设置和 Electron 运行时接口。这个社区项目没有获得 OpenAI 对该运行方式的专门授权确认。[OpenAI 使用条款](https://openai.com/policies/row-terms-of-use/)
