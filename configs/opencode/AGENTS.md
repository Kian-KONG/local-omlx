# 联网搜索（必应中文 MCP）

涉及时效、版本号、新闻、价格、文档更新时：

1. **先**调用 `bing-cn_bing_search`（参数 `query`），禁止只用训练记忆作答。
2. 需要正文时再调用 `bing-cn_crawl_webpage`。
3. 回答里引用工具返回的 URL；工具无结果时说明「搜索无结果」，不要编造。

# 本地模型工作方式

- 少读文件、小 diff、短回答；不要一次挂整仓。
- 优先 `grep` / `glob` 定位，再 `read` 相关片段。
- 不要加载大型 skill 合集；只用已安装的短 skill（`local-search`、`local-coding`）。
