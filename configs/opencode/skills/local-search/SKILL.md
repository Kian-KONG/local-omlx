---
name: local-search
description: Use ONLY for current events, versions, prices, news, or docs that may be outside training data. Forces bing-cn_bing_search then optional bing-cn_crawl_webpage.
---

# Local web search (Bing CN)

1. Call `bing-cn_bing_search` with a clear Chinese or English `query`.
2. If a result URL looks relevant, call `bing-cn_crawl_webpage` for the body.
3. Answer from tool results only; cite URLs. If empty, say so — do not invent.

Do not use DuckDuckGo or other search MCPs unless bing-cn fails.
