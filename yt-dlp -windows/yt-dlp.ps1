<#
YouTube��Ƶ���ؽű������·���棩
���ܣ���װ/����yt-dlp�����ص�����Ƶ�����ز����б�
#>

Write-Host "====================== ʹ����֪ ======================"
Write-Host "1. ��ҪPython 3.7+���л���"
Write-Host "2. ��Ҫ�ܷ���YouTube�����绷��"
Write-Host "3. ���ػ�Ա������Ҫ�����޸Ľű����cookies"
Write-Host "4. �ļ������浽��ǰĿ¼��Downloads�ļ���"
Write-Host "===================================================`n"

# ��ʼ����������
$ffmpegAvailable = $false
$firstRun = $true
$downloadPath = Join-Path (Get-Location) "Downloads"

# �Զ���������Ŀ¼
if (-not (Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    Write-Host "[!] ���Զ���������Ŀ¼��$downloadPath"
}

while ($true) {
    # �״����м��ffmpeg
    if ($firstRun) {
        $checkFFmpeg = Read-Host "�Ƿ��Ѱ�װFFmpeg����ӵ�ϵͳPATH��(Y/N)"
        if ($checkFFmpeg -in @('Y','y')) {
            try {
                Get-Command ffmpeg -ErrorAction Stop | Out-Null
                $ffmpegAvailable = $true
                Write-Host "[��] FFmpeg���ͨ��"
            } catch {
                Write-Host "[��] δ�ҵ�FFmpeg�����ֹ��ܿ�������"
            }
        }
        $firstRun = $false
    }

    # ��ʾ���˵�
    Write-Host "`n============= ���˵� ============="
    Write-Host "1. ͨ��pip��װyt-dlp"
    Write-Host "2. ����yt-dlp"
    Write-Host "3. ���ص�����Ƶ�����浽��$downloadPath��"
    Write-Host "4. ���ز����б����浽��$downloadPath��"
    Write-Host "5. �˳��ű�"
    Write-Host "=================================`n"

    $choice = Read-Host "������ѡ������"
    
    switch ($choice) {
        '1' {
            Write-Host "��ʼ��װyt-dlp..."
            python -m pip install yt-dlp
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[����] ��װʧ�ܣ�����Python����" -ForegroundColor Red
            }
        }
        
        '2' {
            Write-Host "������..."
            python -m pip install --upgrade yt-dlp
        }
        
        '3' {
            $url = Read-Host "������ƵURL��https://www.youtube.com/watch?v=<>&list=������������<>λ�õ��ַ���"
            $command = "yt-dlp -f 'bestvideo+bestaudio' `"https://www.youtube.com/watch?v=$url`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" --no-playlist"
            if ($ffmpegAvailable) {
                $command += " --download-sections `"*from-url`""
            }
            Write-Host "ִ�����$command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[����] ����ʧ�ܣ�����URL����������" -ForegroundColor Red
            }
        }
        
        '4' {
            $url = Read-Host "���벥���б�URL��https://www.youtube.com/watch?v=<>&list=�����������롶��λ�õ��ַ���"
            $command = "yt-dlp -f 'bestvideo+bestaudio' `"https://www.youtube.com/playlist?list=$url`" -o '%(title)s.%(ext)s' -P `"$downloadPath`" --no-playlist " 
            if ($ffmpegAvailable) {
                $command += " --download-sections `"*from-url`""
            }
            Write-Host "ִ�����$command"
            Invoke-Expression $command
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[����] ����ʧ�ܣ�����URL����������" -ForegroundColor Red
            }
        }
        
        '5' { exit }
        
        default {
            Write-Host "��Ч���룬������ѡ��" -ForegroundColor Yellow
        }
    }

    # ѭ�����
    Write-Host "`n---------------------------------"
    $cont = Read-Host "�Ƿ����������(Y/N)"
    if ($cont -notmatch '^[yY]') { break }
}