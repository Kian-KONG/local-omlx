#Requires -Version 5.1
<#
.SYNOPSIS
  安装 Ollama（Windows）。已安装则跳过。
#>
$ErrorActionPreference = "Stop"

function Test-Ollama {
  return [bool](Get-Command ollama -ErrorAction SilentlyContinue)
}

Write-Host "检测 Ollama..."
if (Test-Ollama) {
  Write-Host "已安装: $(Get-Command ollama | Select-Object -ExpandProperty Source)"
  ollama --version
  exit 0
}

Write-Host "未找到 ollama。请安装官方 Windows 版后重开终端再跑本脚本。"
Write-Host "下载页: https://ollama.com/download/windows"
Write-Host ""
Write-Host "或用 winget（若可用）:"
Write-Host "  winget install Ollama.Ollama"

$useWinget = Read-Host "尝试用 winget 安装? [y/N]"
if ($useWinget -match '^[yY]') {
  winget install -e --id Ollama.Ollama --accept-package-agreements --accept-source-agreements
  Write-Host "安装完成后请重新打开 PowerShell，再执行 .\download-models.ps1"
  exit 0
}

Write-Host "已取消自动安装。装好 Ollama 后执行: .\download-models.ps1"
exit 1
