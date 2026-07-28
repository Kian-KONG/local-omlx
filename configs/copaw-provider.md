# CoPaw ↔ oMLX 对接

CoPaw 作为客户端，oMLX 作为本地 OpenAI 兼容后端。**不要**安装 `copaw[mlx]`，避免 CoPaw 再加载一份模型。

## 前置

```bash
cd /Users/bobo/Desktop/Workspace/local-omlx
./scripts/start.sh
./scripts/switch-model.sh 4b   # 开 CoPaw 前建议先切 4B
```

确认：

```bash
curl -s http://127.0.0.1:8000/v1/models
```

## 安装 CoPaw（无内置 MLX）

```bash
# macOS
curl -fsSL https://copaw.agentscope.io/install.sh | bash

# 或
pip install copaw
```

不要使用：

```bash
# 错误：会再占一份统一内存
pip install 'copaw[mlx]'
bash install.sh --extras mlx
```

初始化并打开控制台：

```bash
copaw init --defaults   # 或交互式 copaw init
copaw app
```

浏览器打开：http://127.0.0.1:8088/

## 添加 OpenAI Compatible Provider

1. 控制台 → **Settings** → **Models**
2. **Add provider**（OpenAI Compatible / 自定义）
3. 填写：

| 字段 | 值 |
|------|-----|
| Provider ID | `local-omlx`（自定） |
| Display name | `oMLX Local` |
| Base URL | `http://127.0.0.1:8000/v1` |
| API Key | `local`（oMLX 未设 `--api-key` 时任意占位即可） |

4. 在该 Provider 下添加模型：

| 场景 | Model ID |
|------|----------|
| CoPaw Agent / 工具调用（推荐） | `Qwen3.5-4B-OptiQ-4bit` |
| 轻量聊天（关掉其他重进程） | `Qwen3.5-9B-OptiQ-4bit` |

5. LLM Configuration 下拉框选中当前要用的模型并激活。

若 Admin 里给模型设了 alias，则以 `/v1/models` 返回的 id 为准。

## 16GB 使用策略

| 你在做什么 | 用哪个模型 | 额外动作 |
|------------|------------|----------|
| CoPaw 多轮 agent | **4B** | `./scripts/switch-model.sh 4b`；Admin 里 Unload 9B |
| 单独问答 / 写短文 | **9B** | 先退出 CoPaw；Unload 4B |
| 同时开 userbank-rag / Docker | **4B** | 不要 pin 9B |

oMLX 内存护栏默认约 `OMLX_MEMORY_GUARD_GB=10`。不要同时 Pin 9B 与 4B。

## 其他应用共用

任何 OpenAI SDK / 兼容客户端：

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:8000/v1",
    api_key="local",
)
r = client.chat.completions.create(
    model="Qwen3.5-4B-OptiQ-4bit",
    messages=[{"role": "user", "content": "你好"}],
)
print(r.choices[0].message.content)
```

## 故障排查

| 现象 | 处理 |
|------|------|
| CoPaw 连不上 | 确认 oMLX 在跑：`curl http://127.0.0.1:8000/v1/models` |
| 系统卡顿 / 换页 | 立刻切 4B，Admin Unload 9B，关掉 Chrome/Docker/RAG |
| model not found | Model ID 必须与目录名或 alias 一致；先 `download-models.sh` |
| 首次很慢 | 正常：冷加载 + SSD KV；之后会快一些 |
