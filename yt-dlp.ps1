<# 
YouTube音视频下载脚本（增强版）
功能：支持多种格式选择和参数配置
#>

# 环境初始化
$downloadPath = Join-Path (Get-Location) "Downloads"
$ffmpegDir = Join-Path (Get-Location) "ffmpeg-master-latest-win64-gpl-shared"
$ffmpegExe = Join-Path (Join-Path $ffmpegDir "bin") "ffmpeg.exe"

# 格式配置
$formatConfig = @{
    Video = @{ Format = "mp4"; Params = "--recode-video mp4" }
    Audio = @{ Format = "mp3"; Params = "--extract-audio --audio-format mp3" }
}

# 设置TLS协议版本
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 使用说明信息
$notice = @"
====================== 使用须知 ======================
1. 需要Python 3.7+环境
2. 需要能访问YouTube的网络环境
3. 暂不支持下载会员订阅内容
4. 文件默认保存到当前目录的Downloads文件夹
===================================================
"@

# 环境预检测函数
function Test-Environments {
    # 1. 检测Python环境
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "[错误] 未检测到Python环境，请先安装Python 3.7+" -Foreground Red
        return $false
    }
    
    # 检查Python版本
    try {
        $versionOutput = python --version 2>&1
        if ($versionOutput -match "Python (\d+)\.(\d+)\.\d+") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 7)) {
                Write-Host "[错误] Python版本过低，需要3.7或更高版本（当前版本：$major.$minor）" -Foreground Red
                return $false
            }
        }
        else {
            Write-Host "[错误] 无法解析Python版本" -Foreground Red
            return $false
        }
    }
    catch {
        Write-Host "[错误] Python版本检测失败" -Foreground Red
        return $false
    }

    # 2. 检测FFmpeg环境
    $ffmpegFound = $false
    if (Test-Path $ffmpegExe) {
        Write-Host "[√] 检测到本地FFmpeg（路径：$ffmpegExe）" -Foreground Green
        $ffmpegFound = $true
    }
    else {
        $sysFFmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($sysFFmpeg) {
            Write-Host "[√] 检测到系统环境FFmpeg（路径：$($sysFFmpeg.Source)）" -Foreground Green
            $ffmpegFound = $true
        }
    }
    
    if (-not $ffmpegFound) {
        Write-Host "[错误] 本地文件夹或系统环境中未找到FFmpeg" -Foreground Red
        return $false
    }

    return $true
}

# 函数定义区域
function Process-YouTubeURL {
    param(
        [string]$url
    )
    
    try {
        $uri = [System.Uri]$url
    
        # 参数解析优化
        $queryParams = @{}
        if (-not [string]::IsNullOrEmpty($uri.Query)) {
            $uri.Query.TrimStart('?').Split('&') | ForEach-Object {
                $pair = $_.Split('=', 2)
                if ($pair.Length -ge 1) {
                    $key = [System.Uri]::UnescapeDataString($pair[0])
                    $value = if ($pair.Length -ge 2) { [System.Uri]::UnescapeDataString($pair[1]) } else { $null }
                    $queryParams[$key] = $value
                }
            }
        }

        # 智能路径转换逻辑
        if ($queryParams.ContainsKey('list')) {
            $newUri = [System.UriBuilder]::new($uri.Scheme, $uri.Host)
            $newUri.Path = "/playlist"
            $newUri.Query = "list=$([System.Uri]::EscapeDataString($queryParams['list']))"
            return $newUri.Uri.ToString()
        }
        elseif ($queryParams.ContainsKey('v')) {
            return $uri.ToString()
        }
    }
    catch {
        Write-Host "URL处理失败: $_" -Foreground Red
    }
    return $url
}

function Get-YouTubeURL {
    try {
        $clipboardContent = Get-Clipboard -ErrorAction SilentlyContinue
        $ytRegex = '^https?://(www\.)?(youtube\.com/watch\?.*(v=|list=)|youtu\.be/)'
        
        if ($clipboardContent -match $ytRegex) {
            Write-Host "剪贴板检测到YouTube链接: $clipboardContent" -Foreground Cyan
            $confirm = Read-Host "直接回车使用，其他输入则切换为手动输入"
            if ($confirm -eq '') { 
                return Process-YouTubeURL $clipboardContent 
            }
        }
    }
    catch {
        Write-Host "剪贴板访问失败: $_" -Foreground Yellow
    }
    
    do {
        $url = Read-Host "请输入YouTube链接"
        if (-not ($url -match $ytRegex)) { Write-Host "无效的链接格式！" -Foreground Red }
    } while (-not ($url -match $ytRegex))
    
    return Process-YouTubeURL $url
}

