# Changelog

All notable changes to `milestone-designer` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-12

Initial scaffold baseline — no prior releases.

### Added
- Plugin manifest `.claude-plugin/plugin.json` (`name`, `description`, `version`).
- Marketplace manifest `.claude-plugin/marketplace.json` mirroring the sibling suite plugins' layout.
- MIT `LICENSE`.
- CI floor: the skill-size gate `scripts/check-skill-size.sh` and its PowerShell 7+ twin `scripts/check-skill-size.ps1`, plus the plugin-structure preflight `scripts/validate-plugin-structure.py`.
- Standalone, fixture-driven test harness for the skill-size gate: `tests/check-skill-size.test.sh` and `tests/check-skill-size.test.ps1`.
