# DOING.md

This document, inspired by [this tweet](https://twitter.com/drwave/status/1564063331341590529), contains the currently in progress or planned features for Boop.

This document was last updated *<u>November 17th, 2026</u>*.

## In progress

Nothing right now.

## Planned

### Font Settings

The ability to change font, and more importantly font-size.

### Multi Cursor Editing

The ability to have more than one active cursor to type and edit content.

## Done

### Fewer bundled script libraries

No Swift packages or frameworks remain (SavannaKit and Fuse are gone). jshashes, base64.js, he, lodash and vkBeautify were replaced by small `@boop/` modules backed by CryptoKit and Foundation. js-yaml (now 5.5.0) and Papa Parse (now 5.7.1) stay, since the parsers are hard to get right.

### Color Settings

Themes: Boop and Catppuccin (Latte, Frappé, Macchiato, Mocha), plus window transparency in Frosted, Glass or Clear Glass styles.

### Tabs

Native window tabs and a persistent multi-tab Boops workspace.

## Not Planned

### Load / Save

There is no plan to support files within Boop.
