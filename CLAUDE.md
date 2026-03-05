# Elastic Docs Skills — Project Guide

## What this repo is

A catalog of Claude Code skills for Elastic documentation workflows. Skills are installed into `~/.claude/skills/` via `install.sh` and used as slash commands or auto-triggered behaviors in Claude Code.

## Repository layout

```
skills/<category>/<skill-name>/
  SKILL.md          # The skill definition (frontmatter + instructions)
  evals/evals.json  # Test cases for the skill (optional but encouraged)
.claude/skills/     # Skills that work within this repo only (e.g., /create-skill)
.github/workflows/  # CI and gh-aw agentic workflows
.github/agents/     # Copilot agent definitions
```

## Skill anatomy

Every `skills/**/SKILL.md` must have YAML frontmatter:

```yaml
---
name: my-skill              # Required — kebab-case, must match directory name
version: 1.0.0              # Required — SemVer
description: What it does    # Required — when to trigger this skill
argument-hint: <args>        # Shown in autocomplete if skill accepts input
disable-model-invocation: true  # Only via /my-skill, not auto-triggered
context: fork                # Run in isolated subagent
allowed-tools: Read, Grep    # Tools available without user approval
sources:                     # Upstream URLs this skill encodes (for freshness checks)
  - https://www.elastic.co/docs/some-page
---
```

## Categories

- **authoring** — Skills that help write or edit documentation content
- **review** — Skills that validate, lint, or check existing content
- **workflow** — Skills for meta-tasks (retros, session analysis, project management)

## Conventions

- Skill names are kebab-case and must match their directory name
- Version follows SemVer: bump PATCH for fixes, MINOR for new features, MAJOR for breaking changes
- Skills that only read/analyze should use `context: fork`
- Skills that modify files should NOT use `context: fork`
- All skills that accept `$ARGUMENTS` should have `argument-hint`
- Skills derived from upstream docs should list URLs in `sources:` frontmatter

## gh-aw workflows

Agentic workflows use `.md` files compiled to `.lock.yml` via `gh aw compile`. The lock files are auto-generated — never edit them directly. The `.gitattributes` file marks them as `linguist-generated=true merge=ours`.

## Adding a skill

Use `/create-skill` within this repo, or see `CONTRIBUTING.md` for manual instructions.

## Running CI locally

```bash
# Validate all skills
find skills -name "SKILL.md" -type f -exec echo "Checking {}" \;

# Validate eval JSON
find skills -name "evals.json" -exec python3 -m json.tool {} \;
```
