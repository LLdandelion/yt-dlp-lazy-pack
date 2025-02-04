#!/bin/bash

# 初始化配置
FFMPEG_AVAILABLE=false
FIRST_RUN=true
DOWNLOAD_PATH="$PWD/Downloads"

# 创建下载目录
mkdir -p "$DOWNLOAD_PATH" && echo "[!] 已自动创建下载目录：$DOWNLOAD_PATH"

# 显示使用须知
echo "====================== 使用须知 ======================"
echo "1. 需要Python 3.7+环境"
echo "2. 需要能访问YouTube的网络环境"
echo "3. 会员视频需自行配置cookies"
echo "4. 文件将保存到：$DOWNLOAD_PATH"
echo "======================================================"

# 主循环
while true; do
    # 首次运行检查FFmpeg
    if $FIRST_RUN; then
        read -p "是否已安装FFmpeg并添加到PATH？(Y/N): " check_ffmpeg
        if [[ $check_ffmpeg =~ [Yy] ]]; then
            if command -v ffmpeg &>/dev/null; then
                FFMPEG_AVAILABLE=true
                echo "[✓] FFmpeg检查通过"
            else
                echo "[×] 未找到FFmpeg，部分功能受限"
            fi
        fi
        FIRST_RUN=false
    fi

    # 显示菜单
    echo ""
    echo "============== 主菜单 =============="
    echo "1. 通过pip安装yt-dlp"
    echo "2. 更新yt-dlp"
    echo "3. 下载单个视频"
    echo "4. 下载播放列表"
    echo "5. 安装FFmpeg（自动配置）"  # 新增选项
    echo "6. 退出脚本"
    echo "===================================="
    read -p "请输入选项数字: " choice

    case $choice in
        1)
            echo "正在安装yt-dlp..."
            python3 -m pip install yt-dlp
            if [ $? -ne 0 ]; then
                echo "[错误] 安装失败，请检查Python环境" >&2
            fi
            ;;
        2)
            echo "正在更新yt-dlp..."
            python3 -m pip install --upgrade yt-dlp
            ;;
        3)
            read -p "请输入视频URL（示例：https://youtu.be/abc123）: " url
            cmd="yt-dlp -f 'bestvideo+bestaudio' \"$url\" -o '%(title)s.%(ext)s' -P \"$DOWNLOAD_PATH\" --no-playlist"
            if $FFMPEG_AVAILABLE; then
                cmd+=" --merge-output-format mp4"
            fi
            echo "执行命令：$cmd"
            eval $cmd
            ;;
        4)
            read -p "请输入播放列表URL（示例：https://youtube.com/playlist?list=xyz456）: " url
            cmd="yt-dlp -f 'bestvideo+bestaudio' \"$url\" -o '%(title)s.%(ext)s' -P \"$DOWNLOAD_PATH\""
            if $FFMPEG_AVAILABLE; then
                cmd+=" --merge-output-format mp4"
            fi
            echo "执行命令：$cmd"
            eval $cmd
            ;;
        5)  # 新增FFmpeg安装逻辑
            echo "正在安装FFmpeg..."
            
            # 检查并安装Homebrew（如果未安装）
            if ! command -v brew &>/dev/null; then
                echo "未找到Homebrew，正在安装..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                # 将Homebrew添加到PATH（针对M1芯片和较新系统）
                if [[ -f /opt/homebrew/bin/brew ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            fi
            
            # 通过Homebrew安装FFmpeg
            brew install ffmpeg
            if [ $? -eq 0 ]; then
                FFMPEG_AVAILABLE=true
                echo "[✓] FFmpeg安装成功，功能已启用"
            else
                echo "[×] FFmpeg安装失败，请检查网络或权限" >&2
            fi
            ;;
        6)
            exit 0
            ;;
        *)
            echo "无效输入，请重新选择！" >&2
            ;;
    esac

    # 继续操作提示
    echo ""
    read -p "是否继续操作？(Y/N): " cont
    [[ ! $cont =~ [Yy] ]] && break
done