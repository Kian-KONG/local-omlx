#Requires -Version 5.1
<#
.SYNOPSIS
  拉取 Qwen3.5-9B 到本机 Ollama（适合 RTX 4070 8GB，默认 Q4）。
.PARAMETER Model
  Ollama 模型名，默认 qwen3.5:9b
#>
param(
  [string]$Model = $env:OLLAMA_MODEL
)

$ErrorActionPreference = "Stop"
if (-not $Model) { $Model = "qwen3.5:9b" }

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  Write-Error "未找到 ollama。请先运行 .\install-ollama.ps1"
}

Write-Host "拉取模型: $Model"
Write-Host "4070 8GB 建议保持默认 Q4；下载约 6–7GB。"
ollama pull $Model

Write-Host ""
Write-Host "完成。可用模型:"
ollama list

Write-Host ""
Write-Host "OpenAI 兼容:"
Write-Host "  Base URL: http://127.0.0.1:11434/v1"
Write-Host "  Model:    $Model"
Write-Host "  API Key:  ollama"
Write-Host ""
Write-Host "验证: curl.exe http://127.0.0.1:11434/v1/models"
