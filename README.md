# koreader-frontespico

[KOReader](https://github.com/koreader/koreader) [user patch](https://github.com/koreader/koreader/wiki/User-patches) that replaces the "Opening file '/long/path/…'" popup with the book's **cover** (when cached) or a centred **author + title** splash (fallback).

![Splash showing author above the book title in a centred rounded frame instead of the filepath and filename](screenshot.png)

## How it works

The patch hooks `ReaderUI.showReaderCoroutine` before doShowReader runs, draws a splash, then lets the book open underneath. Two render modes:

1. **Cover mode** — pulls the cached thumbnail from `coverbrowser.koplugin`'s `BookInfoManager` (zstd-compressed BlitBuffer in `~/.config/koreader/settings/bookinfo_cache.sqlite3`) and paints it at 1:1, centred. No EPUB decode, no scaling. The cache is built by coverbrowser the first time the book appears in the FileManager mosaic/list view.
2. **Text mode** — fallback when the cover cache misses (book not yet seen in FileManager, or coverbrowser disabled). Author + title from the `.sdr` sidecar; cleaned filename when the sidecar is also missing.

## Install

Copy `2-frontespico.lua` into KOReader's `patches/` directory, restart.

| Platform | Path |
|---|---|
| Linux (native) | `~/.config/koreader/patches/` |
| Kobo / Kindle / PocketBook | `koreader/patches/` |
| Android | `koreader/patches/` in KOReader's storage folder |

Cover mode also needs the bundled `coverbrowser.koplugin` enabled (it ships with KOReader; turn it on in *Tools → Mosaic / detailed list view* if not already). Browse your library once so the cover cache populates.

## Notes

- A **userpatch**, not a plugin: plugins load inside `ReaderUI:init` — too late to intercept the startup auto-open of the last book. Priority-`2-` patches fire after UIManager is ready but before that open.
- The cover is shown at **native cache size** (~300×450 px). No upscale (avoids blurry pixels on e-paper), no downscale (avoids losing detail). If you want larger covers, bump `coverbrowser`'s max cover size in its settings before re-scanning your library.
- Honours `settings/kotheme.lua` `enabled` flag as a kill-switch if present; otherwise always on.
- Any error falls back to the stock popup. A failure to load the cover silently falls back to text — no crash on launch.
- On slow e-paper hardware (Raspberry Pi) the splash adds **0 measurable startup time** in A/B tests against the stock popup.

## License

[AGPL-3.0](LICENSE). Matches KOReader.
