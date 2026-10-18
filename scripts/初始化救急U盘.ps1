<#
.SYNOPSIS
  初始化「救急U盘」目录结构。默认非破坏性：只建目录、写说明、检查缺失项，不移动任何现有文件。

.DESCRIPTION
  - 建立 00_说明 ~ 09_硬件检测 的标准目录
  - 在根目录建立名为 autorun.inf 的文件夹（只读+隐藏+系统），用于免疫 U 盘传播型病毒
  - 生成 00_说明 下的 README.txt、救急流程卡.txt、机器配置单.txt、缺失项.txt
  - -Organize 把根目录下已识别的工具移动到对应子目录（先用 -WhatIfOnly 预览）
  - -HashAll 为盘内所有文件生成 00_说明\哈希台账.csv

.EXAMPLE
  .\初始化救急U盘.ps1 -Root E:\

.EXAMPLE
  .\初始化救急U盘.ps1 -Root E:\ -Organize -WhatIfOnly

.EXAMPLE
  .\初始化救急U盘.ps1 -Root E:\ -Organize -HashAll
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [switch]$Organize,
    [switch]$HashAll,
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'

# ---------- 基本检查 ----------
if (-not (Test-Path -LiteralPath $Root)) { throw ("路径不存在：" + $Root) }
$Root = (Resolve-Path -LiteralPath $Root).Path
if (-not $Root.EndsWith('\')) { $Root = $Root + '\' }
$rootDisplay = $Root.TrimEnd('\')
if ($Root -eq ($env:SystemDrive + '\')) { throw ("拒绝在系统盘根目录执行：" + $rootDisplay) }
if ($Root -match '^[A-Za-z]:\\Windows') { throw "拒绝在 Windows 目录执行" }

$utf8bom = New-Object System.Text.UTF8Encoding($true)
function Write-Utf8 {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, $script:utf8bom)
}

# ---------- 1. 目录结构 ----------
$dirs = @(
    '00_说明',
    '01_PE',
    '02_系统镜像',
    '03_驱动',
    '04_运行库',
    '05_磁盘数据',
    '06_杀毒排查',
    '07_系统修复',
    '08_便携工具',
    '09_硬件检测'
)
foreach ($d in $dirs) {
    $p = Join-Path $Root $d
    if (-not (Test-Path -LiteralPath $p)) {
        if ($WhatIfOnly) { "[预览] 创建目录 " + $d }
        else { New-Item -ItemType Directory -Path $p | Out-Null; "创建目录 " + $d }
    }
}

# ---------- 1.5 个人文件目录（与救急工具共存） ----------
$personalDir = Join-Path $Root '_个人'
if (-not $WhatIfOnly) {
    if (-not (Test-Path -LiteralPath $personalDir)) {
        New-Item -ItemType Directory -Path $personalDir | Out-Null
        $note = @'
这个目录用来放个人文件（与救急工具共存）。

规则：
  1. 个人文件统一放这里，不要散落在根目录，急起来容易误操作
  2. 初始化脚本的 -Organize 只归位识别出的工具，不会动这个目录
  3. 借给别人修电脑之前，先加密或整个移走（BitLocker To Go / VeraCrypt）
  4. 不要把「唯一一份」的重要资料放在 U 盘上，U 盘会丢、会坏
  5. 做数据恢复时，不要把数据恢复保存到这个盘
'@
        Write-Utf8 (Join-Path $personalDir '请读我.txt') $note
        '创建 _个人 目录'
    }
}
else {
    if (-not (Test-Path -LiteralPath $personalDir)) { '[预览] 创建 _个人 目录' }
}

# ---------- 2. autorun.inf 免疫 ----------
$autoPath = Join-Path $Root 'autorun.inf'
if (Test-Path -LiteralPath $autoPath) {
    $it = Get-Item -LiteralPath $autoPath -Force
    if ($it.PSIsContainer) {
        try {
            $it.Attributes = [System.IO.FileAttributes]::ReadOnly -bor [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System -bor [System.IO.FileAttributes]::Directory
        }
        catch { }
        'autorun.inf 免疫文件夹已存在，已确保只读/隐藏/系统属性'
    }
    else {
        '警告：根目录已存在同名 autorun.inf 文件，未做处理，请人工确认内容'
    }
}
else {
    if ($WhatIfOnly) { '[预览] 创建 autorun.inf 免疫文件夹' }
    else {
        New-Item -ItemType Directory -Path $autoPath | Out-Null
        (Get-Item -LiteralPath $autoPath -Force).Attributes = 'ReadOnly, Hidden, System, Directory'
        '创建 autorun.inf 免疫文件夹（只读/隐藏/系统）'
    }
}

# ---------- 3~4. 说明文档与机器配置单（预览模式跳过） ----------
if (-not $WhatIfOnly) {

    $readme = @'
==================== 救急 U 盘 使用说明 ====================

【分发与免责】
  本盘由 Cavalei 整理分发。仅以本人给出的版本为准，
  其他来源的拷贝请自行判断，详见 00_说明\免责声明.txt
【这个盘是干什么的】
  电脑开不了机、系统崩了、硬盘出问题、疑似中毒时的自救工具盘。
  核心原则：能不动原盘就不动；要恢复数据，先把原盘只读镜像出来。

【怎么启动】
  1) 关机，插上 U 盘
  2) 开机时连按启动菜单键（品牌不同：F12 / F11 / F8 / Esc / F7）
  3) 选择 U 盘（UEFI 前缀的那一项优先）
  4) 进入 Ventoy 菜单，选 PE 或工具 ISO
  老机器若无 UEFI 项，选不带 UEFI 的那一项（Legacy/CSM）。
  BIOS 里若开了 Secure Boot 且无法启动，可临时关闭，或用 Ventoy 的 MOK 注册。

【目录说明】
  00_说明     本文件、流程卡、机器配置单、哈希台账
  01_PE       启动盘镜像（Ventoy 直接识别 ISO）
  02_系统镜像  原版 Windows ISO
  03_驱动      网卡 / 芯片组 / Intel RST / NVMe 离线驱动
  04_运行库    7-Zip、VC++、.NET、DirectX
  05_磁盘数据  DiskGenius、TestDisk/PhotoRec、ddrescue
  06_杀毒排查  360急救箱、银狐专杀、Autoruns、可启动杀毒 ISO
  07_系统修复  Dism++、Bootice、引导修复
  08_便携工具  Everything、卸载器、下载器、TXT 阅读器、哈希校验
  09_硬件检测  图吧工具箱、CrystalDiskInfo、MemTest

【个人文件放哪里（这个盘同时存别的东西）】
  统一放根目录的 _个人\ ，不要散在根目录。
  - 脚本的 -Organize 只归位识别出的工具，不会动 _个人\
  - 借给别人修电脑前，先把 _个人\ 加密或整个移走：
      BitLocker To Go（右键驱动器 -> 启用 BitLocker）或 VeraCrypt 容器
  - 不要把「唯一一份」的重要资料放这个盘，U 盘会丢、会坏
  - 做数据恢复时，不要恢复到这张盘
  - 更稳的做法是分两个区：救急区 + 个人区，物理隔开

【怎么复制到另一张盘（分发用）】
  这张盘的价值在于可复制：23.9 GB 能塞进 32 GB 的盘。

  步骤：
    1. 新盘先装 Ventoy（选项：MBR + 勾选“安全启动支持”）
    2. 把本盘里除 _个人\ 之外的所有目录，复制到新盘的数据分区
    3. 完成。所有路径都是相对的，换个盘符照样能用

  注意：
    - 不要复制 _个人\（个人文件，体积大也不该外传）
    - 复制前后都不需要改任何配置
    - 新盘首次在某台电脑启动，同样要注册一次密钥（见上面排查段）
    - 想复制快一点，可以在命令行用 robocopy：
        robocopy F:\ E:\ /E /XD "_个人" "System Volume Information" /MT:8
      （F: 是源盘，E: 是新盘）
【自建工具（本盘特有，其他盘不会有）】
  08_便携工具\TXT阅读器\TxtReader.exe        v1.2.0.0
      TXT 小说阅读器，单文件免安装
      按键：←/→ 翻页 · Ctrl+D 夜间模式 · Ctrl+T 目录 · Ctrl+加减号 字号 · F11 全屏
      会在同目录生成 TxtReader.ini 保存阅读进度，属正常现象

  08_便携工具\哈希校验\HashChecker.exe       v1.0.0.0
      图形界面：拖入文件，粘贴参考哈希即可比对
  08_便携工具\哈希校验\HashChecker-cli.exe   v1.0.0.0
      命令行：单个文件 --check，整盘核对 --ledger
      例：HashChecker-cli.exe --ledger "F:\00_说明\哈希台账.csv" "F:\"

  核对方式：以上工具的哈希都记在 00_说明\哈希台账.csv 里，
            用 HashChecker 或 certutil 对比，即可确认有没有被替换。
                 certutil -hashfile "文件路径" SHA256
【三条铁律】
  1. 数据恢复期间，绝对不要往故障盘写任何东西（包括"修复"操作）
  2. 不确定的时候先做整盘镜像，再在镜像上折腾
  3. 破解/绿化类工具只用于自己的设备；给别人修机器注意授权与合规

【重要提醒】
  - 如果系统盘开了 BitLocker，PE 里看不到分区，需要恢复密钥（manage-bde -status 可查状态）
  - 工具版本会过期，建议每 3~6 个月检查一次更新
  - 首次在开了安全启动的电脑上使用，需要注册一次密钥（见“救急流程卡”最后的排查段）\n  - 每次更新工具后，重新运行根目录的初始化脚本刷新哈希台账
=============================================================
'@
    Write-Utf8 (Join-Path $Root '00_说明\README.txt') $readme

    $flow = @'
================= 救 急 流 程 卡 =================

【第 0 步：先判断，别急着动手】
  □ 盘里的数据重要吗？
      重要 -> 立刻停止一切写入，先进 PE 做只读镜像
      不重要 -> 可以直接修
  □ 是硬件问题还是软件问题？
      听到异响 / 不认盘 / SMART 报红 -> 按硬件故障处理

【场景 A：开不了机 / 蓝屏 / 引导损坏】
  1. U 盘启动进 PE
  2. 先确认能不能看到系统盘（看不到 -> 驱动或 BitLocker 问题，见 D）
  3. 能进 PE 但进不去系统 -> 先备份重要文件，再修引导
  4. 修引导优先级：Dism++ 的"引导修复" > bcdboot > bootrec
  5. 修不好再考虑"保留数据重装"

【场景 B：误删 / 格式化 / 分区丢失】
  1. 立刻停止对该盘的一切写入
  2. DiskGenius 先"备份分区表"，再尝试恢复文件
  3. 分区表乱了 -> TestDisk 重建
  4. 文件系统级恢复 -> PhotoRec（按文件签名找回，不看分区表）
  5. 目标文件一定恢复到【另一块盘】

【场景 C：硬盘有坏道 / 读取困难】
  1. 不要用 DiskGenius 直接扫故障盘反复读
  2. Linux Live（SystemRescue）下用 ddrescue 做整盘镜像，跳过错误块
  3. 在镜像文件上做恢复，原盘只读挂载
  4. 实在救不回，考虑开盘（专业机构）

【场景 D：PE 里看不到硬盘】
  - 新笔记本常见：BIOS 里存储模式是 Intel RST / RAID
  - 解决：PE 里注入 RST 驱动，或临时改 AHCI（改之前确认不会破坏引导）
  - 另一种：BitLocker 加密，需要恢复密钥

【场景 E：疑似中毒但系统还能进】
  1. 先断网
  2. Autoruns 看自启项（重点：无签名、路径在 Temp/AppData 的）
  3. Process Hacker 看进程树和网络连接
  4. 360急救箱 / 银狐专杀 跑一遍
  5. 清不掉 -> 进 PE 用可启动杀毒 ISO 离线扫

【场景 F：中毒后系统已经进不去】
  用 ESET SysRescue / Kaspersky Rescue Disk 启动离线查杀，
  同时用 PE 把重要文件拷出来（注意：拷出来的文件可能带毒）

【U 盘启动不了？】
  症状 1：ERROR / Verification failed: (0x1A) Security Violation
    → 这台电脑的安全启动还不信任 Ventoy，首次使用要注册一次密钥：
       1. 报错页按 Enter
       2. "Shim UEFI key management" 的 7 秒倒计时内按任意键
       3. 选 Enroll key from disk（不要选 Continue boot）
       4. 选 VTOYEFI 分区（U 盘上那个 32MB 的，没有盘符）
       5. 选 ENROLL_THIS_KEY_IN_MOKMANAGER.cer
       6. Continue → Yes → Enroll → Reboot
       7. 再次启动，直接进 Ventoy 菜单
       每台电脑只需做一次；换机器要重做
    备选：BIOS（F2）里把 Secure Boot 设成 Disabled，但别人机器上通常改不了

  症状 2：启动菜单里找不到 U 盘
    → 换 USB 口（直连，别用扩展坞）/ 长按电源强制关机再开
    → 确认 BIOS 里 Boot Mode 是 UEFI、Fast Boot 关闭
    → 机械革命等机型：启动菜单键常是 F7 而不是 F12
【常用命令速查】
  系统文件修复   sfc /scannow
  组件库修复     DISM /Online /Cleanup-Image /RestoreHealth
  引导重建       bootrec /fixmbr /fixboot /rebuildbcd
  UEFI 引导      bcdboot C:\Windows /s S: /f UEFI
  磁盘只读       diskpart -> list disk -> select disk N -> attributes disk set readonly
  磁盘检查       chkdsk C: /f /r
  BitLocker      manage-bde -status  /  manage-bde -unlock D: -RecoveryPassword 密钥
  看硬盘型号     Get-PhysicalDisk | Format-List FriendlyName,SerialNumber,HealthStatus
=================================================
'@
    Write-Utf8 (Join-Path $Root '00_说明\救急流程卡.txt') $flow
    '生成 README.txt / 救急流程卡.txt'

    # ---------- 4. 机器配置单 ----------
    $info = [ordered]@{ Model = ''; Serial = ''; Bios = ''; Cpu = ''; Ram = ''; Os = ''; Build = ''; Install = '' }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $info.Model = ($cs.Manufacturer + ' ' + $cs.Model).Trim()
        $info.Ram = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    }
    catch { }
    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $info.Serial = $bios.SerialNumber
        $info.Bios = $bios.SMBIOSBIOSVersion
    }
    catch { }
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $info.Cpu = $cpu.Name
    }
    catch { }
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $info.Os = $os.Caption
        $info.Build = $os.BuildNumber
        $info.Install = $os.InstallDate
    }
    catch { }

    # CIM 被安全策略拦截时，退回注册表读取（不需要管理员权限）
    if (-not $info.Model -or -not $info.Bios) {
        try {
            $k = Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS' -ErrorAction Stop
            if (-not $info.Model) { $info.Model = ($k.SystemManufacturer + ' ' + $k.SystemProductName).Trim() }
            if (-not $info.Bios) { $info.Bios = $k.BIOSVersion }
            if (-not $info.Serial) { $info.Serial = $k.SystemSerialNumber }
        }
        catch { }
    }
    if (-not $info.Cpu) {
        try {
            $k = Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction Stop
            $info.Cpu = $k.ProcessorNameString
        }
        catch { }
    }
    if (-not $info.Os) {
        try {
            $k = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
            $info.Os = $k.ProductName
            if ([int]$k.CurrentBuild -ge 22000) { $info.Os = $info.Os -replace 'Windows 10', 'Windows 11' }
            $info.Build = $k.CurrentBuild
            if ($k.InstallDate -is [int] -or $k.InstallDate -is [long]) { $info.Install = [DateTimeOffset]::FromUnixTimeSeconds([int64]$k.InstallDate).LocalDateTime.ToString('yyyy-MM-dd HH:mm:ss') } else { $info.Install = $k.InstallDate }
        }
        catch { }
    }

    $show = { param($v) if ([string]::IsNullOrWhiteSpace([string]$v)) { '（未取到）' } else { [string]$v } }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('============ 本机配置单（救急时省时间用） ============')
    $lines.Add('生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $lines.Add('')
    $lines.Add('机型    ：' + (& $show $info.Model))
    $lines.Add('序列号  ：' + (& $show $info.Serial))
    $lines.Add('BIOS    ：' + (& $show $info.Bios))
    $lines.Add('CPU     ：' + (& $show $info.Cpu))
    if ($info.Ram) { $lines.Add('内存    ：' + $info.Ram + ' GB') } else { $lines.Add('内存    ：（未取到，可手动填写）') }
    $lines.Add('系统    ：' + (& $show $info.Os) + '  Build ' + (& $show $info.Build))
    $lines.Add('安装时间：' + (& $show $info.Install))
    $lines.Add('')

    $lines.Add('硬盘：')
    $gotDisk = $false
    try {
        Get-CimInstance Win32_DiskDrive -ErrorAction Stop | ForEach-Object {
            $gotDisk = $true
            $lines.Add('  - ' + $_.Model + '  ' + [math]::Round($_.Size / 1GB, 0) + ' GB  序列号=' + $_.SerialNumber)
        }
    }
    catch { }
    if (-not $gotDisk) {
        try {
            Get-Disk -ErrorAction Stop | ForEach-Object {
                $gotDisk = $true
                $lines.Add('  - ' + $_.FriendlyName + '  ' + [math]::Round($_.Size / 1GB, 0) + ' GB  序列号=' + $_.SerialNumber + '  健康=' + $_.HealthStatus)
            }
        }
        catch { }
    }
    if (-not $gotDisk) { $lines.Add('  （未取到，可手动填写）') }

    $lines.Add('')
    $lines.Add('分区/卷：')
    $gotVol = $false
    try {
        Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | ForEach-Object {
            $gotVol = $true
            $lines.Add('  ' + $_.DriveLetter + ':  ' + $_.FileSystem + '  ' + [math]::Round($_.Size / 1GB, 1) + ' GB  剩余 ' + [math]::Round($_.SizeRemaining / 1GB, 1) + ' GB  ' + $_.FileSystemLabel)
        }
    }
    catch { }
    if (-not $gotVol) { $lines.Add('  （未取到，可手动填写）') }

    $lines.Add('')
    $lines.Add('BitLocker（需要管理员权限才能查全）：')
    try {
        $bde = manage-bde -status 2>$null
        if ($bde) { $bde | ForEach-Object { $lines.Add('  ' + $_) } }
        else { $lines.Add('  （无输出，请以管理员身份运行 manage-bde -status）') }
    }
    catch { $lines.Add('  （无法读取，请以管理员身份运行 manage-bde -status）') }

    $lines.Add('')
    $lines.Add('提醒：如果开了 BitLocker，务必把恢复密钥另存一份（云账户/纸质），')
    $lines.Add('      否则 PE 下看不到系统盘，救急盘也救不了。')
    $lines.Add('=====================================================')
    Write-Utf8 (Join-Path $Root '00_说明\机器配置单.txt') ($lines -join "`r`n")
    '生成 机器配置单.txt'
}

