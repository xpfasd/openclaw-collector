#!/bin/bash
# OpenClaw案例库/教程收集脚本
# 每30分钟自动运行

DATE=$(date +%Y-%m-%d_%H-%M)
COLLECTOR_DIR="/Users/xiexie/.openclaw/workspace/openclaw-collector"
OPENCLAW_DIR="/opt/homebrew/lib/node_modules/openclaw"
DATA_DIR="$COLLECTOR_DIR/data"
SKILLS_DIR="$COLLECTOR_DIR/skills"
DOCS_DIR="$COLLECTOR_DIR/docs"
LOG_FILE="$COLLECTOR_DIR/collection.log"

echo "=== [$DATE] 开始收集 ===" >> $LOG_FILE

# 创建日期目录
mkdir -p "$DATA_DIR/$DATE"

# 1. 收集Skills列表
echo "收集Skills..." >> $LOG_FILE
ls "$OPENCLAW_DIR/skills/" > "$DATA_DIR/$DATE/skills_list_$DATE.txt"
echo "- 找到 $(wc -l < "$DATA_DIR/$DATE/skills_list_$DATE.txt") 个Skills" >> $LOG_FILE

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
echo "- 找到 $(wc -l < "$DATA_DIR/$DATE/docs_list_$DATE.txt") 个文档" >> $LOG_FILE

# 收集docs目录结构
tree -L 3 --noreport "$OPENCLAW_DIR/docs/" > "$DATA_DIR/$DATE/docs_tree_$DATE.txt" 2>/dev/null || find "$OPENCLAW_DIR/docs/" -type d > "$DATA_DIR/$DATE/docs_dirs_$DATE.txt"

# 3. 收集技能描述（快速摘要）
echo "生成技能摘要..." >> $LOG_FILE
cat > "$DATA_DIR/$DATE/skills_summary_$DATE.md" << 'EOF'
# OpenClaw Skills Summary
Generated: $DATE

## Skills List

EOF

for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    # 提取description
    DESC=$(grep -m1 "<description>" "$skill_dir/SKILL.md" 2>/dev/null | sed 's/<[^>]*>//g' || echo "No description")
    echo "### $SKILL_NAME" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "- $DESC" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    echo "" >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  fi
done

# 4. 更新索引
echo "更新索引..." >> $LOG_FILE
cat > "$COLLECTOR_DIR/index.md" << EOF
# OpenClaw Collection Index

**Last Updated**: $DATE

## Collection Stats

- Skills: $(ls "$OPENCLAW_DIR/skills/" | wc -l)
- Docs: $(find "$OPENCLAW_DIR/docs/" -name "*.md" -o -name "*.mdx" | wc -l)
- Collection Dates: $(ls -1 "$DATA_DIR/" | wc -l)

## Directory Structure

\`\`\`
openclaw-collector/
├── skills/          # Skill details (SKILL.md files)
├── docs/           # Documentation files
├── data/           # Daily snapshots
│   └── $(ls -1 "$DATA_DIR/" | tail -1)/  # Latest collection
├── index.md        # This index
└── collector.sh    # Collection script
\`\`\`

## How to Use

1. Browse \`data/\` for daily snapshots
2. Check \`skills/\` for detailed skill documentation
3. Review \`docs/\` for OpenClaw documentation

## Cron Schedule

Runs every 30 minutes.
EOF

echo "=== [$DATE] 收集完成 ===" >> $LOG_FILE
echo "收集完成！时间: $DATE" >> $LOG_FILE
