#Requires -Version 5.1
<#
  PC Gaming Health Check
  - Chỉ ĐỌC thông tin, không thay đổi bất kỳ cài đặt nào trên máy.
  - Chạy tốt nhất với quyền Administrator (một số mục cần quyền admin).
  - Xuất báo cáo HTML ra Desktop.
  Tham số:  -NoOpen     (không tự mở báo cáo)
            -NoNetwork  (bỏ qua test ping)
#>
param([switch]$NoOpen, [switch]$NoNetwork)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$R = New-Object System.Collections.Generic.List[object]
$Label = @{ OK = 'TỐT'; WARN = 'CHÚ Ý'; BAD = 'LỖI'; INFO = 'INFO' }
$Color = @{ OK = 'Green'; WARN = 'Yellow'; BAD = 'Red'; INFO = 'Gray' }

function Section($name) { Write-Host "`n== $name ==" -ForegroundColor Cyan; $script:CurGroup = $name }
function Add-R($Item, $Value, $Status = 'INFO', $Advice = '') {
    $R.Add([pscustomobject]@{ Group = $script:CurGroup; Item = $Item; Value = "$Value"; Status = $Status; Advice = $Advice })
    Write-Host ("  [{0,-5}] {1}: {2}" -f $Label[$Status], $Item, $Value) -ForegroundColor $Color[$Status]
    if ($Advice -and $Status -ne 'OK') { Write-Host "          -> $Advice" -ForegroundColor DarkGray }
}

Write-Host "PC GAMING HEALTH CHECK  -  $env:COMPUTERNAME  -  $(Get-Date -Format 'dd/MM/yyyy HH:mm')" -ForegroundColor White
if (-not $isAdmin) { Write-Host "(Không chạy bằng quyền Admin: một số mục sẽ bị bỏ qua)" -ForegroundColor DarkYellow }

$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$battery = Get-CimInstance Win32_Battery
$isLaptop = [bool]$battery

# ------------------------------------------------------------------ HỆ THỐNG
Section 'Hệ thống'
Add-R 'Máy' ("{0} {1}{2}" -f $cs.Manufacturer, $cs.Model, $(if ($isLaptop) { ' (Laptop)' } else { '' }))
$bb = Get-CimInstance Win32_BaseBoard
Add-R 'Mainboard' "$($bb.Manufacturer) $($bb.Product)"
Add-R 'Windows' "$($os.Caption) (build $($os.BuildNumber))"

$up = (Get-Date) - $os.LastBootUpTime
$upS = "{0} ngày {1} giờ" -f $up.Days, $up.Hours
if ($up.TotalDays -gt 3) { Add-R 'Uptime' $upS 'WARN' 'Máy chạy lâu không khởi động lại. Hãy Restart (không phải Shut down) trước khi chơi.' }
else { Add-R 'Uptime' $upS 'OK' }

$hb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled
if ($hb -eq 1) { Add-R 'Fast Startup' 'Đang bật' 'WARN' 'Shut down không khởi động lại kernel/driver. Tắt trong powercfg.cpl > Choose what the power buttons do.' }
else { Add-R 'Fast Startup' 'Tắt' 'OK' }

if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    Add-R 'Windows Update' 'Đang chờ khởi động lại' 'WARN' 'Restart để hoàn tất cập nhật.'
}

if ($isLaptop) {
    if ($battery.BatteryStatus -eq 1) { Add-R 'Nguồn' 'Đang chạy PIN' 'BAD' 'Cắm sạc khi chơi game, chạy pin CPU/GPU bị hạ xung mạnh.' }
    else { Add-R 'Nguồn' 'Đang cắm sạc' 'OK' }
}