function Invoke-Download {
    param(
        [string]$url,
        [ValidateSet('video','audio')]$type,
        [string]$downloadPath,
        [string]$ffmpegBinPath
    )
    
    try {
        # 构建基础命令
        $baseCommand = "yt-dlp -P `"$downloadPath`" --no-playlist --download-sections `"*from-url`""
        
        # 添加格式参数
        if ($type -eq 'video') {
            $command = "$baseCommand -f 'bestvideo+bestaudio' `"$url`" -o '%(title)s.%(ext)s' $($formatConfig.Video.Params)"
        }
        else {
            $command = "$baseCommand -f 'bestaudio' `"$url`" -o '%(title)s.%(ext)s' $($formatConfig.Audio.Params)"
        }
        
        # 添加FFmpeg路径
        $sysFFmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($sysFFmpeg) {
            $command += " --ffmpeg-location `"$($sysFFmpeg.Source)`""
        }
        elseif (Test-Path $ffmpegExe) {
            $command += " --ffmpeg-location `"$ffmpegExe`""
        }
        
        # 执行命令
        Write-Host "执行命令: $command"
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[错误] 下载失败，请检查URL或网络" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "下载过程中发生错误: $_" -Foreground Red
    }
}

# 主流程开始
try {
    Write-Host $notice -Foreground Cyan

    # 环境预检测
    if (-not (Test-Environments)) {
        Write-Host "`n[!] 环境检测未通过，脚本终止" -Foreground Red
        exit 1
    }

# 新增版本号标准化函数
function Normalize-Version {
    param(
        [string]$versionString
    )
    # 去除非数字和点的字符（保留语义化版本号中的数字部分）
    $cleanVersion = $versionString -replace '[^0-9.]',''
    # 分割版本号组成部分
    $parts = $cleanVersion.Split('.') | ForEach-Object { 
        # 移除前导零并转换为整数
        if ($_ -match '^\d+') { 
            [int]$_.TrimStart('0') 
        } else { 
            0 
        }
    }
    # 重组为标准化字符串（最多保留4段）
    return ($parts[0..3] -join '.')
}

# 增强版yt-dlp检测安装逻辑
$ytdlpInstalled = $false
if ($ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue) {
    try {
        # 获取当前版本
        $currentRawVersion = (yt-dlp --version 2>$null).Trim()
        $currentVersion = Normalize-Version $currentRawVersion
        
        # 带重试机制的版本检查
        $retryCount = 0
        $maxRetries = 2
        do {
            try {
                $response = Invoke-RestMethod -Uri "https://pypi.org/pypi/yt-dlp/json" -UseBasicParsing -TimeoutSec 5
                $latestRawVersion = $response.info.version
                $latestVersion = Normalize-Version $latestRawVersion
                break
            }
            catch {
                $retryCount++
                if ($retryCount -ge $maxRetries) {
                    throw
                }
                Write-Host "[!] 版本检查失败，正在重试 ($retryCount/$maxRetries)..." -Foreground Yellow
                Start-Sleep -Seconds 2
            }
        } while ($true)

        # 版本比较逻辑
        if ($currentVersion -ne $latestVersion) {
            Write-Host "[!] 发现新版本: $latestRawVersion" -Foreground Yellow
            $choice = Read-Host "是否更新到最新版？(Y/N)"
            if ($choice -match '^[Yy]$') {
                Write-Host "正在更新yt-dlp..."
                python -m pip install --upgrade yt-dlp 2>&1 | Out-Null
                Write-Host "[√] 更新成功" -Foreground Green
            }
        }
        else {
            Write-Host "[√] yt-dlp已是最新版（$latestRawVersion）" -Foreground Green
        }
        $ytdlpInstalled = $true
    }
    catch {
        Write-Host "[!] 无法获取最新版本信息: $_" -Foreground Yellow
        Write-Host "[√] 继续使用当前版本: $currentRawVersion" -Foreground Green
        $ytdlpInstalled = $true
    }
}

if (-not $ytdlpInstalled) {
    Write-Host "[!] 未检测到必要组件 yt-dlp" -Foreground Red
    $choice = Read-Host "是否立即安装？(Y/N)"
    if ($choice -notmatch '^[Yy]$') {
        Write-Host "[错误] 用户取消安装，脚本终止" -Foreground Red
        exit 1
    }
    try {
        Write-Host "正在通过Python pip安装yt-dlp..."
        python -m pip install yt-dlp 2>&1 | Out-Null
        Write-Host "[√] 安装成功" -Foreground Green
        
        # 安装后验证
        if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
            Write-Host "[!] 安装后验证失败，请尝试以下操作：" -Foreground Red
            Write-Host "1. 手动执行: python -m pip install yt-dlp"
            Write-Host "2. 确保Python脚本目录在PATH环境变量中"
            exit 1
        }
    }
    catch {
        Write-Host "[错误] 安装失败: $_" -Foreground Red
        exit 1
    }
}

    # 创建下载目录
    if (-not (Test-Path $downloadPath)) {
        New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    }

    # 主菜单循环
    while ($true) {
        Write-Host "`n============= 主菜单 ============="
        Write-Host "1. 下载视频（当前格式：$($formatConfig.Video.Format)）"
        Write-Host "2. 下载音频（当前格式：$($formatConfig.Audio.Format)）"
        Write-Host "3. 修改下载格式（当前视频：$($formatConfig.Video.Format)，音频：$($formatConfig.Audio.Format)）"
        Write-Host "4. 退出脚本"
        Write-Host "=================================`n"
        
        $selection = Read-Host "请选择操作"
        switch ($selection) {
            '1' { 
                $url = Get-YouTubeURL
                if ($url) { 
                    Invoke-Download -url $url -type video -downloadPath $downloadPath -ffmpegBinPath $ffmpegDir 
                }
            }
            '2' { 
                $url = Get-YouTubeURL
                if ($url) { 
                    Invoke-Download -url $url -type audio -downloadPath $downloadPath -ffmpegBinPath $ffmpegDir 
                }
            }
            '3' {
                Write-Host "`n=== 格式选择 ==="
                Write-Host "1/a) 默认格式 (mp4/mp3)"
                Write-Host "2/b) 高质量格式 (avi/flac)"
                Write-Host "3/c) 原始格式 (不转码)"
                $choice = Read-Host "请选择格式方案（输入数字或字母）"
                
                if ($choice -in '1','2','3') {
                    $choice = @('a','b','c')[[int]$choice -1]
                }

                switch ($choice.ToLower()) {
                    { $_ -in 'a','1' } {
                        $formatConfig.Video = @{ Format = "mp4"; Params = "--recode-video mp4" }
                        $formatConfig.Audio = @{ Format = "mp3"; Params = "--extract-audio --audio-format mp3" }
                    }
                    { $_ -in 'b','2' } {
                        $formatConfig.Video = @{ Format = "avi"; Params = "--recode-video avi" }
                        $formatConfig.Audio = @{ Format = "flac"; Params = "--extract-audio --audio-format flac" }
                    }
                    { $_ -in 'c','3' } {
                        $formatConfig.Video = @{ Format = "原始格式"; Params = "" }
                        $formatConfig.Audio = @{ Format = "原始格式"; Params = "" }
                    }
                    default {
                        Write-Host "无效选择，保持当前格式" -Foreground Red
                    }
                }
                Write-Host "当前视频格式: $($formatConfig.Video.Format)"
                Write-Host "当前音频格式: $($formatConfig.Audio.Format)"
                continue
            }
            '4' { exit }
            default { Write-Host "无效输入" -Foreground Red }
        }
        
        # 循环控制
        Write-Host "`n---------------------------------"
        $key = Read-Host "按回车继续操作，输入 exit 退出"
        if ($key -eq 'exit') { exit }
    }
}
catch {
    Write-Host "脚本执行过程中发生未预期的错误: $_" -Foreground Red
    exit 1
}