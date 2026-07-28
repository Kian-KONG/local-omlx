# Windows / Ollama 环境变量示例（可复制到用户环境或会话）
# 在 PowerShell: . .\env.example.ps1

$env:OLLAMA_HOST = "127.0.0.1:11434"
$env:OLLAMA_MODEL = "qwen3.5:9b"

# 可选：限制显存／并行（按需取消注释）
# $env:OLLAMA_NUM_PARALLEL = "1"
# $env:OLLAMA_MAX_LOADED_MODELS = "1"

Write-Host "OLLAMA_HOST=$($env:OLLAMA_HOST) OLLAMA_MODEL=$($env:OLLAMA_MODEL)"
