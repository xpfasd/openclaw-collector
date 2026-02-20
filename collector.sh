#!/bin/bash
# OpenClaw案例库/教程收集脚本
# 每30分钟自动运行
# 收集后自动生成网站

DATE=$(date +%Y-%m-%d_%H-%M)
COLLECTOR_DIR="/Users/xiexie/.openclaw/workspace/openclaw-collector"
SITE_DIR="/Users/xiexie/.openclaw/workspace/openclaw-site"
OUTPUT_DIR="/Users/xiexie/.openclaw/workspace/openclaw-site-output"
OPENCLAW_DIR="/opt/homebrew/lib/node_modules/openclaw"
DATA_DIR="$COLLECTOR_DIR/data"
SKILLS_DIR="$COLLECTOR_DIR/skills"
LOG_FILE="$COLLECTOR_DIR/collection.log"

echo "=== [$DATE] 开始收集 ===" >> $LOG_FILE

# 创建数据目录
mkdir -p "$DATA_DIR/$DATE"

# 1. 收集OpenClaw内置Skills
echo "收集Skills..." >> $LOG_FILE
ls "$OPENCLAW_DIR/skills/" > "$DATA_DIR/$DATE/skills_list_$DATE.txt"
SKILL_COUNT=$(wc -l < "$DATA_DIR/$DATE/skills_list_$DATE.txt")
echo "- 找到 $SKILL_COUNT 个内置Skills" >> $LOG_FILE

# 2. 收集工作空间自定义Skills
echo "收集工作空间Skills..." >> $LOG_FILE
WORKSPACE_SKILLS_DIR="/Users/xiexie/.openclaw/skills"
if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  WORKSPACE_SKILL_COUNT=$(ls -1 "$WORKSPACE_SKILLS_DIR/" 2>/dev/null | wc -l)
  echo "- 找到 $WORKSPACE_SKILL_COUNT 个工作空间Skills" >> $LOG_FILE
  mkdir -p "$DATA_DIR/$DATE/workspace_skills"
  for skill in "$WORKSPACE_SKILLS_DIR/"*/; do
    if [ -f "$skill/SKILL.md" ]; then
      SKILL_NAME=$(basename "$skill")
      mkdir -p "$DATA_DIR/$DATE/workspace_skills/$SKILL_NAME"
      cp "$skill/SKILL.md" "$DATA_DIR/$DATE/workspace_skills/$SKILL_NAME/"
    fi
  done
else
  echo "- 工作空间Skills目录不存在" >> $LOG_FILE
  WORKSPACE_SKILL_COUNT=0
fi

# 收集每个skill的说明
for skill in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill")
  if [ -f "$skill/SKILL.md" ]; then
    mkdir -p "$SKILLS_DIR/$SKILL_NAME"
    cp "$skill/SKILL.md" "$SKILLS_DIR/$SKILL_NAME/"
  fi
done

# 2. 收集Docs列表
echo "收集Docs..." >> $LOG_FILE
find "$OPENCLAW_DIR/docs/" -name "*.md" -o -name "*.mdx" > "$DATA_DIR/$DATE/docs_list_$DATE.txt"
DOC_COUNT=$(wc -l < "$DATA_DIR/$DATE/docs_list_$DATE.txt")
echo "- 找到 $DOC_COUNT 个文档" >> $LOG_FILE

# 收集docs目录结构
find "$OPENCLAW_DIR/docs/" -type d > "$DATA_DIR/$DATE/docs_dirs_$DATE.txt"

# 3. 生成技能摘要
echo "生成技能摘要..." >> $LOG_FILE

# 函数：从YAML frontmatter提取字段
extract_yaml_field() {
  local file=$1
  local field=$2
  if [ -f "$file" ]; then
    # 提取description字段（支持带引号和不带引号的值）
    sed -n "s/^$field: *[\"\']\?\(.*\)[\"\']\?/\1/p" "$file" | head -1 | sed 's/"/\\"/g' | head -c 300
  fi
}
cat > "$DATA_DIR/$DATE/skills_summary_$DATE.md" << EOF
# OpenClaw Skills Summary
Generated: $DATE

## Skills List ($SKILL_COUNT total)

EOF