# ------------------------------------------------------------------ CÀI ĐẶT WINDOWS
Section 'Cài đặt Windows'
$schemeLine = powercfg /getactivescheme
$guid = ([regex]'[0-9a-f]{8}-[0-9a-f-]{27}').Match("$schemeLine").Value
$planName = ([regex]'\((.+)\)').Match("$schemeLine").Groups[1].Value
switch ($guid) {
    '8c5e7fda-e8bf-4a96-9a85-cf3e3be4f3db' { Add-R 'Power plan' $planName 'OK' }
    'e9a42b02-d5df-448d-aa00-03f14749eb61' { Add-R 'Power plan' $planName 'OK' }
    'a1841308-3541-4fab-bc81-f71556f20b4a' { Add-R 'Power plan' $planName 'BAD' 'Đang ở Power saver! Chuyển sang High performance.' }
    '381b4222-f694-41f0-9685-ff5bb260df2e' { Add-R 'Power plan' $planName 'WARN' 'Balanced có thể hạ xung CPU. Thử High performance: powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-cf3e3be4f3db' }
    default {
        if ($planName -match 'High perf|Ultimate|Hiệu suất cao|Hiệu năng cao|Bitsum|Gaming|Performance') { Add-R 'Power plan' $planName 'OK' }
        elseif ($planName -match 'saver|Tiết kiệm') { Add-R 'Power plan' $planName 'BAD' 'Đang ở chế độ tiết kiệm điện! Chuyển sang High performance.' }
        elseif ($planName -match 'Balanced|Cân bằng') { Add-R 'Power plan' $planName 'WARN' 'Balanced có thể hạ xung CPU. Thử High performance.' }
        else { Add-R 'Power plan' $planName 'INFO' 'Power plan tùy chỉnh (của hãng / do người dùng tạo).' }
    }
}

$gm = (Get-ItemProperty 'HKCU:\Software\Microsoft\GameBar').AutoGameModeEnabled
if ($gm -eq 0) { Add-R 'Game Mode' 'Tắt' 'WARN' 'Bật lại: Settings > Gaming > Game Mode.' } else { Add-R 'Game Mode' 'Bật' 'OK' }

$hist = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR').HistoricalCaptureEnabled
$dvr = (Get-ItemProperty 'HKCU:\System\GameConfigStore').GameDVR_Enabled
if ($hist -eq 1) { Add-R 'Xbox ghi hình nền' 'Đang ghi liên tục' 'BAD' 'Tắt: Settings > Gaming > Captures > Record what happened.' }
elseif ($dvr -eq 1) { Add-R 'Xbox Game DVR' 'Bật' 'WARN' 'Nếu không dùng, tắt trong Settings > Gaming > Captures.' }
else { Add-R 'Xbox Game DVR' 'Tắt' 'OK' }

$hags = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers').HwSchMode
$hagsS = switch ($hags) { 2 { 'Bật' } 1 { 'Tắt' } default { 'Mặc định' } }
Add-R 'HAGS (GPU scheduling)' $hagsS 'INFO' 'Thử bật/tắt trong Settings > Display > Graphics để so sánh.'

$dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard
if ($dg -and $dg.SecurityServicesRunning -contains 2) {
    Add-R 'Memory Integrity (HVCI)' 'Đang chạy' 'WARN' 'Giảm FPS 5-15%. Tắt: Windows Security > Device security > Core isolation. (Valorant/Vanguard có thể yêu cầu bật.)'
} elseif ($dg -and $dg.VirtualizationBasedSecurityStatus -eq 2) {
    Add-R 'VBS' 'Đang chạy (không có HVCI)' 'INFO'
} else { Add-R 'Memory Integrity (HVCI)' 'Tắt' 'OK' }

$pf = @(Get-CimInstance Win32_PageFileUsage)
if ($pf.Count -eq 0 -and -not $cs.AutomaticManagedPagefile) { Add-R 'Pagefile' 'Đã tắt' 'WARN' 'Tắt pagefile có thể gây crash/giật. Để System managed.' }
else { Add-R 'Pagefile' (($pf | ForEach-Object { "$($_.Name) $($_.AllocatedBaseSize)MB" }) -join ', ') 'OK' }

$ms = (Get-ItemProperty 'HKCU:\Control Panel\Mouse').MouseSpeed
if ($ms -eq '1') { Add-R 'Mouse acceleration' 'Bật (Enhance pointer precision)' 'WARN' 'Game FPS nên tắt: main.cpl > Pointer Options.' }
else { Add-R 'Mouse acceleration' 'Tắt' 'OK' }

