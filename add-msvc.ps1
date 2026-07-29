# 给已有的 VS 2022 Community 安装(D:\tool\Microsoft\VisualStudio\common)追加
# MSVC 编译工具 + Windows 11 SDK —— 这两个是 zap 在 Windows 上链接 Rust 的必需品。
# 需要管理员权限:本脚本内部用 Start-Process -Verb RunAs 自动提权。
$ErrorActionPreference = 'Stop'

$setup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
if (-not (Test-Path $setup)) {
    Write-Error "找不到 VS Installer: $setup"
    exit 1
}

# 1) 先杀掉所有残留的 VS Installer 进程,避免 "Another instance is running" 互斥锁问题
Write-Host "清理残留 VS Installer 进程..."
Get-Process -Name setup,vs_installer,vs_installershell,vs_installer_windows,ServiceHub.SettingsHost -ErrorAction SilentlyContinue |
    ForEach-Object {
        Write-Host "  停止 $($_.Name) (PID $($_.Id))"
        try { $_ | Stop-Process -Force -ErrorAction Stop } catch { Write-Warning "  无法停止 $($_.Name): $_" }
    }
Start-Sleep -Seconds 2

# 2) 提权运行 modify
$args = @(
    'modify',
    '--installPath', 'D:\tool\Microsoft\VisualStudio\common',
    '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
    '--includeRecommended',
    '--passive',
    '--norestart'
)

Write-Host ""
Write-Host "提权运行 VS Installer,追加 MSVC + Win11 SDK(约 5-7 GB 下载,10-30 分钟)..."
Write-Host "命令: $setup $($args -join ' ')"
Write-Host ""

$p = Start-Process -FilePath $setup -ArgumentList $args -Verb RunAs -PassThru -Wait
Write-Host ""
Write-Host "VS Installer 退出码: $($p.ExitCode)"
if ($p.ExitCode -ne 0) {
    Write-Warning "退出码非 0,可能未完全成功。请把此输出贴给 harness。"
    exit $p.ExitCode
}

# 3) 复查组件是否真的落地
Write-Host ""
Write-Host "复查组件安装情况..."
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$ok = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.Windows11SDK.22621 `
    -property installationPath
if ($ok) {
    Write-Host "✅ VC.Tools.x86.x64 + Windows11SDK.22621 均已安装,installPath = $ok"
} else {
    Write-Warning "❌ vswhere 仍未识别到这两个组件 —— 可能是安装被取消或网络失败。"
    Write-Warning "请打开 VS Installer GUI 手动确认,或把此输出贴给 harness。"
}
