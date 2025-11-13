# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

-   GitHub Actions release workflow to build Android artifacts on tag push.

### Changed

-   UI: compacted headers and search areas for improved mobile density.
-   Item detail: made drawer content scrollable and action buttons fixed at bottom.

### Fixed

-   Prevent RenderFlex overflow in item detail and other screens by making content scrollable.
-   Offloaded heavy JSON parsing and image cropping/encoding to background isolates to reduce UI jank.

### Other

-   Deferred initial data load until after first frame to avoid first-frame jank.
-   Image crop preview: add "Use original photo" option.

## [v1.0.1] - 2025-11-13

### Fixed

-   Fix item deletion when restoring from history. See commit 08235c6 and pull request #3.

## [0.1.0] - 2025-11-07

-   Release candidate including UI compaction, performance improvements, and several refactors.

> Generated from recent commit history. For full commit list use `git log`.