$av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | Select-Object -ExpandProperty displayName -Unique)
if ($av.Count -gt 1) { Add-R 'Antivirus' ($av -join ', ') 'WARN' 'Nhiều phần mềm diệt virus cùng lúc gây chậm. Giữ 1 cái.' }
elseif ($av.Count -eq 1) { Add-R 'Antivirus' $av[0] 'OK' }

# ------------------------------------------------------------------ RAM
Section 'RAM'
$mods = @(Get-CimInstance Win32_PhysicalMemory)
$totalGB = [math]::Round((($mods | Measure-Object Capacity -Sum).Sum) / 1GB)
$memType = switch ($mods[0].SMBIOSMemoryType) { 24 { 'DDR3' } 26 { 'DDR4' } 34 { 'DDR5' } 30 { 'LPDDR4' } 35 { 'LPDDR5' } default { 'DDR?' } }
$cfg = ($mods | Measure-Object ConfiguredClockSpeed -Minimum).Minimum
$rated = ($mods | Measure-Object Speed -Maximum).Maximum

foreach ($m in $mods) {
    Add-R "Thanh $($m.DeviceLocator)" ("{0} GB {1} {2} - {3}" -f [math]::Round($m.Capacity / 1GB), $memType, $m.Manufacturer, "$($m.PartNumber)".Trim())
}
if ($totalGB -lt 16) { Add-R 'Dung lượng' "$totalGB GB" 'WARN' 'Game hiện nay nên có tối thiểu 16GB.' } else { Add-R 'Dung lượng' "$totalGB GB" 'OK' }

if ($mods.Count -eq 1) { Add-R 'Kênh (channel)' 'Single channel (1 thanh)' 'WARN' 'Chạy 1 thanh RAM mất ~30-50% băng thông, 1% low tụt mạnh. Nên chạy 2 thanh.' }
else { Add-R 'Kênh (channel)' "$($mods.Count) thanh" 'OK' }

$xmpName = 'XMP/DOCP/EXPO'
$speedStatus = 'OK'; $speedAdv = ''
switch -regex ($memType) {
    'DDR4' { if ($cfg -le 2400) { $speedStatus = 'BAD' } elseif ($cfg -le 2666) { $speedStatus = 'WARN' } }
    'DDR5' { if ($cfg -le 4800) { $speedStatus = 'WARN' } }
    'DDR3' { if ($cfg -le 1333) { $speedStatus = 'WARN' } }
}
if ($speedStatus -ne 'OK') {
    $speedAdv = "Tốc độ thấp, nhiều khả năng chưa bật $xmpName trong BIOS. Nếu RAM không hỗ trợ thì nên nâng cấp RAM nhanh hơn."
    if ($isLaptop) { $speedAdv += ' (Laptop thường không chỉnh được.)' }
}
if ($rated -gt $cfg) { $speedStatus = 'WARN'; $speedAdv = "RAM hỗ trợ $rated MT/s nhưng đang chạy $cfg. Bật $xmpName trong BIOS." }
Add-R 'Tốc độ RAM' "$cfg MT/s" $speedStatus $speedAdv

if (@($mods | Select-Object -ExpandProperty PartNumber -Unique).Count -gt 1) { Add-R 'Đồng bộ' 'Các thanh RAM khác mã' 'WARN' 'RAM khác loại dễ phải chạy tốc độ thấp hoặc không ổn định khi bật XMP.' }

$usedPct = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
if ($usedPct -gt 80) { Add-R 'RAM đang dùng' "$usedPct%" 'WARN' 'RAM gần đầy trước khi vào game. Tắt bớt app nền.' } else { Add-R 'RAM đang dùng' "$usedPct%" 'OK' }

# ------------------------------------------------------------------ GPU
Section 'Card đồ họa'
$allGpu = @(Get-CimInstance Win32_VideoController)
$isVirtual = { param($g) $g.Name -match 'Parsec|Virtual|Remote|Basic Display|Meta|Citrix|Mirage|DisplayLink|Idd|Spacedesk|Splashtop|Moonlight|Sunshine' }
$isDiscrete = { param($g) ($g.Name -match 'NVIDIA') -or ($g.Name -match 'Radeon.*(RX|Pro)\s') -or ($g.Name -match 'Arc\(TM\)\s*[AB]\d') }
$dGpus = @($allGpu | Where-Object { (& $isDiscrete $_) })

