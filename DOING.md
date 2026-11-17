# DOING.md

This document, inspired by [this tweet](https://twitter.com/drwave/status/1564063331341590529), contains the currently in progress or planned features for Boop.

This document was last updated *<u>November 17th, 2026</u>*.

## In progress

Nothing right now.

## Planned

Nothing right now.

## Done

### Compression Scripts

Gzip Decompress (gzip, zlib or raw DEFLATE), LZ4 Decompress (LZ4 frames, legacy frames or a raw block), Gzip Compress and LZ4 Compress (a standard LZ4 frame) and LZ4 Compress (Size-Prefixed Block), the format of Python's lz4.block and many online tools; LZ4 Decompress reads it too. Compressed data is pasted as base64 or hex; output that isn't text is shown as hex. Backed by zlib and a small Swift LZ4 decoder in a new `@boop/compression` module.

### Multi Cursor Editing

Several cursors that type, delete, move, copy and paste together. Add them with ⌘-click, ⌥-drag (columns), ⌥⌘↑/↓, ⌘D (next match), ⌃⌘G (all matches) or ⇧⌘L (split into lines); Esc goes back to one. Undo puts the cursors back.

### Font Settings

Font and Size (9–36 pt) in Settings > Appearance, monospaced fonts only. View > Bigger (⌘+), Smaller (⌘−) and Actual Size (⌘0) change the size from the keyboard.

### Fewer bundled script libraries

No Swift packages or frameworks remain (SavannaKit and Fuse are gone). jshashes, base64.js, he, lodash and vkBeautify were replaced by small `@boop/` modules backed by CryptoKit and Foundation. js-yaml (now 5.5.0) and Papa Parse (now 5.7.1) stay, since the parsers are hard to get right.

### Color Settings

Themes: Boop and Catppuccin (Latte, Frappé, Macchiato, Mocha), plus window transparency in Frosted, Glass or Clear Glass styles.

### Tabs

Native window tabs and a persistent multi-tab Boops workspace.

## Not Planned

### Load / Save

There is no plan to support files within Boop.
