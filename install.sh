#!/usr/bin/env bash
set -euo pipefail

# elastic-docs-skills installer
# Interactive TUI for installing Claude Code skills from the catalog
# Zero external dependencies — uses Python 3 curses (ships with macOS/Linux)
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/elastic/elastic-docs-skills/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/elastic/elastic-docs-skills/main/install.sh | bash -s -- --list
#   curl -sSL https://raw.githubusercontent.com/elastic/elastic-docs-skills/main/install.sh | bash -s -- --all

REPO="elastic/elastic-docs-skills"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"
API_BASE="https://api.github.com/repos/$REPO"
INSTALL_DIR="$HOME/.claude/skills"

# Detect if running from a local clone
LOCAL_MODE=false
SCRIPT_DIR=""
SKILLS_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -d "$SCRIPT_DIR/skills" ]]; then
    LOCAL_MODE=true
    SKILLS_DIR="$SCRIPT_DIR/skills"
  fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}${BOLD}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}${BOLD}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}${BOLD}⚠${NC} $1"; }
err()   { echo -e "${RED}${BOLD}✗${NC} $1" >&2; }

usage() {
  cat <<EOF
Usage: install.sh [OPTIONS]

Interactive installer for elastic-docs-skills catalog.
Works both from a local clone and via curl from GitHub.
Requires Python 3 (ships with macOS and most Linux distributions).

Options:
  --list            List all available skills and exit
  --all             Install all skills (non-interactive)
  --uninstall NAME  Remove an installed skill
  --help            Show this help message

Without options, launches an interactive TUI to select skills.
EOF
}

# ─── Skill scanning (bash) ──────────────────────────────────────────────────

parse_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}: *//"
}

parse_field_from_content() {
  local content="$1" field="$2"
  echo "$content" | sed -n '/^---$/,/^---$/p' | grep "^${field}:" | head -1 | sed "s/^${field}: *//"
}

# Builds a TSV catalog: name\tversion\tcategory\tdescription\tpath
build_catalog_local() {
  while IFS= read -r skill_file; do
    local name version description category rel_path
    name="$(parse_field "$skill_file" "name")"
    [[ -z "$name" ]] && continue
    version="$(parse_field "$skill_file" "version")"
    description="$(parse_field "$skill_file" "description")"
    rel_path="${skill_file#"$SKILLS_DIR/"}"
    category="$(echo "$rel_path" | cut -d'/' -f1)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "${version:-0.0.0}" "$category" "${description:-No description}" "$skill_file"
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)
}

build_catalog_remote() {
  info "Fetching skill catalog from GitHub..."
  local tree_response
  tree_response=$(curl -fsSL "${API_BASE}/git/trees/${BRANCH}?recursive=1" 2>/dev/null) || {
    err "Failed to fetch repository tree from GitHub"; exit 1
  }
  local skill_paths
  skill_paths=$(echo "$tree_response" | grep -o '"path":"skills/[^"]*SKILL\.md"' | sed 's/"path":"//;s/"//' | sort)
  [[ -z "$skill_paths" ]] && { err "No skills found in the remote catalog"; exit 1; }

  while IFS= read -r remote_path; do
    local content name version description category
    content=$(curl -fsSL "${RAW_BASE}/${remote_path}" 2>/dev/null) || continue
    name="$(parse_field_from_content "$content" "name")"
    [[ -z "$name" ]] && continue
    version="$(parse_field_from_content "$content" "version")"
    description="$(parse_field_from_content "$content" "description")"
    category="$(echo "$remote_path" | cut -d'/' -f2)"
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "${version:-0.0.0}" "$category" "${description:-No description}" "$remote_path"
  done <<< "$skill_paths"
}

build_catalog() {
  if [[ "$LOCAL_MODE" == true ]]; then
    build_catalog_local
  else
    build_catalog_remote
  fi
}

# ─── Installation helpers ────────────────────────────────────────────────────

