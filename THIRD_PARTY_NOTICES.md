# Third-party notices

`src/fonts/IBMPlexSans-*.ttf` contains IBM Plex Sans Regular, Italic, SemiBold, Bold, and Bold Italic, copyright IBM Corp., distributed under the SIL Open Font License 1.1. The complete Plex license is in [src/fonts/OFL.txt](src/fonts/OFL.txt).

`src/fonts/NordwandMono-*.ttf` contains Nordwand Mono Regular, Bold, and SemiBold by tywr, distributed under the SIL Open Font License 1.1. The bundled SemiBold face is modified with terminal box-drawing, block-element, and Powerline glyphs added by Multiprompt under the same SIL Open Font License 1.1. Its source is the [official 1.3.1 release](https://github.com/tywr/Nordwand-Mono/releases/tag/1.3.1); regenerate it with [tools/fonts/add-terminal-glyphs.py](tools/fonts/add-terminal-glyphs.py) using the original SemiBold TTF and fonttools 4.67.0. The complete license is in [src/fonts/LICENSE-NordwandMono.txt](src/fonts/LICENSE-NordwandMono.txt).

The optional WebView2 prototype requires Microsoft's WebView2 SDK and runtime, which are not distributed here. Obtain them from Microsoft and follow their license terms.

JavaScript dependencies are installed separately with npm; their packages include their respective licenses. Zig is a separately installed toolchain.
