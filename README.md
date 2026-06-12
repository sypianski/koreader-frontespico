# koreader-bookopen-splash

A [KOReader](https://github.com/koreader/koreader) [user patch](https://github.com/koreader/koreader/wiki/User-patches) that replaces the file-path popup shown while a book opens —

> Opening file '/long/ugly/path/Author Name - Some_Book_Title.epub'.

— with a centred author + title splash:

![Splash showing author above the book title in a centred rounded frame](screenshot.png)

It covers every way a book opens: tapping it in the file browser, history, "open last document" at startup, etc. The splash dismisses itself exactly when the original popup would — as soon as the book has loaded and painted.

## Install

Copy `2-bookopen-splash.lua` into the `patches/` directory next to your KOReader settings (create it if it doesn't exist):

| Platform | Path |
|---|---|
| Linux (native) | `~/.config/koreader/patches/` |
| Kobo / Kindle / PocketBook | `koreader/patches/` on the device |
| Android | `koreader/patches/` in KOReader's storage folder |

Restart KOReader. The patch logs `Applying patch: …/2-bookopen-splash.lua` on startup.

## How it works

- It wraps `ReaderUI.showReaderCoroutine`, the single funnel through which all book opens pass, and swaps the path `InfoMessage` for a two-line widget (author in a smaller face, title larger and bold), preserving the upstream load-masking flow (`forceRePaint` → `nextTick` → coroutine).
- It is a **priority-2 user patch** rather than a plugin on purpose: plugins load inside `ReaderUI:init`, *after* the popup has already been shown for the book KOReader auto-opens at launch. Priority-2 patches are applied after UIManager is ready but before that startup open.
- Author and title come from the book's `.sdr` sidecar (`doc_props`), available from the second open onward. On the very first open of a file the splash falls back to a cleaned-up filename (extension stripped, underscores → spaces).
- "Seamless" opens (e.g. next/previous document in history navigation) are passed through untouched, as upstream intends.
- Any error inside the patch falls back to the original popup — worst case you see the stock message.

## Optional KoTheme integration

If a settings file `settings/kotheme.lua` with an `enabled` flag exists (written by a KoTheme plugin), the splash honours it as a kill-switch. Without that file the splash is simply always on.

## Compatibility

Tested with KOReader 2026.03 on desktop Linux (Wayland). The patch only relies on `ReaderUI.showReaderCoroutine`, `InfoMessage`, and `DocSettings`, which are stable core APIs; if anything fails it falls back to stock behaviour.

## Related work

- [reuerendo/koreader-patches](https://github.com/reuerendo/koreader-patches) — `2-bookloadcover.lua` shows the book *cover* instead
- [jandamm/KOReader.patches](https://github.com/jandamm/KOReader.patches) — improved fork of the above
- [AndyHazz/koreader-tweaks](https://github.com/AndyHazz/koreader-tweaks) — `2-suppress-opening-dialog.lua` just hides the popup
- [AnthonyGress/zen_ui.koplugin](https://github.com/AnthonyGress/zen_ui.koplugin) — full UI suite with an opening banner pinned to the tapped cover

This patch sits between them: no cover, no suite — just typography.

## License

[AGPL-3.0](LICENSE), same as KOReader (the patch derives from its `showReaderCoroutine`).
