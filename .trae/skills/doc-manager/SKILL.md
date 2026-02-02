---
name: "doc-manager"
description: "Manages project documentation structure and rules. Invoke when user wants to create docs, organize files, or asks about documentation standards."
---

# Documentation Manager

This skill enforces the system-level documentation rules defined in `docs/system/DOCUMENTATION_MANAGEMENT_RULE.md`.

## Core Responsibilities
1. **Classification**: Ensure all markdown files in `docs/` are categorized.
2. **Syncing**: Maintain 1:1 mapping between `docs/<category>/` and `.trae/skills/<skill>/`.
3. **Evolution**: Update existing docs instead of creating duplicates.

## Reference
[DOCUMENTATION_MANAGEMENT_RULE.md](file:///root/zzp/langextract-main/ljt/note-prompt/docs/system/DOCUMENTATION_MANAGEMENT_RULE.md)