foreach ($g in $allGpu) {
    if (& $isVirtual $g) { Add-R 'Card ảo' $g.Name 'WARN' 'Driver màn hình ảo (Parsec, remote...) đôi khi gây lỗi frame pacing. Gỡ nếu không dùng.'; continue }
    $ver = $g.DriverVersion
    if ($g.Name -match 'NVIDIA') { $d = ($ver -replace '\.', ''); $ver = "$ver (" + $d.Substring($d.Length - 5, 3) + '.' + $d.Substring($d.Length - 2) + ')' }
    $age = if ($g.DriverDate) { [int]((Get-Date) - $g.DriverDate).TotalDays } else { 0 }
    $txt = "$($g.Name) - driver $ver, $($g.DriverDate.ToString('dd/MM/yyyy'))"
    if ((& $isDiscrete $g) -and $age -gt 180) { Add-R 'GPU' $txt 'WARN' "Driver đã cũ $age ngày. Cập nhật driver mới." } else { Add-R 'GPU' $txt 'OK' }
}

$active = @($allGpu | Where-Object { $_.CurrentRefreshRate -gt 0 -and -not (& $isVirtual $_) })
foreach ($a in $active) {
    $res = "$($a.CurrentHorizontalResolution)x$($a.CurrentVerticalResolution) @ $($a.CurrentRefreshRate)Hz trên $($a.Name)"
    if ($a.CurrentRefreshRate -le 60) { Add-R 'Màn hình' $res 'WARN' 'Đang 60Hz. Nếu màn hình hỗ trợ 144/165/240Hz hãy chỉnh: Settings > Display > Advanced display. Kiểm tra cả dây (nên dùng DisplayPort).' }
    else { Add-R 'Màn hình' $res 'OK' }
}
if ($dGpus.Count -gt 0 -and -not $isLaptop -and $active.Count -gt 0 -and -not ($active | Where-Object { & $isDiscrete $_ })) {
    Add-R 'Cổng màn hình' 'Đang cắm vào cổng ONBOARD của mainboard' 'BAD' 'Dây màn hình phải cắm vào cổng của card rời (cổng nằm ngang phía dưới), không phải cổng trên mainboard!'
}

$smi = "$env:WINDIR\System32\nvidia-smi.exe"
if (-not (Test-Path $smi)) { $smi = (Get-Command nvidia-smi).Source }
if ($smi -and (Test-Path $smi)) {
    $q = & $smi --query-gpu=name,temperature.gpu,power.limit,power.default_limit,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv,noheader,nounits
    foreach ($line in @($q)) {
        $f = $line -split ',\s*'
        if ($f.Count -lt 7) { continue }
        $temp = [int]$f[1]
        if ($temp -gt 83) { Add-R 'Nhiệt độ GPU (lúc đo)' "$temp°C" 'WARN' 'GPU nóng ngay cả khi không tải nặng. Vệ sinh, kiểm tra quạt/airflow.' } else { Add-R 'Nhiệt độ GPU (lúc đo)' "$temp°C" 'OK' }
        $pl = [double]$f[2]; $pd = [double]$f[3]
        if ($pd -gt 0 -and $pl -lt $pd * 0.9) { Add-R 'Giới hạn điện GPU' "$pl W / mặc định $pd W" 'WARN' 'Power limit bị hạ (Afterburner/phần mềm hãng). Đưa về mặc định.' }
        elseif ($pd -gt 0) { Add-R 'Giới hạn điện GPU' "$pl W" 'OK' }
        $wc = [int]$f[5]; $wm = [int]$f[6]
        if ($wc -lt $wm) { Add-R 'PCIe' "Gen$($f[4]) x$wc (tối đa x$wm)" 'WARN' 'Card không chạy đủ băng thông. Kiểm tra khe cắm (khe trên cùng), riser, bụi bẩn.' }
        else { Add-R 'PCIe' "Gen$($f[4]) x$wc" 'OK' }
    }
}

