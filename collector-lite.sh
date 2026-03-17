#!/bin/bash
# One-shot collection without site generation or git pushes
set -euo pipefail

DATE=$(date +%Y-%m-%d_%H-%M)
COLLECTOR_DIR="/Users/xiexie/.openclaw/workspace/openclaw-collector"
SITE_DIR="/Users/xiexie/.openclaw/workspace/openclaw-site"
OPENCLAW_DIR="/opt/homebrew/lib/node_modules/openclaw"
DATA_DIR="$COLLECTOR_DIR/data"
SKILLS_DIR="$COLLECTOR_DIR/skills"
LOG_FILE="$COLLECTOR_DIR/collection.log"
WORKSPACE_SKILLS_DIR="/Users/xiexie/.openclaw/skills"

mkdir -p "$DATA_DIR/$DATE"
echo "=== [$DATE] 开始收集 (lite) ===" >> "$LOG_FILE"

# 1) Built-in skills list
ls "$OPENCLAW_DIR/skills/" > "$DATA_DIR/$DATE/skills_list_$DATE.txt"
SKILL_COUNT=$(wc -l < "$DATA_DIR/$DATE/skills_list_$DATE.txt" | xargs)

# 2) Workspace skills
WORKSPACE_SKILL_COUNT=0
if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  WORKSPACE_SKILL_COUNT=$(ls -1 "$WORKSPACE_SKILLS_DIR/" 2>/dev/null | wc -l | xargs)
  mkdir -p "$DATA_DIR/$DATE/workspace_skills"
  for skill in "$WORKSPACE_SKILLS_DIR/"*/; do
    if [ -f "$skill/SKILL.md" ]; then
      SKILL_NAME=$(basename "$skill")
      mkdir -p "$DATA_DIR/$DATE/workspace_skills/$SKILL_NAME"
      cp "$skill/SKILL.md" "$DATA_DIR/$DATE/workspace_skills/$SKILL_NAME/"
    fi
  done
fi

# Copy SKILL.md of built-in skills
mkdir -p "$SKILLS_DIR"
for skill in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill")
  if [ -f "$skill/SKILL.md" ]; then
    mkdir -p "$SKILLS_DIR/$SKILL_NAME"
    cp "$skill/SKILL.md" "$SKILLS_DIR/$SKILL_NAME/"
  fi
done

# 3) Docs list
find "$OPENCLAW_DIR/docs/" -name "*.md" -o -name "*.mdx" > "$DATA_DIR/$DATE/docs_list_$DATE.txt"
DOC_COUNT=$(wc -l < "$DATA_DIR/$DATE/docs_list_$DATE.txt" | xargs)
find "$OPENCLAW_DIR/docs/" -type d > "$DATA_DIR/$DATE/docs_dirs_$DATE.txt"

# Helper to extract YAML frontmatter fields
extract_yaml_field() {
  local file=$1
  local field=$2
  if [ -f "$file" ]; then
    local desc
    desc=$(sed -n "s/^$field: *\"\([^\"]*\)\"/\1/p" "$file" | head -1)
    if [ -z "$desc" ]; then
      desc=$(sed -n "s/^$field: *\([^#\n]*\)/\1/p" "$file" | head -1 | xargs echo)
    fi
    echo "$desc" | sed 's/"/\\"/g' | head -c 300
  fi
}

# 4) skills summary
cat > "$DATA_DIR/$DATE/skills_summary_$DATE.md" << 'SUMMARYEOF'
# OpenClaw Skills Summary

## Skills List
SUMMARYEOF

for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
    [ -z "$DESC" ] && DESC="No description"
    {
      echo "### $SKILL_NAME"
      echo "- $DESC"
      echo
    } >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  fi
done

if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  {
    echo
    echo "## Workspace Skills ($WORKSPACE_SKILL_COUNT total)"
    echo
  } >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
  for skill_dir in "$WORKSPACE_SKILLS_DIR/"*/; do
    SKILL_NAME=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
      [ -z "$DESC" ] && DESC="Workspace Custom Skill"
      {
        echo "### $SKILL_NAME"
        echo "- $DESC"
        echo
      } >> "$DATA_DIR/$DATE/skills_summary_$DATE.md"
    fi
  done
fi

# 5) skills.json + merge workspace skills
mkdir -p "$SITE_DIR/data"
cat > "$SITE_DIR/data/skills.json" << 'JSONEOF'
{
  "skills": {
JSONEOF

first=true
for skill_dir in "$OPENCLAW_DIR/skills/"*/; do
  SKILL_NAME=$(basename "$skill_dir")
  if [ -f "$skill_dir/SKILL.md" ]; then
    DESC=$(extract_yaml_field "$skill_dir/SKILL.md" "description")
    [ -z "$DESC" ] && DESC="OpenClaw Skill"
    EMOJI=$(sed -n 's/.*"emoji": *"\([^"]*\)".*/\1/p' "$skill_dir/SKILL.md" | head -1)
    [ -z "$EMOJI" ] && EMOJI="📦"

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

# Merge workspace skills
if [ -d "$WORKSPACE_SKILLS_DIR" ]; then
  python3 - << PY
import json, os
site_path = "$SITE_DIR/data/skills.json"
ws_dir = "$WORKSPACE_SKILLS_DIR"

data = json.load(open(site_path))
added = 0
for name in sorted(os.listdir(ws_dir)):
    md = os.path.join(ws_dir, name, "SKILL.md")
    if os.path.isfile(md):
        data["skills"][name] = {
            "name": name,
            "description": "Workspace Custom Skill",
            "category": "utilities",
            "location": os.path.join(ws_dir, name) + "/",
            "icon": "🛠️",
        }
        added += 1
json.dump(data, open(site_path, "w"), indent=2, ensure_ascii=False)
print(f"Merged {added} workspace skills")
PY
fi

# 6) site.json + index.md
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
  "stats": {
    "totalSkills": $TOTAL_SKILLS,
    "totalDocs": $DOC_COUNT
  }
}
EOF

cat > "$COLLECTOR_DIR/index.md" << EOF
# OpenClaw Collection Index

**Last Updated**: $DATE

- Built-in Skills: $SKILL_COUNT
- Workspace Skills: $WORKSPACE_SKILL_COUNT
- Total Skills: $TOTAL_SKILLS
- Docs: $DOC_COUNT

## Recent runs

$(ls -1 "$DATA_DIR/" | tail -10)
EOF

{
  echo "=== [$DATE] 收集完成 (lite) ==="
  echo "Skills: $SKILL_COUNT (built-in) + $WORKSPACE_SKILL_COUNT (workspace) = $TOTAL_SKILLS"
  echo "Docs: $DOC_COUNT"
} >> "$LOG_FILE"

echo "OK $DATE Skills=$TOTAL_SKILLS Docs=$DOC_COUNT"
