#Requires -Version 5.1
<#
.SYNOPSIS
  用国内镜像下载 Qwen3.5-9B GGUF，再 ollama create 导入默认库（不走 ollama pull）。

.DESCRIPTION
  Ollama 不能直接把 GGUF「复制进目录」就识别；正确做法是：
  1) hf-mirror 下载 .gguf
  2) 写 Modelfile: FROM <本地gguf>
  3) ollama create <名字> -f Modelfile
  之后权重会出现在 %USERPROFILE%\.ollama\models（由 ollama 管理 blob）。

.PARAMETER Model
  导入后的 Ollama 模型名，默认 qwen3.5:9b
.PARAMETER Repo
  HF 仓库，默认 unsloth/Qwen3.5-9B-GGUF
.PARAMETER File
  GGUF 文件名，默认 Qwen3.5-9B-Q4_K_M.gguf
.PARAMETER GgufDir
  GGUF 缓存目录，默认 %USERPROFILE%\models\gguf
.PARAMETER Pull
  若指定，则改走 ollama pull（需能访问 Ollama 官方库）
#>
param(
  [string]$Model = $env:OLLAMA_MODEL,
  [string]$Repo = "unsloth/Qwen3.5-9B-GGUF",
  [string]$File = "Qwen3.5-9B-Q4_K_M.gguf",
  [string]$GgufDir = "",
  [switch]$Pull
)

$ErrorActionPreference = "Stop"
if (-not $Model) { $Model = "qwen3.5:9b" }
if (-not $GgufDir) { $GgufDir = Join-Path $env:USERPROFILE "models\gguf" }

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
  Write-Error "未找到 ollama。请先运行 .\install-ollama.ps1"
}

# --- 可选：官方 pull ---
if ($Pull) {
  Write-Host "使用 ollama pull（需能访问官方库）: $Model"
  ollama pull $Model
  ollama list
  exit 0
}

# --- 默认：hf-mirror 下载 + ollama create ---
$env:HF_ENDPOINT = if ($env:HF_ENDPOINT) { $env:HF_ENDPOINT } else { "https://hf-mirror.com" }
$env:HF_HUB_DISABLE_XET = "1"
$PipIndex = if ($env:PIP_INDEX_URL) { $env:PIP_INDEX_URL } else { "https://pypi.tuna.tsinghua.edu.cn/simple" }

New-Item -ItemType Directory -Force -Path $GgufDir | Out-Null
$ggufPath = Join-Path $GgufDir $File

function Find-Gguf {
  if (Test-Path $ggufPath) { return $ggufPath }
  $hit = Get-ChildItem -Path $GgufDir -Recurse -Filter $File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { return $hit.FullName }
  return $null
}

$existing = Find-Gguf
if (-not $existing) {
  Write-Host "从 hf-mirror 下载 $Repo / $File"
  Write-Host "  HF_ENDPOINT=$($env:HF_ENDPOINT)"
  Write-Host "  目录: $GgufDir"

  if (-not (Get-Command hf -ErrorAction SilentlyContinue) -and -not (Get-Command huggingface-cli -ErrorAction SilentlyContinue)) {
    Write-Host "安装 huggingface_hub ..."
    python -m pip install -U "huggingface_hub[cli]" -i $PipIndex
  }

  if (Get-Command hf -ErrorAction SilentlyContinue) {
    hf download $Repo $File --local-dir $GgufDir
  } else {
    huggingface-cli download $Repo $File --local-dir $GgufDir --local-dir-use-symlinks False
  }

  $existing = Find-Gguf
  if (-not $existing) {
    Write-Error "下载后未找到 $File"
  }
} else {
  Write-Host "已有 GGUF: $existing"
}

# Ollama 需要能读到绝对路径；Modelfile 放在 GGUF 同目录
$modelfile = Join-Path (Split-Path $existing -Parent) ("Modelfile." + ($Model -replace '[:\\/]', '_'))
@"
FROM $existing
"@ | Set-Content -Path $modelfile -Encoding utf8

Write-Host "导入到 Ollama 默认库（不走 pull）: $Model"
Write-Host "  Modelfile: $modelfile"
Write-Host "  完成后由 ollama 写入: $env:USERPROFILE\.ollama\models"
ollama create $Model -f $modelfile

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
Write-Host "说明: 不要手动往 .ollama\models 塞 GGUF；必须用 create 导入。"
