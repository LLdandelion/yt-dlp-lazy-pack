#!/bin/bash
# 文件名：launch.command
# 功能：在新终端窗口中启动主程序

# 获取脚本绝对路径
script_path="$(cd "$(dirname "$0")"; pwd)/yt-dlp-mac.sh"

# 在新终端窗口执行
osascript <<EOF
tell application "Terminal"
    activate
    do script "bash \\"$script_path\\""
end tell
EOF