# ---------- 5. -Organize：把已知工具归位 ----------
if ($Organize) {
    $map = @(
        @{ p = 'DiskGenius';            d = '05_磁盘数据' },
        @{ p = '*DiskGenius*';          d = '05_磁盘数据' },
        @{ p = '*360病毒急救箱*';        d = '06_杀毒排查' },
        @{ p = '*Silverfox*';           d = '06_杀毒排查' },
        @{ p = '*DirectX修复*';          d = '04_运行库' },
        @{ p = 'Office Tool';           d = '08_便携工具' },
        @{ p = '*Everything*';          d = '08_便携工具' },
        @{ p = '*Geek*';                d = '08_便携工具' },
        @{ p = '*FreeDownloadManager*'; d = '08_便携工具' },
        @{ p = '*Md5检查器*';            d = '08_便携工具' },
        @{ p = '*压缩包密码恢复*';        d = '08_便携工具' },
        @{ p = '*图吧工具箱*';            d = '09_硬件检测' },
        @{ p = '*显卡对应驱动*';          d = '03_驱动' }
    )

    $skip = @('00_说明', '_个人', '01_PE', '02_系统镜像', '03_驱动', '04_运行库',
        '05_磁盘数据', '06_杀毒排查', '07_系统修复', '08_便携工具', '09_硬件检测',
        'autorun.inf', 'System Volume Information', '$RECYCLE.BIN', '.Trash-1000')

    $items = Get-ChildItem -LiteralPath $Root -Force | Where-Object { $skip -notcontains $_.Name }
    foreach ($it in $items) {
        $matched = $null
        foreach ($m in $map) {
            if ($it.Name -like $m.p) { $matched = $m; break }
        }
        if ($matched) {
            $destDir = Join-Path $Root $matched.d
            $dest = Join-Path $destDir $it.Name
            if (Test-Path -LiteralPath $dest) { "跳过（目标已存在）：" + $it.Name; continue }
            if ($WhatIfOnly) { "[预览] 移动 " + $it.Name + " -> " + $matched.d + "\" }
            else {
                Move-Item -LiteralPath $it.FullName -Destination $destDir
                "移动 " + $it.Name + " -> " + $matched.d + "\"
            }
        }
        else {
            "未识别，保持原位：" + $it.Name
        }
    }
}

# ---------- 6. 缺失项检查 ----------
$expect = @(
    @{ path = '01_PE\*PE*.iso';          name = 'PE 启动镜像（微PE / FirPE / Edgeless）'; pri = 'P0'; how = '官网下载 ISO，直接放进 01_PE' },
    @{ path = '02_系统镜像\*Windows10*.iso';   name = 'Windows 10 原版 ISO';                    pri = 'P0'; how = '微软官网 Media Creation Tool 或 UUP dump' },
    @{ path = '02_系统镜像\*Windows11*.iso';   name = 'Windows 11 原版 ISO';                    pri = 'P1'; how = '微软官网' },
    @{ path = '03_驱动\*网卡*';            name = '万能网卡驱动离线包';                        pri = 'P0'; how = '驱动总裁离线版 / SDIO / 品牌官网' },
    @{ path = '04_运行库\7-Zip*';             name = '7-Zip';                                   pri = 'P0'; how = '7-zip.org，便携版即可' },
    @{ path = '04_运行库\*vcredist*';       name = 'VC++ 运行库合集';                          pri = 'P1'; how = '微软或 AIO 合集包' },
    @{ path = '04_运行库\NET35_离线源';     name = '.NET Framework 3.5 离线源（sxs）';         pri = 'P1'; how = '已从官方 ISO 提取' },
    @{ path = '05_磁盘数据\*testdisk*';     name = 'TestDisk / PhotoRec';                     pri = 'P0'; how = 'cgsecurity.org' },
    @{ path = '06_杀毒排查\*autoruns*';     name = 'Autoruns（Sysinternals）';                 pri = 'P1'; how = 'learn.microsoft.com/sysinternals' },
    @{ path = '01_PE\*Kaspersky*';        name = '可启动杀毒 ISO（Kaspersky Rescue Disk）'; pri = 'P1'; how = '已放进 01_PE 即可' },
    @{ path = '07_系统修复\*Dism*';         name = 'Dism++';                                  pri = 'P0'; how = 'chuyu.me' },
    @{ path = '07_系统修复\*Bootice*';      name = 'Bootice（可选，Dism++ 可替代）';            pri = 'P2'; how = '无忧启动论坛手动下载（需注册）' },
    @{ path = '01_PE\*SystemRescue*';       name = 'SystemRescue（Linux 救援 ISO）';            pri = 'P2'; how = 'system-rescue.org' }
)

$missing = New-Object System.Collections.Generic.List[string]
$missing.Add('========== 还没准备好的项目 ==========')
$missing.Add('生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
$missing.Add('')
$missing.Add('说明：这里只是"按文件名猜"的检查，放了文件但名字不同也会显示缺失，')
$missing.Add('      请以自己实际准备情况为准。')
$missing.Add('')
$missingCount = 0
foreach ($e in $expect) {
    $full = Join-Path $Root $e.path
    $hit = Get-ChildItem -Path $full -ErrorAction SilentlyContinue
    if (-not $hit) {
        $missingCount++
        $missing.Add('[' + $e.pri + '] ' + $e.name)
        $missing.Add('      放哪里：' + $rootDisplay + '\' + (Split-Path $e.path -Parent) + '    怎么弄：' + $e.how)
        $missing.Add('')
    }
}
if ($missingCount -eq 0) { $missing.Add('全部就位，好样的。') }
$missing.Add('=====================================')

if ($WhatIfOnly) {
    '缺失项：' + $missingCount + ' 项（预览模式不写文件）'
}
else {
    Write-Utf8 (Join-Path $Root '00_说明\缺失项.txt') ($missing -join "`r`n")
    '生成 缺失项.txt（缺 ' + $missingCount + ' 项）'
}

# ---------- 7. -HashAll：哈希台账 ----------
if ($HashAll -and -not $WhatIfOnly) {
    $all = Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notlike '*\00_说明\哈希台账.csv' -and $_.FullName -notlike '*\_个人\*' }
    $rows = foreach ($f in $all) {
        $h = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue
        [pscustomobject]@{
            相对路径 = $f.FullName.Substring($Root.Length)
            大小MB   = [math]::Round($f.Length / 1MB, 2)
            修改时间 = $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            SHA256   = if ($h) { $h.Hash } else { '' }
        }
    }
    $csv = Join-Path $Root '00_说明\哈希台账.csv'
    $rows | Sort-Object 相对路径 | Export-Csv -LiteralPath $csv -NoTypeInformation -Encoding UTF8
    "生成 哈希台账.csv（" + $rows.Count + " 个文件）"
}

# ---------- 8. 汇总 ----------
''
'================ 完成 ================'
'根目录：' + $rootDisplay
'已就位目录：' + ($dirs -join '、')
if ($WhatIfOnly) { '注意：本次是预览模式，没有真正移动或写入任何文件。' }
''
'下一步：'
'  1) 打开 00_说明\缺失项.txt，按 P0 先补齐'
'  2) 用 Ventoy 把 U 盘做成启动盘，再把本目录放进数据分区'
'  3) 补齐后重新运行：.\初始化救急U盘.ps1 -Root "' + $rootDisplay + '" -HashAll'
'======================================'
