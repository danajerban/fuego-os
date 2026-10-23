# Changelog

All notable changes to this project are listed here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The plan ([the spec](https://github.com/danajerban/fuego-os/issues/1)), the glossary, research notes, and the repository's community files.
- The four package lists (Keep, Must-Keep, Known-Bloat, Takeover Packages) under `lists/`, with a check that the Must-Keep List wins and no Takeover Package is Known-Bloat.
- The script's base (`script/fuego`): `check` names the tools the Mac is missing, `pair` and `connect` reach the TV over Wireless debugging, and an unreachable TV gets the Settings path to turn Wireless debugging back on ([TV setup steps](docs/tv-setup.md)). Script tests run against a fake TV with `script/tests/run`.