# ------------------------------------------------------------------ Ổ CỨNG
Section 'Ổ cứng'
$pds = @(Get-PhysicalDisk)
foreach ($d in $pds) {
    $rc = if ($isAdmin) { $d | Get-StorageReliabilityCounter } else { $null }
    $txt = "{0} - {1} {2}, {3:N0} GB" -f $d.FriendlyName, $d.MediaType, $d.BusType, ($d.Size / 1GB)
    if ($rc -and $rc.Temperature) { $txt += ", $($rc.Temperature)°C" }
    if ($d.HealthStatus -ne 'Healthy') { Add-R 'Ổ đĩa' $txt 'BAD' "Tình trạng: $($d.HealthStatus). Sao lưu dữ liệu ngay!" }
    elseif ($rc -and $rc.Temperature -gt 70) { Add-R 'Ổ đĩa' $txt 'WARN' 'Ổ quá nóng, dễ bị hạ tốc độ.' }
    elseif ($d.MediaType -eq 'HDD') { Add-R 'Ổ đĩa' $txt 'INFO' 'Ổ HDD: không nên cài game lên ổ này.' }
    else { Add-R 'Ổ đĩa' $txt 'OK' }
}
foreach ($v in Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.Size -gt 0 }) {
    $freeGB = [math]::Round($v.SizeRemaining / 1GB, 1); $pct = [math]::Round($v.SizeRemaining / $v.Size * 100)
    $txt = "$freeGB GB trống ($pct%)"
    if ($pct -lt 10 -or ($v.DriveLetter -eq 'C' -and $freeGB -lt 20)) { Add-R "Ổ $($v.DriveLetter):" $txt 'WARN' 'Ổ gần đầy. Dọn bớt (SSD đầy sẽ chậm).' } else { Add-R "Ổ $($v.DriveLetter):" $txt 'OK' }
}

function Get-DriveMedia($letter) {
    $part = Get-Partition -DriveLetter $letter
    if (-not $part) { return $null }
    Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "$($part.DiskNumber)" } | Select-Object -First 1
}
$steamPath = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
if ($steamPath) {
    $vdf = Join-Path ($steamPath -replace '/', '\') 'steamapps\libraryfolders.vdf'
    foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"')) {
        $lib = $m.Matches[0].Groups[1].Value -replace '\\\\', '\'
        if (-not (Test-Path $lib)) { continue }
        $pd = Get-DriveMedia $lib.Substring(0, 1)
        $mt = if ($pd) { "$($pd.MediaType)" } else { '?' }
        if ($mt -eq 'HDD') { Add-R 'Thư viện Steam' "$lib (HDD)" 'WARN' 'Game trên HDD sẽ giật khi load map/texture. Chuyển sang SSD.' }
        else { Add-R 'Thư viện Steam' "$lib ($mt)" 'OK' }
    }
}

# ------------------------------------------------------------------ CHẠY NỀN (đo lúc máy rảnh)
Section 'Phần mềm chạy nền'
$known = [ordered]@{
    'Overwolf'                         = 'Overlay Overwolf'
    'Blitz'                            = 'Blitz (overlay)'
    'FxSound'                          = 'FxSound (xử lý âm thanh, hay làm audiodg ăn CPU)'
    'NVIDIA Overlay'                   = 'NVIDIA overlay'
    'wallpaper32|wallpaper64'          = 'Wallpaper Engine'
    'ArmouryCrate'                     = 'Armoury Crate'
    'iCUE'                             = 'Corsair iCUE'
    'NZXT CAM'                         = 'NZXT CAM'
    'SignalRgb'                        = 'SignalRGB'
    'Medal'                            = 'Medal (ghi clip)'
    'Outplayed'                        = 'Outplayed (ghi clip)'
    'qbittorrent|utorrent|BitTorrent'  = 'Torrent (chiếm mạng)'
    'Hamachi|Radmin|ZeroTier'          = 'VPN LAN ảo'
    'nordvpn|expressvpn|protonvpn'     = 'VPN'
}
$procs = Get-Process
$found = @()
foreach ($k in $known.Keys) { if ($procs | Where-Object { $_.ProcessName -match "^($k)" }) { $found += $known[$k] } }
if ($found.Count) { Add-R 'App nặng/overlay đang chạy' ($found -join '; ') 'WARN' 'Tắt các app này trước khi chơi game.' }
else { Add-R 'App nặng/overlay đang chạy' 'Không phát hiện' 'OK' }

