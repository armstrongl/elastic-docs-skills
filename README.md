# AGENTS.md file for Elastic documentation

This repository contains comprehensive instructions for AI agents responsible for authoring and maintaining Elastic documentation.

For more information, refer to [AGENTS.md](AGENTS.md).

## Purpose

The `AGENTS.md` file serves as a comprehensive guide that AI agents must follow when working with Elastic documentation. It ensures consistency, accessibility, and adherence to Elastic's documentation standards across all content.

## What's in AGENTS.md

The file covers essential topics including:

- Core principles of Elastic documentation (cumulative docs, voice/tone, accessibility)
- The `docs-builder` system and how to structure content correctly
- Substitutions (e.g., `{{edot}}`, `{{ess}}`) and when to use them
- Comments using `%` syntax and their importance for maintenance
- Content organization components:
  - Dropdowns for progressive disclosure
  - Tabs for variant instructions
  - Stepper components for complex procedures
- Linking strategies with absolute paths for better maintainability
- The `applies_to` mechanism for version-specific content filtering
- Style and formatting guidelines for consistent presentation
- Handling urgent updates and complex version scenarios

## How to use

The idea behind an AGENTS.md file is that it's always available as workspace / repo context. Place it in the root of your repository and rename it accordingly to your LLM agent preferences (for example, Claude Code uses `CLAUDE.md`). Most agents are now following the `AGENTS.md` convention.

Before starting an agentic session, ask the agent if it's aware of the file and its contents. You can also upload the file manually as context.