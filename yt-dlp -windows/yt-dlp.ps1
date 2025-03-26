<# 
YouTube音视频下载脚本
功能：安装/更新yt-dlp，下载视频或音频，支持剪贴板识别和URL优化
#>

# 新增：URL处理函数
function Process-YouTubeURL {
    param(
        [string]$url
    )
    
    # 解析URL参数
    $uri = [System.Uri]$url
    $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
    
    # 如果同时存在v和list参数
    if ($query['v'] -and $query['list']) {
        # 构造新查询字符串（保留除v和index外的所有参数）
        $newQuery = @{}
        foreach ($key in $query.Keys) {
            if ($key -notin @('v', 'index')) {
                $newQuery[$key] = $query[$key]
            }
        }
        # 构建新URL
        $newUri = [System.UriBuilder]$uri
        $newUri.Query = ($newQuery.GetEnumerator() | ForEach-Object {
            "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))"
        }) -join '&'
        return $newUri.ToString()
    }
    return $url
}

Write-Host "====================== 使用须知 ======================"
Write-Host "1. 需要Python 3.7+环境"
Write-Host "2. 需要能访问YouTube的网络环境"
Write-Host "3. 下载会员内容需自行修改脚本或提供cookies"
Write-Host "4. 文件默认保存到当前目录的Downloads文件夹"
Write-Host "===================================================`n"

# 初始化配置
$ffmpegAvailable = $false
$downloadPath = Join-Path (Get-Location) "Downloads"

