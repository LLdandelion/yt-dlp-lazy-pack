<# 
YouTube����Ƶ���ؽű�����ǿ�棩
���ܣ�֧�ֶ��ָ�ʽѡ��Ͳ�������
#>

# ������ʼ��
$downloadPath = Join-Path (Get-Location) "Downloads"
$ffmpegDir = Join-Path (Get-Location) "ffmpeg-master-latest-win64-gpl-shared"
$ffmpegExe = Join-Path (Join-Path $ffmpegDir "bin") "ffmpeg.exe"

# ��ʽ����
$formatConfig = @{
    Video = @{ Format = "mp4"; Params = "--recode-video mp4" }
    Audio = @{ Format = "mp3"; Params = "--extract-audio --audio-format mp3" }
}

# ����TLSЭ��汾
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ʹ��˵����Ϣ
$notice = @"
====================== ʹ����֪ ======================
1. ��ҪPython 3.7+����
2. ��Ҫ�ܷ���YouTube�����绷��
3. �ݲ�֧�����ػ�Ա��������
4. �ļ�Ĭ�ϱ��浽��ǰĿ¼��Downloads�ļ���
===================================================
"@

# ����Ԥ��⺯��
function Test-Environments {
    # 1. ���Python����
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "[����] δ��⵽Python���������Ȱ�װPython 3.7+" -Foreground Red
        return $false
    }
    
    # ���Python�汾
    try {
        $versionOutput = python --version 2>&1
        if ($versionOutput -match "Python (\d+)\.(\d+)\.\d+") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 7)) {
                Write-Host "[����] Python�汾���ͣ���Ҫ3.7����߰汾����ǰ�汾��$major.$minor��" -Foreground Red
                return $false
            }
        }
        else {
            Write-Host "[����] �޷�����Python�汾" -Foreground Red
            return $false
        }
    }
    catch {
        Write-Host "[����] Python�汾���ʧ��" -Foreground Red
        return $false
    }

    # 2. ���FFmpeg����
    $ffmpegFound = $false
    if (Test-Path $ffmpegExe) {
        Write-Host "[��] ��⵽����FFmpeg��·����$ffmpegExe��" -Foreground Green
        $ffmpegFound = $true
    }
    else {
        $sysFFmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($sysFFmpeg) {
            Write-Host "[��] ��⵽ϵͳ����FFmpeg��·����$($sysFFmpeg.Source)��" -Foreground Green
            $ffmpegFound = $true
        }
    }
    
    if (-not $ffmpegFound) {
        Write-Host "[����] �����ļ��л�ϵͳ������δ�ҵ�FFmpeg" -Foreground Red
        return $false
    }

    return $true
}

# ������������
function Process-YouTubeURL {
    param(
        [string]$url
    )
    
    try {
        $uri = [System.Uri]$url
    
        # ���������Ż�
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

        # ����·��ת���߼�
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
        Write-Host "URL����ʧ��: $_" -Foreground Red
    }
    return $url
}

function Get-YouTubeURL {
    try {
        $clipboardContent = Get-Clipboard -ErrorAction SilentlyContinue
        $ytRegex = '^https?://(www\.)?(youtube\.com/watch\?.*(v=|list=)|youtu\.be/)'
        
        if ($clipboardContent -match $ytRegex) {
            Write-Host "�������⵽YouTube����: $clipboardContent" -Foreground Cyan
            $confirm = Read-Host "ֱ�ӻس�ʹ�ã������������л�Ϊ�ֶ�����"
            if ($confirm -eq '') { 
                return Process-YouTubeURL $clipboardContent 
            }
        }
    }
    catch {
        Write-Host "���������ʧ��: $_" -Foreground Yellow
    }
    
    do {
        $url = Read-Host "������YouTube����"
        if (-not ($url -match $ytRegex)) { Write-Host "��Ч�����Ӹ�ʽ��" -Foreground Red }
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
        # ������������
        $baseCommand = "yt-dlp -P `"$downloadPath`" --no-playlist --download-sections `"*from-url`""
        
        # ��Ӹ�ʽ����
        if ($type -eq 'video') {
            $command = "$baseCommand -f 'bestvideo+bestaudio' `"$url`" -o '%(title)s.%(ext)s' $($formatConfig.Video.Params)"
        }
        else {
            $command = "$baseCommand -f 'bestaudio' `"$url`" -o '%(title)s.%(ext)s' $($formatConfig.Audio.Params)"
        }
        
        # ���FFmpeg·��
        $sysFFmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
        if ($sysFFmpeg) {
            $command += " --ffmpeg-location `"$($sysFFmpeg.Source)`""
        }
        elseif (Test-Path $ffmpegExe) {
            $command += " --ffmpeg-location `"$ffmpegExe`""
        }
        
        # ִ������
        Write-Host "ִ������: $command"
        Invoke-Expression $command
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[����] ����ʧ�ܣ�����URL������" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "���ع����з�������: $_" -Foreground Red
    }
}

