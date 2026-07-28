#Requires -Version 5.1
<#
.SYNOPSIS
  启动 Ollama 应用/服务（若未在跑）。
#>
$ErrorActionPreference = "Stop"

function Test-Api {
  try {
    $r = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 2
    return $r.StatusCode -eq 200
  } catch {
    return $false
  }
}

if (Test-Api) {
  Write-Host "Ollama API 已在运行: http://127.0.0.1:11434"
  exit 0
}

$ollamaApp = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama app.exe"
$ollamaExe = (Get-Command ollama -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)

if (Test-Path $ollamaApp) {
  Write-Host "启动 Ollama App..."
  Start-Process $ollamaApp
} elseif ($ollamaExe) {
  Write-Host "后台启动: ollama serve"
  Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
} else {
  Write-Error "未找到 Ollama。请先 .\install-ollama.ps1"
}

for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 1
  if (Test-Api) {
    Write-Host "就绪: http://127.0.0.1:11434/v1"
    exit 0
  }
}

Write-Error "启动超时。请从开始菜单手动打开 Ollama。"