Write-Host '  Đang đo CPU và độ trễ driver (5 giây)...' -ForegroundColor DarkGray
$snap = @{}; Get-Process | ForEach-Object { $snap[$_.Id] = $_.TotalProcessorTime.TotalSeconds }
$dpc = @(); $intr = @()
for ($i = 0; $i -lt 5; $i++) {
    Start-Sleep -Milliseconds 1000
    $p = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    if ($i -gt 0) { $dpc += [double]$p.PercentDPCTime; $intr += [double]$p.PercentInterruptTime }
}
$lp = [int]$env:NUMBER_OF_PROCESSORS
$top = Get-Process | Where-Object { $snap.ContainsKey($_.Id) -and $_.Id -ne $PID -and $_.ProcessName -ne 'Idle' } |
    ForEach-Object { [pscustomobject]@{ Name = $_.ProcessName; Pct = ($_.TotalProcessorTime.TotalSeconds - $snap[$_.Id]) / 5 / $lp * 100 } } |
    Group-Object Name | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Pct = ($_.Group | Measure-Object Pct -Sum).Sum } } |
    Sort-Object Pct -Descending | Select-Object -First 5
$busy = @($top | Where-Object { $_.Pct -ge 3 })
if ($busy.Count) { Add-R 'Tiến trình ăn CPU lúc rảnh' (($busy | ForEach-Object { "{0} {1:N1}%" -f $_.Name, $_.Pct }) -join ', ') 'WARN' 'Các tiến trình này đang dùng CPU khi máy không làm gì.' }
else { Add-R 'Tiến trình ăn CPU lúc rảnh' 'Không có' 'OK' }

$dpcA = ($dpc | Measure-Object -Average).Average; $intA = ($intr | Measure-Object -Average).Average
$txt = "DPC {0:N2}%, Interrupt {1:N2}%" -f $dpcA, $intA
if ($dpcA -gt 2 -or $intA -gt 2) { Add-R 'Độ trễ driver' $txt 'WARN' 'Cao bất thường: có driver gây giật. Dùng LatencyMon để tìm driver lỗi.' } else { Add-R 'Độ trễ driver' $txt 'OK' }