# �����̿�ʼ
try {
    Write-Host $notice -Foreground Cyan

    # ����Ԥ���
    if (-not (Test-Environments)) {
        Write-Host "`n[!] �������δͨ�����ű���ֹ" -Foreground Red
        exit 1
    }

# �����汾�ű�׼������
function Normalize-Version {
    param(
        [string]$versionString
    )
    # ȥ�������ֺ͵���ַ����������廯�汾���е����ֲ��֣�
    $cleanVersion = $versionString -replace '[^0-9.]',''
    # �ָ�汾����ɲ���
    $parts = $cleanVersion.Split('.') | ForEach-Object { 
        # �Ƴ�ǰ���㲢ת��Ϊ����
        if ($_ -match '^\d+') { 
            [int]$_.TrimStart('0') 
        } else { 
            0 
        }
    }
    # ����Ϊ��׼���ַ�������ౣ��4�Σ�
    return ($parts[0..3] -join '.')
}

# ��ǿ��yt-dlp��ⰲװ�߼�
$ytdlpInstalled = $false
if ($ytdlp = Get-Command yt-dlp -ErrorAction SilentlyContinue) {
    try {
        # ��ȡ��ǰ�汾
        $currentRawVersion = (yt-dlp --version 2>$null).Trim()
        $currentVersion = Normalize-Version $currentRawVersion
        
        # �����Ի��Ƶİ汾���
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
                Write-Host "[!] �汾���ʧ�ܣ��������� ($retryCount/$maxRetries)..." -Foreground Yellow
                Start-Sleep -Seconds 2
            }
        } while ($true)

        # �汾�Ƚ��߼�
        if ($currentVersion -ne $latestVersion) {
            Write-Host "[!] �����°汾: $latestRawVersion" -Foreground Yellow
            $choice = Read-Host "�Ƿ���µ����°棿(Y/N)"
            if ($choice -match '^[Yy]$') {
                Write-Host "���ڸ���yt-dlp..."
                python -m pip install --upgrade yt-dlp 2>&1 | Out-Null
                Write-Host "[��] ���³ɹ�" -Foreground Green
            }
        }
        else {
            Write-Host "[��] yt-dlp�������°棨$latestRawVersion��" -Foreground Green
        }
        $ytdlpInstalled = $true
    }
    catch {
        Write-Host "[!] �޷���ȡ���°汾��Ϣ: $_" -Foreground Yellow
        Write-Host "[��] ����ʹ�õ�ǰ�汾: $currentRawVersion" -Foreground Green
        $ytdlpInstalled = $true
    }
}

if (-not $ytdlpInstalled) {
    Write-Host "[!] δ��⵽��Ҫ��� yt-dlp" -Foreground Red
    $choice = Read-Host "�Ƿ�������װ��(Y/N)"
    if ($choice -notmatch '^[Yy]$') {
        Write-Host "[����] �û�ȡ����װ���ű���ֹ" -Foreground Red
        exit 1
    }
    try {
        Write-Host "����ͨ��Python pip��װyt-dlp..."
        python -m pip install yt-dlp 2>&1 | Out-Null
        Write-Host "[��] ��װ�ɹ�" -Foreground Green
        
        # ��װ����֤
        if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
            Write-Host "[!] ��װ����֤ʧ�ܣ��볢�����²�����" -Foreground Red
            Write-Host "1. �ֶ�ִ��: python -m pip install yt-dlp"
            Write-Host "2. ȷ��Python�ű�Ŀ¼��PATH����������"
            exit 1
        }
    }
    catch {
        Write-Host "[����] ��װʧ��: $_" -Foreground Red
        exit 1
    }
}

    # ��������Ŀ¼
    if (-not (Test-Path $downloadPath)) {
        New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    }

    # ���˵�ѭ��
    while ($true) {
        Write-Host "`n============= ���˵� ============="
        Write-Host "1. ������Ƶ����ǰ��ʽ��$($formatConfig.Video.Format)��"
        Write-Host "2. ������Ƶ����ǰ��ʽ��$($formatConfig.Audio.Format)��"
        Write-Host "3. �޸����ظ�ʽ����ǰ��Ƶ��$($formatConfig.Video.Format)����Ƶ��$($formatConfig.Audio.Format)��"
        Write-Host "4. �˳��ű�"
        Write-Host "=================================`n"
        
        $selection = Read-Host "��ѡ�����"
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
                Write-Host "`n=== ��ʽѡ�� ==="
                Write-Host "1/a) Ĭ�ϸ�ʽ (mp4/mp3)"
                Write-Host "2/b) ��������ʽ (avi/flac)"
                Write-Host "3/c) ԭʼ��ʽ (��ת��)"
                $choice = Read-Host "��ѡ���ʽ�������������ֻ���ĸ��"
                
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
                        $formatConfig.Video = @{ Format = "ԭʼ��ʽ"; Params = "" }
                        $formatConfig.Audio = @{ Format = "ԭʼ��ʽ"; Params = "" }
                    }
                    default {
                        Write-Host "��Чѡ�񣬱��ֵ�ǰ��ʽ" -Foreground Red
                    }
                }
                Write-Host "��ǰ��Ƶ��ʽ: $($formatConfig.Video.Format)"
                Write-Host "��ǰ��Ƶ��ʽ: $($formatConfig.Audio.Format)"
                continue
            }
            '4' { exit }
            default { Write-Host "��Ч����" -Foreground Red }
        }
        
        # ѭ������
        Write-Host "`n---------------------------------"
        $key = Read-Host "���س��������������� exit �˳�"
        if ($key -eq 'exit') { exit }
    }
}
catch {
    Write-Host "�ű�ִ�й����з���δԤ�ڵĴ���: $_" -Foreground Red
    exit 1
}