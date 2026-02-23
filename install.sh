#!/usr/bin/env bash
set -euo pipefail

# elastic-docs-skills installer
# Interactive TUI for installing Claude Code skills from the catalog

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
INSTALL_DIR="$HOME/.claude/skills"

# Colors (used when gum is not available for basic output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Helpers ────────────────────────────────────────────────────────────────

info()  { echo -e "${CYAN}${BOLD}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}${BOLD}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}${BOLD}⚠${NC} $1"; }
err()   { echo -e "${RED}${BOLD}✗${NC} $1" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Interactive installer for elastic-docs-skills catalog.

Options:
  --list          List all available skills and exit
  --all           Install all skills (non-interactive)
  --uninstall NAME  Remove an installed skill
  --help          Show this help message

Without options, launches an interactive TUI to select skills.
Requires gum (https://github.com/charmbracelet/gum).
EOF
}

# ─── Gum dependency ─────────────────────────────────────────────────────────

check_gum() {
  if command -v gum &>/dev/null; then
    return 0
  fi
  return 1
}

install_gum() {
  echo ""
  warn "gum is required for the interactive installer."
  echo "  https://github.com/charmbracelet/gum"
  echo ""

  if command -v brew &>/dev/null; then
    read -rp "Install gum via Homebrew? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
      brew install gum
      return 0
    fi
  elif command -v apt-get &>/dev/null; then
    read -rp "Install gum via apt? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
      echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
      sudo apt-get update && sudo apt-get install -y gum
      return 0
    fi
  elif command -v dnf &>/dev/null; then
    read -rp "Install gum via dnf? [Y/n] " answer
    if [[ "${answer:-Y}" =~ ^[Yy]$ ]]; then
      echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
      sudo dnf install -y gum
      return 0
    fi
  fi

  err "Please install gum manually: https://github.com/charmbracelet/gum#installation"
  exit 1
}

# ─── Skill scanning ─────────────────────────────────────────────────────────

# Parse frontmatter value from a SKILL.md file
parse_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}: *//"
}

# Collect all skills into parallel arrays
declare -a SKILL_PATHS=()
declare -a SKILL_NAMES=()
declare -a SKILL_VERSIONS=()
declare -a SKILL_DESCRIPTIONS=()
declare -a SKILL_CATEGORIES=()

scan_skills() {
  SKILL_PATHS=()
  SKILL_NAMES=()
  SKILL_VERSIONS=()
  SKILL_DESCRIPTIONS=()
  SKILL_CATEGORIES=()

  while IFS= read -r skill_file; do
    local name version description category rel_path

    name="$(parse_field "$skill_file" "name")"
    version="$(parse_field "$skill_file" "version")"
    description="$(parse_field "$skill_file" "description")"

    # Extract category from path: skills/<category>/<name>/SKILL.md
    rel_path="${skill_file#"$SKILLS_DIR/"}"
    category="$(echo "$rel_path" | cut -d'/' -f1)"

    if [[ -z "$name" ]]; then
      warn "Skipping $skill_file — missing name field"
      continue
    fi

    SKILL_PATHS+=("$skill_file")
    SKILL_NAMES+=("$name")
    SKILL_VERSIONS+=("${version:-0.0.0}")
    SKILL_DESCRIPTIONS+=("${description:-No description}")
    SKILL_CATEGORIES+=("$category")
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -type f 2>/dev/null | sort)

  if [[ ${#SKILL_NAMES[@]} -eq 0 ]]; then
    err "No skills found in $SKILLS_DIR"
    exit 1
  fi
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd_list() {
  scan_skills

  printf "\n${BOLD}%-20s %-12s %-10s %s${NC}\n" "NAME" "CATEGORY" "VERSION" "DESCRIPTION"
  printf "%-20s %-12s %-10s %s\n" "────────────────────" "────────────" "──────────" "────────────────────────────────────────"

  for i in "${!SKILL_NAMES[@]}"; do
    local installed=""
    if [[ -f "$INSTALL_DIR/${SKILL_NAMES[$i]}/SKILL.md" ]]; then
      installed=" ${GREEN}(installed)${NC}"
    fi
    printf "%-20s %-12s %-10s %s${installed}\n" \
      "${SKILL_NAMES[$i]}" \
      "${SKILL_CATEGORIES[$i]}" \
      "${SKILL_VERSIONS[$i]}" \
      "${SKILL_DESCRIPTIONS[$i]:0:50}"
  done
  echo ""
}

cmd_uninstall() {
  local name="$1"
  local target="$INSTALL_DIR/$name"

  if [[ ! -d "$target" ]]; then
    err "Skill '$name' is not installed at $target"
    exit 1
  fi

  rm -rf "$target"
  ok "Uninstalled skill '$name'"
}

install_skill() {
  local index="$1"
  local name="${SKILL_NAMES[$index]}"
  local version="${SKILL_VERSIONS[$index]}"
  local source_dir
  source_dir="$(dirname "${SKILL_PATHS[$index]}")"
  local target="$INSTALL_DIR/$name"

  mkdir -p "$target"
  cp -r "$source_dir"/* "$target"/
  ok "Installed ${BOLD}$name${NC} v$version → $target"
}

cmd_install_all() {
  scan_skills
  mkdir -p "$INSTALL_DIR"

  info "Installing all ${#SKILL_NAMES[@]} skills..."
  echo ""

  for i in "${!SKILL_NAMES[@]}"; do
    install_skill "$i"
  done

  echo ""
  ok "All skills installed to $INSTALL_DIR"
}

cmd_interactive() {
  if ! check_gum; then
    install_gum
    if ! check_gum; then
      exit 1
    fi
  fi

  scan_skills

  # Build display lines for gum filter
  local options=()
  for i in "${!SKILL_NAMES[@]}"; do
    local installed=""
    if [[ -f "$INSTALL_DIR/${SKILL_NAMES[$i]}/SKILL.md" ]]; then
      installed=" [installed]"
    fi
    options+=("$(printf "%-20s  %-12s  v%-8s  %s%s" \
      "${SKILL_NAMES[$i]}" \
      "${SKILL_CATEGORIES[$i]}" \
      "${SKILL_VERSIONS[$i]}" \
      "${SKILL_DESCRIPTIONS[$i]:0:45}" \
      "$installed")")
  done

  # Header
  gum style \
    --border rounded \
    --border-foreground 212 \
    --padding "1 2" \
    --margin "1 0" \
    "🛠  elastic-docs-skills installer" \
    "" \
    "Select skills to install (use TAB to select, ENTER to confirm)"

  # Multi-select with gum filter
  local selected
  selected=$(printf '%s\n' "${options[@]}" | gum filter --no-limit --height 20 --placeholder "Type to filter skills...") || true

  if [[ -z "$selected" ]]; then
    warn "No skills selected."
    exit 0
  fi

  echo ""
  mkdir -p "$INSTALL_DIR"

  # Match selections back to skill indices and install
  local count=0
  while IFS= read -r line; do
    # Extract skill name (first field, trimmed)
    local selected_name
    selected_name="$(echo "$line" | awk '{print $1}')"

    for i in "${!SKILL_NAMES[@]}"; do
      if [[ "${SKILL_NAMES[$i]}" == "$selected_name" ]]; then
        install_skill "$i"
        ((count++))
        break
      fi
    done
  done <<< "$selected"

  echo ""
  gum style \
    --foreground 212 \
    --bold \
    "✓ Installed $count skill(s) to $INSTALL_DIR"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
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
        err "Usage: $(basename "$0") --uninstall <skill-name>"
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