for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
    [ -z "$DESC" ] && DESC="No description"
    echo "### $SKILL_NAME" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "- $DESC" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  fi
done

# 添加工作空间技能到摘要
if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  echo "## Workspace Skills ($WORKSPACE_SKILL_COUNT total)" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  for skill_dir in "$WORKSPACE_SKILLS_DIR/"*/; do
    SKILL_NAME=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
      [ -z "$DESC" ] && DESC="Workspace Custom Skill"
      echo "### $SKILL_NAME" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
      echo "- $DESC" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
      echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    fi
  done
fi

# 4. 生成技能数据JSON
echo "生成技能数据..." >> $LOG_FILE
cat > "$SITE_DIR/data/skills.json" << 'JSONEOF'
{
  "skills": {
JSONEOF

first=true
for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    # 从YAML frontmatter提取description
    DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
    [ -z "$DESC" ] && DESC="OpenClaw Skill"
    
    # 提取emoji
    EMOJI=$(sed -n 's/.*"emoji": *"\([^"]*\)".*/\1/p' "$skill_dir/SKILL.md" | head -1)
    [ -z "$EMOJI" ] && EMOJI="📦"
    
    # Determine category
    case "$SKILL_NAME" in
      nano-banana-pro|gemini|coding-agent) CAT="ai-ml" ;;
      canvas|openai-image-gen|openai-whisper|video-frames) CAT="media" ;;
      notion|obsidian|apple-notes|things-mac) CAT="productivity" ;;
      discord|slack|imsg|bird) CAT="communication" ;;
      github|tmux|skill-creator) CAT="development" ;;
      spotify-player|songsee|gifgrep) CAT="multimedia" ;;
      openhue|goplaces) CAT="iot" ;;
      *) CAT="utilities" ;;
    esac
    
    # 添加逗号（除了第一个）
    if [ "$first" = "false" ]; then
      echo "," >> "$SITE_DIR/data/skills.json"
    fi
    first=false
    
    cat >> "$SITE_DIR/data/skills.json" << JSONEOF
    "$SKILL_NAME": {
      "name": "$SKILL_NAME",
      "description": "$DESC",
      "category": "$CAT",
      "location": "$skill_dir",
      "icon": "$EMOJI"
    }
JSONEOF
  fi
done

cat >> "$SITE_DIR/data/skills.json" << 'JSONEOF'
  }
}
JSONEOF

# 4.1 添加工作空间Skills（使用Python合并）
if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  echo "添加工作空间Skills..." >> $LOG_FILE
  
  # 收集工作空间技能数据
  WORKSPACE_DATA="["
  first_ws=true
  for skill_dir in "$WORKSPACE_SKILLS_DIR/"*/; do
    SKILL_NAME=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
      [ -z "$DESC" ] && DESC="Workspace Custom Skill"
      
      # 转义DESC中的特殊字符
      DESC=$(echo "$DESC" | sed 's/"/\\"/g' | tr '\n' ' ')
      
      if [ "$first_ws" = "false" ]; then
        WORKSPACE_DATA+=","
      fi
      first_ws=false
      WORKSPACE_DATA+="{\"name\":\"$SKILL_NAME\",\"description\":\"$DESC\",\"category\":\"utilities\",\"icon\":\"🛠️\"}"
    fi
  done
  WORKSPACE_DATA+="]"
  
  # 使用Python合并
  python3 << PYEOF >> $LOG_FILE 2>&1
import json

# 读取现有skills.json
with open('$SITE_DIR/data/skills.json', 'r') as f:
    data = json.load(f)

# 添加工作空间技能
ws_data = $WORKSPACE_DATA
for skill in ws_data:
    data['skills'][skill['name']] = {
        'name': skill['name'],
        'description': skill['description'],
        'category': skill['category'],
        'location': '$WORKSPACE_SKILLS_DIR/' + skill['name'] + '/',
        'icon': skill['icon']
    }