# ------------------------------------------------------------------ CPU (test tải)
Section 'CPU'
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Add-R 'CPU' ("{0} ({1} nhân / {2} luồng)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)

Write-Host '  Đang tạo tải CPU 6 giây để đo xung nhịp...' -ForegroundColor DarkGray
$workers = @()
for ($i = 0; $i -lt $lp; $i++) {
    $ps = [powershell]::Create()
    [void]$ps.AddScript('$e=[DateTime]::Now.AddSeconds(7); while([DateTime]::Now -lt $e){ $x=[math]::Sqrt(12345.678) }')
    $workers += [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
}
Start-Sleep -Seconds 2
# Dùng dữ liệu RAW (lớp Formatted trả số cũ/không chính xác; Get-Counter bị dịch tên theo ngôn ngữ Windows)
# Lấy nhân boost cao nhất: CPU Intel 12th+ có P-core/E-core, trung bình _Total bị E-core kéo xuống.
$cls = 'Win32_PerfRawData_Counters_ProcessorInformation'
$a = @{}; Get-CimInstance $cls | Where-Object { $_.Name -notmatch '_Total' } | ForEach-Object { $a[$_.Name] = $_ }
Start-Sleep -Seconds 4
$b = @(Get-CimInstance $cls | Where-Object { $_.Name -notmatch '_Total' })
foreach ($w in $workers) { try { $w.PS.Stop(); $w.PS.Dispose() } catch {} }

$best = $null
foreach ($x in $b) {
    $o = $a[$x.Name]; if (-not $o) { continue }
    $dB = [double]$x.PercentProcessorPerformance_Base - [double]$o.PercentProcessorPerformance_Base
    if ($dB -le 0) { continue }
    $pc = ([double]$x.PercentProcessorPerformance - [double]$o.PercentProcessorPerformance) / $dB
    $mhz = [double]$x.ProcessorFrequency * $pc / 100
    if (-not $best -or $mhz -gt $best.MHz) { $best = [pscustomobject]@{ MHz = $mhz; Pct = $pc; Base = [double]$x.ProcessorFrequency } }
}
if ($best) {
    $pAvg = $best.Pct; $base = $best.Base
    $txt = "{0:N2} GHz nhân cao nhất (xung cơ bản {1:N2} GHz, {2:N0}%)" -f ($best.MHz / 1000), ($base / 1000), $pAvg
    if ($pAvg -lt 90) { Add-R 'Xung nhịp khi tải' $txt 'BAD' 'CPU chạy DƯỚI xung cơ bản: kiểm tra power plan, nhiệt độ CPU (keo tản nhiệt, quạt), cài đặt BIOS.' }
    elseif ($pAvg -lt 100) { Add-R 'Xung nhịp khi tải' $txt 'WARN' 'CPU không boost được lên trên xung cơ bản: có thể do nhiệt, giới hạn điện (BIOS/phần mềm hãng) hoặc power plan.' }
    else { Add-R 'Xung nhịp khi tải' $txt 'OK' }
} else { Add-R 'Xung nhịp khi tải' 'Không đo được' 'INFO' }

$tz = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature | Select-Object -First 1
if ($tz -and $tz.CurrentTemperature -gt 0) {
    $t = [math]::Round($tz.CurrentTemperature / 10 - 273.15)
    Add-R 'Nhiệt độ (ACPI, tham khảo)' "$t°C" 'INFO' 'Chỉ mang tính tham khảo. Đo chính xác bằng HWiNFO.'
}

# ------------------------------------------------------------------ MẠNG
Section 'Mạng'
$nics = @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface })
foreach ($n in $nics) {
    $wifi = $n.PhysicalMediaType -match '802\.11|Wireless' -or $n.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN'
    $txt = "$($n.Name) - $($n.InterfaceDescription) ($($n.LinkSpeed))"
    if ($wifi) { Add-R 'Kết nối' $txt 'WARN' 'Đang dùng Wi-Fi: dễ ping giật/mất gói. Nên cắm dây LAN khi chơi game.' } else { Add-R 'Kết nối' $txt 'OK' }
}

if (-not $NoNetwork) {
    Write-Host '  Đang ping 1.1.1.1 (30 lần)...' -ForegroundColor DarkGray
    $pinger = New-Object System.Net.NetworkInformation.Ping
    $times = @(); $lost = 0
    for ($i = 0; $i -lt 30; $i++) {
        try { $pr = $pinger.Send('1.1.1.1', 1000); if ($pr.Status -eq 'Success') { $times += $pr.RoundtripTime } else { $lost++ } } catch { $lost++ }
        Start-Sleep -Milliseconds 100
    }
    if ($times.Count) {
        $avg = ($times | Measure-Object -Average).Average; $max = ($times | Measure-Object -Maximum).Maximum
        $jit = 0; for ($i = 1; $i -lt $times.Count; $i++) { $jit += [math]::Abs($times[$i] - $times[$i - 1]) }; if ($times.Count -gt 1) { $jit /= ($times.Count - 1) }
        $lossPct = [math]::Round($lost / 30 * 100)
        $txt = "TB {0:N0}ms, max {1}ms, jitter {2:N1}ms, mất gói {3}%" -f $avg, $max, $jit, $lossPct
        if ($lossPct -gt 0) { Add-R 'Ping' $txt 'BAD' 'Có mất gói: kiểm tra dây mạng, router, Wi-Fi, hoặc liên hệ nhà mạng.' }
        elseif ($jit -gt 10 -or $max -gt 150) { Add-R 'Ping' $txt 'WARN' 'Ping không ổn định: kiểm tra Wi-Fi, người khác dùng chung mạng, app tải ngầm.' }
        else { Add-R 'Ping' $txt 'OK' }
    } else { Add-R 'Ping' 'Không ping được 1.1.1.1' 'BAD' 'Không có Internet hoặc bị chặn ICMP.' }
}

