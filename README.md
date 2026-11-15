# Codex 中文启动工具

为 Windows 商店版 Codex 启用简体中文界面、汉化原生菜单和内置插件卡片。社区版基于汉化工具包 v1.7，使用你电脑上已经安装的 Codex。项目由社区维护，与 OpenAI、Microsoft 无隶属或代言关系。

当前发行版 **v1.7-community.2**。2026-11-15 在 Windows x64 商店构建 **26.1111.2228.0** 完成隔离安装和真实客户端冷启动。登录页的中文按钮已通过控件检查。安装自检覆盖 8 个内置插件和 5 张技能卡片；登录后的工作区和全部菜单项仍需用户验证。[官方 Windows 更新清单](https://persistent.oaistatic.com/codex-app-prod/windows-store-update.json)

## 把项目发给智能体

复制本仓库首页地址，连同下面这句话发给**可以操作这台 Windows 电脑**的 Codex、豆包或其他助手。

> 你帮我把这个工具安装好并打开。请按这个 GitHub 仓库的 AI_INSTALL.md，在我的 Windows 电脑上安装、自检并启动中文版。如果需要退出当前 Codex，请提醒我保存工作。

安装入口为 [AI_INSTALL.md](AI_INSTALL.md)。助手需要能下载仓库文件并运行本地 PowerShell。只有网页聊天能力时，请用下面的双击方式。

## 自己安装

1. 使用 Windows 10/11 x64，先从 Microsoft Store 安装 Codex，打开并登录一次。
2. 在仓库首页选择 **Code → Download ZIP**，或下载维护者在 **Releases** 附上的完整 ZIP。将文件全部解压到一个准备保留的目录。
3. 双击 **一键安装.bat**。程序校验文件、准备中文资源、进行安装自检，然后打开中文版。以后双击桌面的 **Codex 中文启动**。
4. 若原 Codex 正在运行，安装器会显示 `WAITING_FOR_CODEX_EXIT`。请保存工作，**从系统托盘完全退出 Codex**。后台进程会接着安装并打开，最长等待两小时。等待期间保留解压目录，保持 Windows 已登录。

## 汉化范围

| 位置 | 效果 |
| --- | --- |
| 主界面 | 启动器启用客户端自带的 zh-CN 资源。翻译覆盖程度随客户端版本变化。 |
| Windows 原生菜单 | 检测到内置简体中文菜单目录时，交给客户端按中文启动参数加载。旧版使用原来的菜单翻译补丁。 |
| 插件市场 | 在当前用户目录创建官方内置插件的本地副本，更新已匹配卡片的名称、分类、介绍和示例。新插件按原样保留。 |
| 系统技能 | 为本机已有的图像生成、OpenAI 文档、代码审查、技能创建器和技能安装器更新可用的卡片字段。技能执行说明、脚本和图标沿用用户安装的版本。 |

旧 v1.7 将五套系统技能连同正文一起替换。本版只编辑已有的卡片字段，因此直接打开 `SKILL.md` 时仍可能看到英文。若本机还在使用旧 v1.7，建议先从托盘退出 Codex，使用**旧包**的卸载程序恢复其技能备份，然后运行本版。两个版本使用不同的工具目录和快捷方式；本版的卸载程序只管理本版记录的改动。

## 文件、更新和卸载

- 默认安装到当前用户的 `%USERPROFILE%\.codex\zh-community-v17`，已设置 `CODEX_HOME` 时使用该目录。内置插件来自本机商店安装，中文副本在工具目录的 `resources`。系统技能卡片在 `skills\.system\<名称>\agents\openai.yaml`，原件保存在工具目录的 `cards`。
- 商店更新导致安装路径变化时，中文版快捷方式会尝试调用上次保留的安装目录重新生成中文资源。若已移动或删除安装目录，完全退出客户端，再从本项目下载运行 **一键安装.bat**。工具重新读取本机插件。若报告缺少兼容标记，保留错误信息与 Codex 版本，供维护者核对。
- 卸载前退出 Codex，在解压目录双击 **卸载.bat**。工具移除本版资源和快捷方式，恢复仍与安装时一致的技能卡片。之后被用户或客户端修改过的卡片会保留现状。已保存的界面语言偏好可以在应用设置中调回。
- 安装过程中不需要管理员权限。新版使用本机回环调试端口读取可见控件，确认中文界面生效。旧版兼容路径另用主进程调试端口处理原生菜单。日志位于 `%LOCALAPPDATA%\CodexZhLauncher\logs\launcher.log`。

## 维护与发布

将**本目录中的文件**提交到 GitHub 仓库根目录，让浏览首页时能直接看到本 README。源码下载包自带 Windows 启动器，首次发布无需先创建 Release。保留 `.gitattributes`、许可证、`bin` 及 `SHA256SUMS.txt`，避免自动换行转换破坏校验。若通过 GitHub 网页上传，请核对这几个文件均已提交。

修改文件后，在 Windows PowerShell 中运行下面的命令重算校验清单，并在仓库外生成可直接作为 Release 附件的 ZIP。修改 C# 或启动脚本资源后，使用第二条重建二进制。编译依赖 Windows 自带的 64 位 .NET Framework C# 编译器和 WPF 程序集。

```powershell
.\package.ps1 -OutputDirectory ..\releases
.\package.ps1 -RebuildLauncher -OutputDirectory ..\releases
```

项目原创代码采用 [MIT](LICENSE)。启动器的上游、许可和本版修改见 [第三方声明](THIRD_PARTY_NOTICES.md)。工具依赖桌面客户端的内部机制，公开源码不表示 OpenAI 已授权这一运行方式。使用时请参阅 [OpenAI 使用条款](https://openai.com/policies/row-terms-of-use/)。
