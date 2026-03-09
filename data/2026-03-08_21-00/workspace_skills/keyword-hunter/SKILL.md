# Keyword Hunter - 找新词自动化技能

## Description

自动化Google Trends暴涨词发现和KGR验证工具。

## Commands

### 找新词
搜索Google Trends Related Queries的Rising暴涨词。
```
找新词 [词根]
例如：
找新词 generator
找新词 game
找新词 tool
```

### 验证KGR
验证关键词的KGR（Keyword Golden Ratio）。
```
验证KGR [关键词]
例如：
验证KGR ai image generator maker
验证KGR ai video generator
```

### 检查域名
检查域名是否可注册。
```
检查域名 [关键词]
例如：
检查域名 aitoolgenerator
检查域名 aimakergenerator
```

### 生成建站计划
为一键建站生成计划。
```
建站 [域名] [关键词]
例如：
建站 aitoolgenerator.io AI Tool Generator
```

## Requirements

- OpenClaw Gateway运行中
- Browser-use已安装
- SerpAPI Key（可选，用于真实数据查询）

## Configuration

在 `~/.openclaw/.env` 中配置：
```
SERPAPI_KEY=your_serpapi_key
```

## Source

https://github.com/openclaw/openclaw
