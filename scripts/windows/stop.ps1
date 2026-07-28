#Requires -Version 5.1
<#
.SYNOPSIS
  停止 Ollama（结束 ollama 相关进程）。
#>
$ErrorActionPreference = "Continue"

Get-Process -Name "ollama","ollama app" -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "停止 PID $($_.Id) ($($_.ProcessName))"
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 1
try {
  Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 1 | Out-Null
  Write-Host "警告: API 仍可访问，请在托盘图标里退出 Ollama"
} catch {
  Write-Host "Ollama 已停止"
}