# 设置TLS协议版本
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 创建下载目录
if (-not (Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    Write-Host "[!] 已自动创建下载目录: $downloadPath"
}

# ================== 新增：yt-dlp版本检测逻辑 ==================
$ytdlpInstalled = $false
$ytdlpUpdateAvailable = $false

if (Get-Command yt-dlp -ErrorAction SilentlyContinue) {
    $ytdlpInstalled = $true
    Write-Host "[√] yt-dlp已安装" -ForegroundColor Green
    
    try {
        # 获取本地版本
        $localVersion = (yt-dlp --version).Trim()
        Write-Host "当前版本: $localVersion"
        
        # 获取最新版本
        try {
            $apiResponse = Invoke-RestMethod -Uri "https://pypi.org/pypi/yt-dlp/json" -ErrorAction Stop
            $latestVersion = $apiResponse.info.version
            Write-Host "最新版本: $latestVersion"
            
            # 版本比较
            if ([version]$localVersion -lt [version]$latestVersion) {
                $ytdlpUpdateAvailable = $true
                Write-Host "[!] 发现新版本可用" -ForegroundColor Yellow
            } else {
                Write-Host "[√] 当前已是最新版本" -ForegroundColor Green
            }
        } catch {
            Write-Host "[!] 无法获取最新版本: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "[!] 无法获取本地版本: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "[×] yt-dlp未安装，请使用主菜单选项1安装" -ForegroundColor Red
}

# 更新提示
if ($ytdlpUpdateAvailable) {
    $choice = Read-Host "`n检测到新版本 $latestVersion，是否立即更新？(Y/N)"
    if ($choice -match '^[yY]') {
        Write-Host "正在更新yt-dlp..."
        python -m pip install --upgrade yt-dlp
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[√] 更新成功" -ForegroundColor Green
        } else {
            Write-Host "[×] 更新失败，请手动更新" -ForegroundColor Red
        }
    } else {
        Write-Host "[!] 警告：使用旧版本可能导致功能异常！" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 2
}
# ================== 版本检测逻辑结束 ==================

# 自动检测FFmpeg
try {
    Get-Command ffmpeg -ErrorAction Stop | Out-Null
    $ffmpegAvailable = $true
    Write-Host "[√] FFmpeg已安装" -ForegroundColor Green
} catch {
    Write-Host "[×] 未检测到FFmpeg！请从官网下载并添加到系统PATH: https://www.ffmpeg.org/download.html" -ForegroundColor Red
}

while ($true) {
    # 显示主菜单
    Write-Host "`n============= 主菜单 ============="
    Write-Host "1. 安装/更新yt-dlp (通过pip)"
    Write-Host "2. 下载视频（保存到: $downloadPath)"
    Write-Host "3. 下载音频（保存到: $downloadPath）"
    Write-Host "4. 退出脚本"
    Write-Host "=================================`n"

    $choice = Read-Host "请输入选项"
    
    switch ($choice) {
        '1' {
            $action = Read-Host "输入 '1' 安装yt-dlp 或 '2' 更新yt-dlp"
            if ($action -eq '1') {
                Write-Host "正在安装yt-dlp..."
                python -m pip install yt-dlp
            } elseif ($action -eq '2') {
                Write-Host "正在更新yt-dlp..."
                python -m pip install --upgrade yt-dlp
            } else {
                Write-Host "无效输入，操作已取消" -ForegroundColor Yellow
                continue
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 操作失败，请检查Python环境" -ForegroundColor Red
            }
        }
        
        '2' {
            # 剪贴板处理逻辑（修改点：允许直接回车确认）
            $clipboardContent = Get-Clipboard -ErrorAction SilentlyContinue
            $ytRegex = '^https?://(www\.)?youtube\.com/watch\?.*list=.*'
            
            if ($clipboardContent -match $ytRegex) {
                Write-Host "剪贴板检测到YouTube链接: $clipboardContent"
                $confirm = Read-Host "是否直接使用？(直接回车确认/Y/N)"
                # 正则匹配：允许空输入/Y/y
                if ($confirm -match '^[yY]?$') {
                    $url = $clipboardContent
                } else {
                    $url = Read-Host "请输入视频URL"
                }
            } else {
                Write-Host "[!] 剪贴板内容无效，请手动输入URL" -ForegroundColor Yellow
                $url = Read-Host "请输入视频URL"
            }
            
            # 处理URL参数
            $processedUrl = Process-YouTubeURL $url
            if ($processedUrl -ne $url) {
                Write-Host "[!] 已优化URL为播放列表模式: $processedUrl"
            }
            
            $command = "yt-dlp -f 'bestvideo+bestaudio' `"$processedUrl`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" "
            if ($ffmpegAvailable) { $command += " --download-sections `"*from-url`"" }
            Write-Host "执行命令: $command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 下载失败，请检查URL或网络" -ForegroundColor Red
            }
        }
        
        '3' {
            # 剪贴板处理逻辑（修改点：允许直接回车确认）
            $clipboardContent = Get-Clipboard -ErrorAction SilentlyContinue
            $ytRegex = '^https?://(www\.)?youtube\.com/watch\?.*list=.*'
            
            if ($clipboardContent -match $ytRegex) {
                Write-Host "剪贴板检测到YouTube链接: $clipboardContent"
                $confirm = Read-Host "是否直接使用？(直接回车确认/Y/N)"
                # 正则匹配：允许空输入/Y/y
                if ($confirm -match '^[yY]?$') {
                    $url = $clipboardContent
                } else {
                    $url = Read-Host "请输入视频URL"
                }
            } else {
                Write-Host "[!] 剪贴板内容无效，请手动输入URL" -ForegroundColor Yellow
                $url = Read-Host "请输入视频URL"
            }
            
            # 处理URL参数
            $processedUrl = Process-YouTubeURL $url
            if ($processedUrl -ne $url) {
                Write-Host "[!] 已优化URL为播放列表模式: $processedUrl"
            }
            
            $command = "yt-dlp -f 'bestaudio' `"$processedUrl`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" --no-playlist"
            if ($ffmpegAvailable) { $command += " --download-sections `"*from-url`"" }
            Write-Host "执行命令: $command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[错误] 下载失败，请检查URL或网络" -ForegroundColor Red
            }
        }
        
        '4' { exit }
        
        default {
            Write-Host "无效输入，请重新选择" -ForegroundColor Yellow
        }
    }

    # 循环控制
    Write-Host "`n---------------------------------"
    $cont = Read-Host "是否继续操作？(Y/N)"
    if ($cont -notmatch '^[yY]') { break }
}
