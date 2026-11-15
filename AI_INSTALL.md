# 从仓库地址安装并打开

本说明适用于用户已经给出本仓库地址，并明确要求“安装并打开”的情况。目标是用户本人的 Windows 10/11 x64 桌面会话。仅能访问云端终端或网页的助手，请直接给用户 README 中的双击安装步骤。手机聊天里的执行环境无法代替用户的 Windows 桌面。

1. 获取用户给出的仓库。优先用 Git 把该仓库的默认分支克隆到当前用户新建、可长期保留的文件夹；已有不同内容的同名目录请保留。没有 Git 时，使用**该仓库**的 Code → Download ZIP，或从该仓库的 Release 下载社区版 ZIP，然后完整解压。识别同时包含 README.md、setup.ps1、SHA256SUMS.txt 和 bin 的那一级目录。整个仓库已经包含可用入口，不依赖另一个下载站或手填仓库名。
2. 在该目录用普通用户权限运行下方命令。安装器先校验文件，自动检测商店版 Codex、准备资源、创建快捷方式并自检；成功后默认直接启动。使用助手本身提供的本机权限流程。若助手不能执行本地命令，告诉用户双击 **一键安装.bat**。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\setup.ps1"
```

3. 根据实际输出反馈给用户。

| 输出 | 含义与下一步 |
| --- | --- |
| `VERIFY_RESULT=OK`、`INSTALL_RESULT=OK` 和 `LAUNCH_RESULT=OK` | 安装文件校验完成，启动器已确认中文界面。新版使用内置菜单资源，未逐项检查所有菜单。告诉用户以后从桌面“Codex 中文启动”进入。 |
| `WAITING_FOR_CODEX_EXIT phase=launch` | 首次安装和自检已完成。请用户保存任务并从托盘完全退出 Codex；后台随后自动打开中文版。不要把等待退出报告成“已打开”。 |
| `WAITING_FOR_CODEX_EXIT phase=upgrade` | 已有本版安装，后台等待退出后执行升级、自检和启动。请用户保存任务、从托盘退出，保留本次解压目录。 |
| 安装完成后出现启动器错误 | 报告“已安装，启动或汉化未完成”，保留退出码。读启动日志，优先检查目标 Codex 是否完全退出、商店版本是否已更新；处理后用桌面快捷方式重试。 |
| 缺少商店应用、文件校验错误或兼容性检查失败 | 报告具体错误。缺少客户端时先安装并登录 Microsoft Store 版 Codex。校验不符时重新从同一仓库下载或解压。新版本兼容性错误请交给维护者。 |

在仍可操作桌面的外部助手里，可继续检查对应后台日志中的本次结果。首次安装等待打开时看 `%TEMP%\codex-zh-v17-open.log`；升级等待退出时看 `%TEMP%\codex-zh-v17-install.log`。启动器日志为 `%LOCALAPPDATA%\CodexZhLauncher\logs\launcher.log`。核对日志时间。Codex 自己代装时，退出会结束当前会话；后台进程负责后续工作。如果后台进程被系统或受管环境终止，首次安装后双击桌面 **Codex 中文启动**；待升级时双击 **一键安装.bat**。

只检查已安装的文件可运行下方命令。自检不会打开或关闭桌面应用。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\setup.ps1" -Action Verify
```
