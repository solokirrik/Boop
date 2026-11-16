# DOING.md

This document, inspired by [this tweet](https://twitter.com/drwave/status/1564063331341590529), contains the currently in progress or planned features for Boop.

This document was last updated *<u>November 16th, 2026</u>*.

## In progress

### Fewer bundled script libraries

SavannaKit and Fuse are gone; no Swift packages or frameworks remain. What's left:

- [x] Remove the stale `FRAMEWORK_SEARCH_PATHS` (`$(PROJECT_DIR)/Boop/Frameworks` and `$(PROJECT_DIR)`) from the app targets.

Bundled script libraries live in `Boop/Boop/scripts/lib/`. User scripts can `require('@boop/<name>')` them. Renaming a module or changing its API is fine.

- [x] **jshashes** (`hashes.js`): replaced by a wrapper over CryptoKit (MD5, SHA1, SHA256, SHA512, plus HMAC).
- [x] **base64.js** (`base64.js`): replaced by a wrapper over Foundation.
- [x] **he** 1.2.0 (`he.js`): replaced by plain HTML escape/unescape. Encode escapes `& < > " '` only; decode handles those, numeric references and about 25 common named entities.
- [x] **lodash** custom build (`lodash.boop.js`): replaced by `@boop/strings`. Also fixes Start Case, which called a `lowerCase` the build didn't include.
- [x] **vkBeautify** 0.99 (`vkBeautify.js`): replaced by `@boop/format`. XML goes through Foundation's XMLDocument; CSS and SQL are small tokenizer-based rewrites that leave strings and comments untouched.
- Keep **js-yaml** 3.14.0 (`js-yaml.js`) and **Papa Parse** 5.3.0 (`papaparse.js`): the parsers are hard to get right. Consider updating them (js-yaml is at 4.x, which changed its API).

## Planned

### Font Settings

The ability to change font, and more importantly font-size.

### Multi Cursor Editing

The ability to have more than one active cursor to type and edit content.

## Done

### Color Settings

Themes: Boop and Catppuccin (Latte, Frappé, Macchiato, Mocha), plus window transparency in Frosted, Glass or Clear Glass styles.

### Tabs

Native window tabs and a persistent multi-tab Boops workspace.

## Not Planned

### Load / Save

There is no plan to support files within Boop.
