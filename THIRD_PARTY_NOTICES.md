# Third-party notices

## Included

| Component | Source | Licence | Where it lives in fuego-os |
|---|---|---|---|
| CleanYourTV | [github.com/Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv), commit `30626a8` | MIT, Copyright (c) 2026 Gathin | The blur trick (artwork shrunk to a 48x27 bitmap and stretched, from `HeroArt.java`) in `launcher/app/src/main/kotlin/io/github/danajerban/fuegoos/GlassBand.kt`; the cached glass highlight (from `GlassView.java`) in `launcher/app/src/main/kotlin/io/github/danajerban/fuegoos/GlassHighlight.kt`. Both ported to Kotlin and changed. |

The Launcher's bundled artwork (`launcher/app/src/main/res/drawable-nodpi/artwork_*.webp`) is ours: `launcher/tools/make-bundled-artwork.py` draws it, under fuego-os's own licence.

### CleanYourTV licence

```
MIT License

Copyright (c) 2026 Gathin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

CleanYourTV's licence file also has a note for the Outfit font, which fuego-os does not use.

## Planned

| Component | Source | Licence | What we plan to use |
|---|---|---|---|
| CleanYourTV | as above | as above | the HOME manifest setup and the disable/restore notes |

## Not included

fuego-os works with Netflix, YouTube, Stremio and Spotify but contains none of their code. [Home+](https://github.com/pbalazaar/home-plus) and [CleanFrame](https://github.com/nthnclrk/CleanFrame) are inspiration only; none of their code is used.
