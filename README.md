# koreader-frontespico

[KOReader](https://github.com/koreader/koreader) [user patch](https://github.com/koreader/koreader/wiki/User-patches) that replaces the "Opening file '/long/path/…'" popup with a centred author + title splash from the book's `.sdr` sidecar.

![Splash showing author above the book title in a centred rounded frame instead of the filepath and filename](screenshot.png)

## Install

Copy `2-frontespico.lua` into KOReader's `patches/` directory, restart.

| Platform | Path |
|---|---|
| Linux (native) | `~/.config/koreader/patches/` |
| Kobo / Kindle / PocketBook | `koreader/patches/` |
| Android | `koreader/patches/` in KOReader's storage folder |

## Notes

- A **userpatch**, not a plugin: plugins load too late to intercept the startup auto-open of the last book; priority-`2-` patches fire after UIManager is ready but before that open.
- First open of a file uses a cleaned-up filename (extension stripped, underscores → spaces); from the second open on, author + title come from the `.sdr` sidecar.
- Honours `settings/kotheme.lua` `enabled` flag as a kill-switch if present; otherwise always on.
- Any error falls back to the stock popup.

## License

[AGPL-3.0](LICENSE). Matches KOReader.
