#Requires -Version 5.1
<#
.SYNOPSIS
  可选：从 hf-mirror 下载 Qwen3.5-9B GGUF（Q4_K_M），供 LM Studio / llama-server。
  日常更推荐 .\download-models.ps1（Ollama）。
#>
param(
  [string]$Repo = "unsloth/Qwen3.5-9B-GGUF",
  [string]$File = "Qwen3.5-9B-Q4_K_M.gguf",
  [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
if (-not $OutDir) {
  $OutDir = Join-Path $env:USERPROFILE "models\gguf"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$env:HF_ENDPOINT = if ($env:HF_ENDPOINT) { $env:HF_ENDPOINT } else { "https://hf-mirror.com" }
$env:HF_HUB_DISABLE_XET = "1"

Write-Host "HF_ENDPOINT=$($env:HF_ENDPOINT)"
Write-Host "下载 $Repo / $File → $OutDir"

if (-not (Get-Command huggingface-cli -ErrorAction SilentlyContinue) -and -not (Get-Command hf -ErrorAction SilentlyContinue)) {
  Write-Host "安装 huggingface_hub到当前用户..."
  python -m pip install -U "huggingface_hub[cli]" -i https://pypi.tuna.tsinghua.edu.cn/simple
}

$target = Join-Path $OutDir $File
if (Test-Path $target) {
  Write-Host "已存在: $target"
  exit 0
}

if (Get-Command hf -ErrorAction SilentlyContinue) {
  hf download $Repo $File --local-dir $OutDir
} else {
  huggingface-cli download $Repo $File --local-dir $OutDir --local-dir-use-symlinks False
}

if (-not (Test-Path $target)) {
  # 有的仓库会带子目录
  $found = Get-ChildItem -Path $OutDir -Recurse -Filter $File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) {
    Write-Host "完成: $($found.FullName)"
    exit 0
  }
  Write-Error "未找到 $File，请检查仓库文件名是否变更"
}

Write-Host "完成: $target"
Write-Host "可用 LM Studio 打开该 GGUF，或 llama-server -m `"$target`" -ngl 99 --port 8080"
