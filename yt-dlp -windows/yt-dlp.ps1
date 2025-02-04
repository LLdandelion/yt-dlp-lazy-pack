<#
YouTube视频下载脚本（相对路径版）
功能：安装/更新yt-dlp、下载单个视频、下载播放列表
#>

Write-Host "====================== 使用须知 ======================"
Write-Host "1. 需要Python 3.7+运行环境"
Write-Host "2. 需要能访问YouTube的网络环境"
Write-Host "3. 下载会员内容需要自行修改脚本添加cookies"
Write-Host "4. 文件将保存到当前目录的Downloads文件夹"
Write-Host "===================================================`n"

# 初始化环境变量
$ffmpegAvailable = $false
$firstRun = $true
$downloadPath = Join-Path (Get-Location) "Downloads"

# 自动创建下载目录
if (-not (Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    Write-Host "[!] 已自动创建下载目录：$downloadPath"
}

while ($true) {
    # 首次运行检查ffmpeg
    if ($firstRun) {
        $checkFFmpeg = Read-Host "是否已安装FFmpeg并添加到系统PATH？(Y/N)"
        if ($checkFFmpeg -in @('Y','y')) {
            try {
                Get-Command ffmpeg -ErrorAction Stop | Out-Null
                $ffmpegAvailable = $true
                Write-Host "[√] FFmpeg检测通过"
            } catch {
                Write-Host "[×] 未找到FFmpeg，部分功能可能受限"
            }
        }
        $firstRun = $false
    }

    # 显示主菜单
    Write-Host "`n============= 主菜单 ============="
    Write-Host "1. 通过pip安装yt-dlp"
    Write-Host "2. 更新yt-dlp"
    Write-Host "3. 下载单个视频（保存到：$downloadPath）"
    Write-Host "4. 下载播放列表（保存到：$downloadPath）"
    Write-Host "5. 退出脚本"
    Write-Host "=================================`n"

    $choice = Read-Host "请输入选项数字"
    
    switch ($choice) {
        '1' {
            Write-Host "开始安装yt-dlp..."
            python -m pip install yt-dlp
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 安装失败，请检查Python环境" -ForegroundColor Red
            }
        }
        
        '2' {
            Write-Host "检查更新..."
            python -m pip install --upgrade yt-dlp
        }
        
        '3' {
            $url = Read-Host "输入视频URL（https://www.youtube.com/watch?v=<>&list=《》，请输入<>位置的字符）"
            $command = "yt-dlp -f 'bestvideo+bestaudio' `"https://www.youtube.com/watch?v=$url`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" --no-playlist"
            if ($ffmpegAvailable) {
                $command += " --download-sections `"*from-url`""
            }
            Write-Host "执行命令：$command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 下载失败，请检查URL和网络连接" -ForegroundColor Red
            }
        }
        
        '4' {
            $url = Read-Host "输入播放列表URL（https://www.youtube.com/watch?v=<>&list=《》，请输入《》位置的字符）"
            $command = "yt-dlp -f 'bestvideo+bestaudio' `"https://www.youtube.com/playlist?list=$url`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" --no-playlist " 
            if ($ffmpegAvailable) {
                $command += " --download-sections `"*from-url`""
            }
            Write-Host "执行命令：$command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 下载失败，请检查URL和网络连接" -ForegroundColor Red
            }
        }
        
        '5' { exit }
        
        default {
            Write-Host "无效输入，请重新选择" -ForegroundColor Yellow
        }
    }

    # 循环间隔
    Write-Host "`n---------------------------------"
    $cont = Read-Host "是否继续操作？(Y/N)"
    if ($cont -notmatch '^[yY]') { break }
}