# 写回
with open('$SITE_DIR/data/skills.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Added {len(ws_data)} workspace skills")
PYEOF
fi

# 5. 更新site.json（含categories和i18n）
echo "更新site.json..." >> $LOG_FILE
TOTAL_SKILLS=$((SKILL_COUNT + WORKSPACE_SKILL_COUNT))
cat > "$SITE_DIR/data/site.json" << EOF
{
  "site": {
    "name": "OpenClaw Skills Hub",
    "description": "OpenClaw技能索引与教程中心",
    "url": "https://xpfasd.github.io/openclaw-site",
    "version": "1.0.0",
    "lastUpdated": "$(date +%Y-%m-%d)"
  },
  "i18n": {
    "languages": [
      { "code": "en", "name": "English", "nativeName": "English" },
      { "code": "zh", "name": "Chinese", "nativeName": "中文" }
    ],
    "defaultLang": "en"
  },
  "stats": {
    "totalSkills": $TOTAL_SKILLS,
    "totalDocs": $DOC_COUNT,
    "categories": [
      { "id": "ai-ml", "name": "AI/ML", "icon": "🤖", "skills": ["gemini", "openai-image-gen", "openai-whisper", "coding-agent", "nano-banana-pro"] },
      { "id": "media", "name": "Media", "icon": "🎬", "skills": ["spotify-player", "songsee", "sonoscli", "video-frames", "canvas", "camsnap"] },
      { "id": "productivity", "name": "Productivity", "icon": "📋", "skills": ["notion", "obsidian", "things-mac", "trello", "apple-notes", "bear-notes"] },
      { "id": "communication", "name": "Communication", "icon": "💬", "skills": ["discord", "slack", "imsg", "wacli", "voice-call", "bluebubbles"] },
      { "id": "development", "name": "Development", "icon": "💻", "skills": ["github", "tmux", "skill-creator"] },
      { "id": "multimedia", "name": "Multimedia", "icon": "🎨", "skills": ["gifgrep", "nano-pdf"] },
      { "id": "iot", "name": "IoT", "icon": "🏠", "skills": ["openhue", "goplaces", "eightctl"] },
      { "id": "utilities", "name": "Utilities", "icon": "🔧", "skills": ["1password", "apple-reminders", "blogwatcher", "blucli", "food-order", "gog", "healthcheck", "himalaya", "local-places", "mcporter", "model-usage", "openai-whisper-api", "oracle", "ordercli", "peekaboo", "sag", "session-logs", "sherpa-onnx-tts", "summarize", "weather", "clawhub"] }
    ]
  }
}
EOF

# 6. 更新索引
echo "更新索引..." >> $LOG_FILE
cat > "$COLLECTOR_DIR/index.md" << EOF
# OpenClaw Collection Index

**Last Updated**: $DATE

## Collection Stats

- Built-in Skills: $SKILL_COUNT
- Workspace Skills: $WORKSPACE_SKILL_COUNT
- Total Skills: $TOTAL_SKILLS
- Docs: $DOC_COUNT

## Collection Dates

$(ls -1 "$DATA_DIR/" | tail -10)

## Quick Links

- [Skills Index](/openclaw-site-output/skills/)
- [Categories](/openclaw-site-output/categories/)

## Cron Schedule

Runs every 30 minutes.
EOF

# 7. 生成网站
echo "生成网站..." >> $LOG_FILE
cd "$SITE_DIR"
node generate.js >> $LOG_FILE 2>&1

# 8. 推送到GitHub
echo "推送到GitHub..." >> $LOG_FILE
cd "$COLLECTOR_DIR"
git add -A >> $LOG_FILE 2>&1
git commit -m "Auto-collect: $DATE" >> $LOG_FILE 2>&1
git push origin main >> $LOG_FILE 2>&1

# 9. 推送到GitHub Pages
echo "同步GitHub Pages..." >> $LOG_FILE
cd "$OUTPUT_DIR"
git init >> $LOG_FILE 2>&1
git add -A >> $LOG_FILE 2>&1
git commit -m "Site update: $DATE" >> $LOG_FILE 2>&1
git push -f https://github.com/xpfasd/openclaw-site.git main:gh-pages >> $LOG_FILE 2>&1

echo "=== [$DATE] 收集完成 ===" >> $LOG_FILE
echo "✅ 收集完成！时间: $DATE" >> $LOG_FILE
echo "   Skills: $SKILL_COUNT | Docs: $DOC_COUNT"