install_one_local() {
  local name="$1" path="$2" version="$3"
  local source_dir target
  source_dir="$(dirname "$path")"
  target="$INSTALL_DIR/$name"
  mkdir -p "$target"
  cp -r "$source_dir"/* "$target"/
  ok "Installed ${BOLD}$name${NC} v$version → $target"
}

install_one_remote() {
  local name="$1" remote_path="$2" version="$3"
  local remote_dir target
  remote_dir="$(dirname "$remote_path")"
  target="$INSTALL_DIR/$name"
  mkdir -p "$target"

  curl -fsSL "${RAW_BASE}/${remote_path}" -o "$target/SKILL.md" 2>/dev/null || {
    err "Failed to download $name"; return 1
  }

  # Fetch any supplementary files
  local tree_response extra_files
  tree_response=$(curl -fsSL "${API_BASE}/git/trees/${BRANCH}?recursive=1" 2>/dev/null) || true
  extra_files=$(echo "$tree_response" | grep -o "\"path\":\"${remote_dir}/[^\"]*\"" | sed 's/"path":"//;s/"//' | grep -v "SKILL\.md$" || true)
  while IFS= read -r extra_path; do
    [[ -z "$extra_path" ]] && continue
    local filename="${extra_path#"$remote_dir/"}"
    mkdir -p "$target/$(dirname "$filename")"
    curl -fsSL "${RAW_BASE}/${extra_path}" -o "$target/$filename" 2>/dev/null || true
  done <<< "$extra_files"

  ok "Installed ${BOLD}$name${NC} v$version → $target"
}

install_one() {
  if [[ "$LOCAL_MODE" == true ]]; then
    install_one_local "$@"
  else
    install_one_remote "$@"
  fi
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd_list() {
  local catalog
  catalog="$(build_catalog)"
  [[ -z "$catalog" ]] && { err "No skills found"; exit 1; }

  printf "\n${BOLD}%-20s %-12s %-10s %s${NC}\n" "NAME" "CATEGORY" "VERSION" "DESCRIPTION"
  printf "%-20s %-12s %-10s %s\n" "────────────────────" "────────────" "──────────" "────────────────────────────────────────"

  while IFS=$'\t' read -r name version category description path; do
    local installed=""
    [[ -f "$INSTALL_DIR/$name/SKILL.md" ]] && installed=" ${GREEN}(installed)${NC}"
    printf "%-20s %-12s %-10s %s${installed}\n" "$name" "$category" "$version" "${description:0:50}"
  done <<< "$catalog"
  echo ""
}

cmd_uninstall() {
  local name="$1"
  local target="$INSTALL_DIR/$name"
  [[ ! -d "$target" ]] && { err "Skill '$name' is not installed at $target"; exit 1; }
  rm -rf "$target"
  ok "Uninstalled skill '$name'"
}

cmd_install_all() {
  local catalog
  catalog="$(build_catalog)"
  [[ -z "$catalog" ]] && { err "No skills found"; exit 1; }
  mkdir -p "$INSTALL_DIR"

  local count=0
  while IFS=$'\t' read -r name version category description path; do
    install_one "$name" "$path" "$version"
    ((count++))
  done <<< "$catalog"

  echo ""
  ok "Installed $count skill(s) to $INSTALL_DIR"
}

cmd_interactive() {
  # Check Python 3 is available
  local python_cmd=""
  for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; assert sys.version_info >= (3, 6)" 2>/dev/null; then
      python_cmd="$cmd"
      break
    fi
  done
  if [[ -z "$python_cmd" ]]; then
    err "Python 3.6+ is required for the interactive installer."
    echo "  Use --list and --all for non-interactive mode."
    exit 1
  fi

  # Build catalog TSV
  local catalog
  catalog="$(build_catalog)"
  [[ -z "$catalog" ]] && { err "No skills found"; exit 1; }

  # Launch Python curses TUI, passing catalog via env, get selected names back
  local selected
  selected=$(CATALOG="$catalog" "$python_cmd" -c '
import curses
import sys
import os

def main(stdscr):
    curses.curs_set(0)
    curses.use_default_colors()
    curses.start_color()
    curses.init_pair(1, curses.COLOR_CYAN, -1)     # header/title
    curses.init_pair(2, curses.COLOR_GREEN, -1)     # selected marker
    curses.init_pair(3, curses.COLOR_YELLOW, -1)    # installed tag
    curses.init_pair(4, curses.COLOR_WHITE, curses.COLOR_BLUE)  # cursor highlight
    curses.init_pair(5, curses.COLOR_MAGENTA, -1)   # summary

    install_dir = os.path.expanduser("~/.claude/skills")

    # Parse catalog from env
    catalog_raw = os.environ.get("CATALOG", "")
    items = []
    for line in catalog_raw.strip().split("\n"):
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) >= 5:
            name, version, category, description, path = parts[0], parts[1], parts[2], parts[3], parts[4]
            installed = os.path.isfile(os.path.join(install_dir, name, "SKILL.md"))
            items.append({
                "name": name,
                "version": version,
                "category": category,
                "description": description,
                "path": path,
                "installed": installed,
                "selected": False,
            })

    if not items:
        return ""

    cursor = 0
    scroll_offset = 0
    filter_text = ""

    def get_filtered():
        if not filter_text:
            return list(range(len(items)))
        ft = filter_text.lower()
        return [i for i, it in enumerate(items)
                if ft in it["name"].lower()
                or ft in it["category"].lower()
                or ft in it["description"].lower()]

    while True:
        stdscr.clear()
        max_y, max_x = stdscr.getmaxyx()
        filtered = get_filtered()

        # Title
        title = " elastic-docs-skills installer "
        stdscr.attron(curses.color_pair(1) | curses.A_BOLD)
        stdscr.addnstr(0, max(0, (max_x - len(title)) // 2), title, max_x - 1)
        stdscr.attroff(curses.color_pair(1) | curses.A_BOLD)

        # Help line
        help_text = "SPACE=toggle  ENTER=install  /=filter  a=all  n=none  q=quit"
        stdscr.addnstr(1, max(0, (max_x - len(help_text)) // 2), help_text, max_x - 1)

        # Filter bar
        if filter_text:
            filter_display = f" Filter: {filter_text}_ "
        else:
            filter_display = " Type / to filter "
        stdscr.addnstr(2, 0, filter_display, max_x - 1, curses.color_pair(1))

        # Column header
        header_y = 3
        hdr = f"  {'':3s} {'NAME':<20s} {'CATEGORY':<12s} {'VERSION':<10s} DESCRIPTION"
        stdscr.attron(curses.A_BOLD)
        stdscr.addnstr(header_y, 0, hdr[:max_x - 1], max_x - 1)
        stdscr.attroff(curses.A_BOLD)

        # Separator
        stdscr.addnstr(header_y + 1, 0, "─" * min(max_x - 1, 80), max_x - 1)

        # List area
        list_start_y = header_y + 2
        list_height = max_y - list_start_y - 2  # reserve 2 lines at bottom
        if list_height < 1:
            list_height = 1

        # Adjust scroll
        if cursor < scroll_offset:
            scroll_offset = cursor
        if cursor >= scroll_offset + list_height:
            scroll_offset = cursor - list_height + 1

        for row_idx in range(list_height):
            fi = scroll_offset + row_idx
            if fi >= len(filtered):
                break
            item_idx = filtered[fi]
            item = items[item_idx]

            marker = "[x]" if item["selected"] else "[ ]"
            tag = " *" if item["installed"] else ""
            line = f"  {marker} {item['name']:<20s} {item['category']:<12s} v{item['version']:<9s} {item['description'][:max_x - 55]}{tag}"

            y = list_start_y + row_idx
            if y >= max_y - 2:
                break

            if fi == cursor:
                stdscr.attron(curses.color_pair(4))
                stdscr.addnstr(y, 0, line[:max_x - 1].ljust(max_x - 1), max_x - 1)
                stdscr.attroff(curses.color_pair(4))
            elif item["selected"]:
                stdscr.attron(curses.color_pair(2))
                stdscr.addnstr(y, 0, line[:max_x - 1], max_x - 1)
                stdscr.attroff(curses.color_pair(2))
            else:
                stdscr.addnstr(y, 0, line[:max_x - 1], max_x - 1)

        # Status bar
        selected_count = sum(1 for it in items if it["selected"])
        status = f" {selected_count} selected | {len(filtered)}/{len(items)} skills | * = installed "
        status_y = max_y - 1
        stdscr.attron(curses.color_pair(5) | curses.A_BOLD)
        stdscr.addnstr(status_y, 0, status[:max_x - 1], max_x - 1)
        stdscr.attroff(curses.color_pair(5) | curses.A_BOLD)

        stdscr.refresh()
        key = stdscr.getch()

        if key == ord("q") or key == 27:  # q or ESC
            return ""
        elif key == ord("\n") or key == curses.KEY_ENTER or key == 10 or key == 13:
            selected_names = [it["name"] for it in items if it["selected"]]
            return "\n".join(selected_names)
        elif key == curses.KEY_UP or key == ord("k"):
            if cursor > 0:
                cursor -= 1
        elif key == curses.KEY_DOWN or key == ord("j"):
            if cursor < len(filtered) - 1:
                cursor += 1
        elif key == ord(" "):
            if filtered:
                idx = filtered[cursor]
                items[idx]["selected"] = not items[idx]["selected"]
                if cursor < len(filtered) - 1:
                    cursor += 1
        elif key == ord("a"):
            for fi in filtered:
                items[fi]["selected"] = True
        elif key == ord("n"):
            for fi in filtered:
                items[fi]["selected"] = False
        elif key == ord("/"):
            # Enter filter mode
            filter_text = ""
            cursor = 0
            scroll_offset = 0
            stdscr.nodelay(False)
            while True:
                # Redraw filter bar
                if filter_text:
                    fd = f" Filter: {filter_text}_ (ESC to clear) "
                else:
                    fd = " Filter: _ (type to search, ESC to clear) "
                stdscr.addnstr(2, 0, fd[:max_x - 1].ljust(max_x - 1), max_x - 1, curses.color_pair(1))
                stdscr.refresh()
                fk = stdscr.getch()
                if fk == 27:  # ESC
                    filter_text = ""
                    cursor = 0
                    scroll_offset = 0
                    break
                elif fk == ord("\n") or fk == 10 or fk == 13:
                    cursor = 0
                    scroll_offset = 0
                    break
                elif fk == curses.KEY_BACKSPACE or fk == 127 or fk == 8:
                    filter_text = filter_text[:-1]
                    cursor = 0
                    scroll_offset = 0
                elif 32 <= fk <= 126:
                    filter_text += chr(fk)
                    cursor = 0
                    scroll_offset = 0

result = curses.wrapper(main)
if result:
    print(result)
' <<< "" 2>/dev/null) || true

  if [[ -z "$selected" ]]; then
    echo ""
    warn "No skills selected."
    exit 0
  fi

  echo ""
  mkdir -p "$INSTALL_DIR"

  local count=0
  while IFS= read -r selected_name; do
    [[ -z "$selected_name" ]] && continue
    while IFS=$'\t' read -r name version category description path; do
      if [[ "$name" == "$selected_name" ]]; then
        install_one "$name" "$path" "$version"
        ((count++))
        break
      fi
    done <<< "$catalog"
  done <<< "$selected"

  echo ""
  ok "Installed $count skill(s) to $INSTALL_DIR"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  if [[ "$LOCAL_MODE" == true ]]; then
    info "Running from local clone: $SCRIPT_DIR"
  else
    info "Running in remote mode — fetching from github.com/$REPO"
  fi

  case "${1:-}" in
    --help|-h)
      usage
      ;;
    --list)
      cmd_list
      ;;
    --all)
      cmd_install_all
      ;;
    --uninstall)
      if [[ -z "${2:-}" ]]; then
        err "Usage: install.sh --uninstall <skill-name>"
        exit 1
      fi
      cmd_uninstall "$2"
      ;;
    "")
      cmd_interactive
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
}

main "$@"
