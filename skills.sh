#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m'

usage() {
    echo -e "${BOLD}skills.sh${NC} — Claude Code Skill Manager"
    echo ""
    echo "Usage:"
    echo "  ./skills.sh list              List all available skills (sorted)"
    echo "  ./skills.sh info <skill>      Show details for a skill"
    echo "  ./skills.sh install <skill>   Install a skill to ~/.claude/skills/"
    echo "  ./skills.sh install --all     Install all skills"
    echo "  ./skills.sh uninstall <skill> Remove an installed skill"
    echo ""
    echo -e "Install dir: ${DIM}$INSTALL_DIR${NC}"
    echo -e "Override:    ${DIM}CLAUDE_SKILLS_DIR=/path ./skills.sh install ...${NC}"
}

# Extract YAML frontmatter field from a string
_yaml_field() {
    local content="$1"
    local field="$2"
    echo "$content" | awk -v f="$field" '
        /^---/{block++; next}
        block==1 && $0 ~ "^"f":" {
            sub("^"f":[[:space:]]*", "")
            print; exit
        }
    '
}

# Get all SKILL.md paths inside a zip (handles bundles with multiple skills)
_zip_skills() {
    local zip="$1"
    unzip -Z1 "$zip" 2>/dev/null | grep 'SKILL\.md$' | sort
}

# Check if a skill dir is installed
_is_installed() {
    local name="$1"
    [[ -f "$INSTALL_DIR/$name/SKILL.md" ]]
}

# ─── list ─────────────────────────────────────────────────────────────────────

list_skills() {
    echo -e "${BOLD}Available Skills${NC}"
    echo "────────────────────────────────────────────────────────────"

    # Collect: name|description|source_zip, then sort by name
    local entries=()
    while IFS= read -r -d '' zip; do
        local zipbase
        zipbase=$(basename "$zip" .zip)
        while IFS= read -r skillmd; do
            local content
            content=$(unzip -p "$zip" "$skillmd" 2>/dev/null | head -20)
            local name desc
            name=$(_yaml_field "$content" "name")
            desc=$(_yaml_field "$content" "description")
            # Trim description to first sentence / 80 chars
            desc=$(echo "$desc" | cut -c1-80)
            [[ -z "$name" ]] && name="$zipbase"
            entries+=("$name|$desc|$zipbase")
        done < <(_zip_skills "$zip")
    done < <(find "$REPO_DIR" -maxdepth 1 -name "*.zip" -print0 | sort -z)

    # Deduplicate by name (bundle re-ships same skills), sort by name
    declare -A seen
    local sorted
    sorted=$(printf '%s\n' "${entries[@]}" | sort -t'|' -k1,1)

    while IFS='|' read -r name desc src; do
        [[ -v "seen[$name]" ]] && continue
        seen["$name"]=1
        local tag=""
        _is_installed "$name" && tag=" ${GREEN}[installed]${NC}"
        echo -e "  ${BOLD}${CYAN}$name${NC}${tag}"
        [[ -n "$desc" ]] && echo -e "  ${DIM}$desc${NC}…"
        echo -e "  ${DIM}source: $src.zip${NC}"
        echo ""
    done <<< "$sorted"

    echo -e "Install with: ${YELLOW}./skills.sh install <name>${NC}  or  ${YELLOW}./skills.sh install --all${NC}"
}

# ─── info ─────────────────────────────────────────────────────────────────────