# ------------------------------------------------------------------ TỔNG KẾT
$nBad = @($R | Where-Object Status -eq 'BAD').Count
$nWarn = @($R | Where-Object Status -eq 'WARN').Count
$score = [math]::Max(0, 100 - 15 * $nBad - 5 * $nWarn)
Write-Host "`n==============================================" -ForegroundColor White
Write-Host ("  ĐIỂM: {0}/100   |   LỖI: {1}   CHÚ Ý: {2}" -f $score, $nBad, $nWarn) -ForegroundColor $(if ($nBad) { 'Red' } elseif ($nWarn) { 'Yellow' } else { 'Green' })
Write-Host "==============================================" -ForegroundColor White

# ------------------------------------------------------------------ BÁO CÁO HTML
function E($s) { [System.Net.WebUtility]::HtmlEncode("$s") }
$rows = New-Object System.Text.StringBuilder
foreach ($grp in ($R | Group-Object Group)) {
    [void]$rows.Append("<tr class='g'><td colspan='4'>$(E $grp.Name)</td></tr>")
    foreach ($x in $grp.Group) {
        $adv = if ($x.Status -ne 'OK') { E $x.Advice } else { '' }
        [void]$rows.Append("<tr><td><span class='b $($x.Status)'>$(E $Label[$x.Status])</span></td><td>$(E $x.Item)</td><td>$(E $x.Value)</td><td class='a'>$adv</td></tr>")
    }
}
$scoreCls = if ($nBad) { 'BAD' } elseif ($nWarn) { 'WARN' } else { 'OK' }
$html = @"
<!doctype html><html lang="vi"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PC Check - $(E $env:COMPUTERNAME)</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--fg:#1d2330;--mute:#667085;--line:#e4e7ec;--g:#f0f2f5;--ok:#12805c;--warn:#b25e09;--bad:#c4320a;--info:#667085}
@media (prefers-color-scheme:dark){:root{--bg:#111418;--card:#1a1e24;--fg:#e6e9ef;--mute:#98a2b3;--line:#2a3039;--g:#222831;--ok:#3ccb8f;--warn:#f5a524;--bad:#f97066;--info:#98a2b3}}
body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.5 "Segoe UI",system-ui,sans-serif}
.w{max-width:1100px;margin:0 auto;padding:24px 16px}
h1{font-size:22px;margin:0 0 4px}.m{color:var(--mute);margin-bottom:16px}
.s{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:16px}.s div{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px 16px}
.s b{display:block;font-size:24px}
table{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
td{padding:8px 10px;border-top:1px solid var(--line);vertical-align:top}
tr.g td{background:var(--g);font-weight:600}
.a{color:var(--mute)}
.b{display:inline-block;min-width:52px;text-align:center;border-radius:6px;padding:1px 6px;font-size:12px;font-weight:600;border:1px solid currentColor}
.OK{color:var(--ok)}.WARN{color:var(--warn)}.BAD{color:var(--bad)}.INFO{color:var(--info)}
@media (max-width:700px){td:nth-child(4){display:none}}
</style></head><body><div class="w">
<h1>PC Gaming Health Check</h1>
<div class="m">$(E $env:COMPUTERNAME) &middot; $(Get-Date -Format 'dd/MM/yyyy HH:mm') &middot; $(if ($isAdmin) { 'Admin' } else { 'Không có quyền Admin (thiếu một số mục)' })</div>
<div class="s"><div>Điểm<b class="$scoreCls">$score/100</b></div><div>Lỗi<b class="BAD">$nBad</b></div><div>Chú ý<b class="WARN">$nWarn</b></div></div>
<table>$($rows.ToString())</table>
<p class="m">Tool chỉ đọc thông tin, không thay đổi cài đặt. Điểm số mang tính tham khảo.</p>
</div></body></html>
"@
$desk = [Environment]::GetFolderPath('Desktop')
$out = Join-Path $desk ("PCCheck_{0}_{1}.html" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd_HHmm'))
[IO.File]::WriteAllText($out, $html, (New-Object Text.UTF8Encoding $false))
Write-Host "`nĐã lưu báo cáo: $out" -ForegroundColor Cyan
if (-not $NoOpen) { Start-Process $out }
