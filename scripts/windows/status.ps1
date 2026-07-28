#Requires -Version 5.1
<#
.SYNOPSIS
  检查 Ollama API 与已安装模型。
#>
$ErrorActionPreference = "Continue"
$Model = if ($env:OLLAMA_MODEL) { $env:OLLAMA_MODEL } else { "qwen3.5:9b" }

Write-Host "=== ollama CLI ==="
if (Get-Command ollama -ErrorAction SilentlyContinue) {
  ollama --version
  ollama list
} else {
  Write-Host "未安装 ollama"
}

Write-Host ""
Write-Host "=== API http://127.0.0.1:11434 ==="
try {
  $tags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
  $tags.models | ForEach-Object { Write-Host ("- " + $_.name) }
} catch {
  Write-Host "API 未就绪。试: .\start.ps1"
  exit 1
}

Write-Host ""
Write-Host "OpenAI /v1/models:"
try {
  (Invoke-RestMethod -Uri "http://127.0.0.1:11434/v1/models" -TimeoutSec 3).data |
    ForEach-Object { Write-Host ("- " + $_.id) }
} catch {
  Write-Host "( /v1/models 调用失败 )"
}

Write-Host ""
Write-Host "CoPaw/Codex: Base URL=http://127.0.0.1:11434/v1  Model=$Model  Key=ollama"