info_skill() {
    local target="$1"
    local found=false

    while IFS= read -r -d '' zip; do
        [[ "$found" == "true" ]] && break
        while IFS= read -r skillmd; do
            local content
            content=$(unzip -p "$zip" "$skillmd" 2>/dev/null | head -30)
            local name
            name=$(_yaml_field "$content" "name")
            [[ "$name" != "$target" ]] && continue
            found=true

            local desc
            desc=$(_yaml_field "$content" "description")
            echo -e "${BOLD}${CYAN}$name${NC}"
            echo "────────────────────────────────────────────────────────────"
            echo -e "${DIM}$desc${NC}"
            echo ""
            echo "Files:"
            unzip -Z1 "$zip" 2>/dev/null | grep "^$name/" | sed 's/^/  /'
            echo ""
            _is_installed "$name" \
                && echo -e "Status: ${GREEN}installed${NC} → $INSTALL_DIR/$name/" \
                || echo -e "Status: ${DIM}not installed${NC}"
            echo ""
            echo -e "Install: ${YELLOW}./skills.sh install $name${NC}"
            break
        done < <(_zip_skills "$zip")
    done < <(find "$REPO_DIR" -maxdepth 1 -name "*.zip" -print0 | sort -z)

    if [[ "$found" == "false" ]]; then
        echo -e "${RED}Skill '$target' not found.${NC} Run './skills.sh list' to see all skills."
        exit 1
    fi
}

# ─── install ──────────────────────────────────────────────────────────────────

_install_one() {
    local zip="$1"
    local skillmd="$2"  # e.g. "clean-java/SKILL.md"
    local name="$3"

    # Extract only files under this skill's directory
    local prefix="${skillmd%/SKILL.md}"
    mkdir -p "$INSTALL_DIR"
    unzip -o "$zip" "$prefix/*" -d "$INSTALL_DIR" > /dev/null 2>&1
    echo -e "  ${GREEN}✓${NC} ${BOLD}$name${NC} → $INSTALL_DIR/$name/"
}

install_skill() {
    local target="$1"
    local found=false

    while IFS= read -r -d '' zip; do
        [[ "$found" == "true" ]] && break
        while IFS= read -r skillmd; do
            local content
            content=$(unzip -p "$zip" "$skillmd" 2>/dev/null | head -10)
            local name
            name=$(_yaml_field "$content" "name")
            [[ "$name" != "$target" ]] && continue
            found=true
            _install_one "$zip" "$skillmd" "$name"
            break
        done < <(_zip_skills "$zip")
    done < <(find "$REPO_DIR" -maxdepth 1 -name "*.zip" -print0 | sort -z)

    if [[ "$found" == "false" ]]; then
        echo -e "${RED}Skill '$target' not found.${NC} Run './skills.sh list' to see all skills."
        exit 1
    fi
}

install_all() {
    echo -e "${BOLD}Installing all skills${NC} → $INSTALL_DIR"
    echo "────────────────────────────────────────────────────────────"
    declare -A seen
    local count=0

    while IFS= read -r -d '' zip; do
        while IFS= read -r skillmd; do
            local content
            content=$(unzip -p "$zip" "$skillmd" 2>/dev/null | head -10)
            local name
            name=$(_yaml_field "$content" "name")
            [[ -v "seen[$name]" ]] && continue
            seen["$name"]=1
            _install_one "$zip" "$skillmd" "$name"
            ((count++))
        done < <(_zip_skills "$zip")
    done < <(find "$REPO_DIR" -maxdepth 1 -name "*.zip" -print0 | sort -z)

    echo ""
    echo -e "${GREEN}Done. Installed $count skill(s).${NC}"
}

# ─── uninstall ────────────────────────────────────────────────────────────────

uninstall_skill() {
    local name="$1"
    local dir="$INSTALL_DIR/$name"
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Skill '$name' is not installed at $dir${NC}"
        exit 1
    fi
    rm -rf "$dir"
    echo -e "${GREEN}✓ Removed${NC} $dir"
}

# ─── main ─────────────────────────────────────────────────────────────────────

case "${1:-list}" in
    list)        list_skills ;;
    info)        [[ -z "${2:-}" ]] && { usage; exit 1; }; info_skill "$2" ;;
    install)
        [[ -z "${2:-}" ]] && { usage; exit 1; }
        [[ "$2" == "--all" ]] && install_all || install_skill "$2"
        ;;
    uninstall)   [[ -z "${2:-}" ]] && { usage; exit 1; }; uninstall_skill "$2" ;;
    help|--help|-h) usage ;;
    *) echo -e "${RED}Unknown command: $1${NC}"; usage; exit 1 ;;
esac
