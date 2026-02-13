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

# 1. 收集Skills列表
echo "收集Skills..." >> $LOG_FILE
ls "$OPENCLAW_DIR/skills/" > "$DATA_DIR/$DATE/skills_list_$DATE.txt"
SKILL_COUNT=$(wc -l < "$DATA_DIR/$DATE/skills_list_$DATE.txt")
echo "- 找到 $SKILL_COUNT 个Skills" >> $LOG_FILE

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
cat > "$DATA_DIR/$DATE/skills_summary_$DATE.md" << EOF
# OpenClaw Skills Summary
Generated: $DATE

## Skills List ($SKILL_COUNT total)

EOF

for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    DESC=$(grep -m1 "<description>" "$skill_dir/SKILL.md" 2>/dev/null | sed 's/<[^>]*>//g' | tr -d '\n' | head -c 200 || echo "No description")
    echo "### $SKILL_NAME" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "- $DESC" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  fi
done

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
    DESC=$(grep -m1 "<description>" "$skill_dir/SKILL.md" 2>/dev/null | sed 's/<[^>]*>//g' | tr -d '\n' | head -c 300 || echo "OpenClaw Skill")
    
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
    
    [ -z "$first" ] && echo "," >> "$SITE_DIR/data/skills.json"
    first=false
    cat >> "$SITE_DIR/data/skills.json" << JSONEOF
    "$SKILL_NAME": {
      "name": "$SKILL_NAME",
      "description": "$DESC",
      "category": "$CAT",
      "location": "$skill_dir",
      "icon": "📦"
    }
JSONEOF
  fi
done

cat >> "$SITE_DIR/data/skills.json" << 'JSONEOF'
  }
}
JSONEOF

# 5. 更新site.json
echo "更新site.json..." >> $LOG_FILE
cat > "$SITE_DIR/data/site.json" << EOF
{
  "site": {
    "name": "OpenClaw Skills Hub",
    "description": "OpenClaw技能索引与教程中心",
    "url": "https://xpfasd.github.io/openclaw-site",
    "version": "1.0.0",
    "lastUpdated": "$(date +%Y-%m-%d)"
  },
  "stats": {
    "totalSkills": $SKILL_COUNT,
    "totalDocs": $DOC_COUNT
  }
}
EOF

# 6. 更新索引
echo "更新索引..." >> $LOG_FILE
cat > "$COLLECTOR_DIR/index.md" << EOF
# OpenClaw Collection Index

**Last Updated**: $DATE

## Collection Stats

- Skills: $SKILL_COUNT
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
