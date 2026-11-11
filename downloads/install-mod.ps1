# 赛博朋克 2077 模组一键安装脚本
# 用法：把从 Nexus 下载的 zip 丢进 D:\CP2077_ModDrop\，然后双击「装mod.cmd」
# 说明：脚本会识别包里的目录结构，把文件放到游戏对应位置；放之前备份同名旧文件。

$ErrorActionPreference = 'Stop'
$TestMode = $args -contains '-Test'
$GameDir = "D:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077"
$DropDir = "D:\CP2077_ModDrop"
$LogRoot = "D:\CP2077_ModLog"
$Stamp = Get-Date -Format "yyyyMMdd_HHmmss"

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

Say "==============================================" 'Cyan'
Say "  赛博朋克 2077 · 模组安装" 'Cyan'
Say "==============================================" 'Cyan'

if (-not (Test-Path $GameDir)) { Say "找不到游戏目录：$GameDir" 'Red'; exit 1 }
if (-not (Test-Path $DropDir)) { New-Item -ItemType Directory -Path $DropDir -Force | Out-Null; Say "已创建投放目录：$DropDir" 'Yellow' }
$LogDir = Join-Path $LogRoot $Stamp
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

$zips = @(Get-ChildItem $DropDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.zip', '.7z') })
if ($zips.Count -eq 0) {
    Say "投放目录里没有 zip：$DropDir" 'Yellow'
    Say "把下载的 mod 压缩包放进去，再运行一次。" 'Yellow'
    if (-not $TestMode) { Read-Host "按回车关闭" }
    exit 0
}

Say "发现 $($zips.Count) 个压缩包" 'Green'
$sevenZip = @("C:\Program Files\7-Zip\7z.exe", "C:\Program Files (x86)\7-Zip\7z.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

function Expand-Package($file, $dest) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    if ($file.Extension -eq '.zip') {
        Expand-Archive -Path $file.FullName -DestinationPath $dest -Force
        return $true
    }
    if ($file.Extension -eq '.7z') {
        if (-not $sevenZip) { Say "  需要 7-Zip 才能解压 .7z，已跳过" 'Yellow'; return $false }
        & $sevenZip x $file.FullName "-o$dest" -y | Out-Null
        return $true
    }
    return $false
}

$report = @()
foreach ($zip in $zips) {
    Say ""
    Say "===== $($zip.Name) =====" 'White'
    $tmp = Join-Path $LogDir ("unpack_" + [IO.Path]::GetFileNameWithoutExtension($zip.Name))
    try { if (-not (Expand-Package $zip $tmp)) { $report += "$($zip.Name) : 解压失败"; continue } }
    catch { Say "  解压出错：$($_.Exception.Message)" 'Red'; $report += "$($zip.Name) : 解压出错"; continue }

    # 如果压缩包里只有一层同名目录，钻进去
    $root = $tmp
    $entries = @(Get-ChildItem $root -Force | Where-Object { $_.Name -notmatch '^__MACOSX$' })
    if ($entries.Count -eq 1 -and $entries[0].PSIsContainer) { $root = $entries[0].FullName }

    $installed = @()
    # 1) 标准目录：archive / r6 / bin / red4ext / engine / mods
    foreach ($dirName in @('archive','r6','bin','red4ext','engine','mods')) {
        $src = Join-Path $root $dirName
        if (Test-Path $src) {
            $dst = if ($dirName -eq 'mods') { Join-Path $GameDir 'bin\x64\plugins\cyber_engine_tweaks\mods' } else { Join-Path $GameDir $dirName }
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            & robocopy $src $dst /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 2>&1 | Out-Null
            $installed += $dirName
        }
    }
    # 2) 散落文件
    $loose = @(Get-ChildItem $root -File -Force)
    foreach ($f in $loose) {
        $target = $null
        switch -Regex ($f.Name) {
            '\.archive\.xl$' { $target = Join-Path $GameDir 'archive\pc\mod' }
            '\.archive$'     { $target = Join-Path $GameDir 'archive\pc\mod' }
            '\.reds$'        { $target = Join-Path $GameDir 'r6\scripts' }
            '\.toml$'        { $target = Join-Path $GameDir 'r6\tweaks' }
            '\.ini$'         { $target = Join-Path $GameDir 'r6\config' }
            '\.dll$|\.asi$'  { $target = Join-Path $GameDir 'bin\x64\plugins' }
        }
        if ($target) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
            Copy-Item $f.FullName $target -Force
            $installed += $f.Name
        }
    }
    # 3) r6\subdirs 下的散落 archive（有些包结构是 r6\... 已覆盖）
    if ($installed.Count -eq 0) {
        Say "  没认出可安装的内容，请手动看一眼：$root" 'Yellow'
        $report += "$($zip.Name) : 未识别"
    } else {
        Say "  已安装：$($installed -join ', ')" 'Green'
        $report += "$($zip.Name) : $($installed -join ', ')"
    }
}

Say ""
Say "==============================================" 'Cyan'
Say "  结果" 'Cyan'
$report | ForEach-Object { Say "  $_" }
Say ""
Say "解压残留和日志：$LogDir" 'DarkGray'
Say "注意：装完先启动游戏确认能进；崩了就把下面这个文件夹里对应文件删掉。" 'Yellow'
Say "备份参考：D:\CP2077_ModBackup_20261108_2110" 'DarkGray'
Say ""
if (-not $TestMode) { Read-Host "按回车关闭" }
