# Third-party notices

`src/fonts/IBMPlexSans-*.ttf` contains IBM Plex Sans Regular, Italic, SemiBold, Bold, and Bold Italic, copyright IBM Corp., distributed under the SIL Open Font License 1.1. The complete Plex license is in [src/fonts/OFL.txt](src/fonts/OFL.txt).

`src/fonts/NordwandMono-*.ttf` contains Nordwand Mono Regular, Bold, and SemiBold by tywr, distributed under the SIL Open Font License 1.1. The bundled SemiBold face is renamed to **Nordwand Mono MP SemiBold** and modified with terminal box-drawing, block-element, and Powerline glyphs added by Multiprompt under the same SIL Open Font License 1.1. Its source is the [official 1.3.1 release](https://github.com/tywr/Nordwand-Mono/releases/tag/1.3.1). Its 24-character legacy family and full name (name IDs 1 and 4) are identical so GDI/conhost can request the distinct face at weight 600 within the 31-character FaceName limit without matching an installed upstream copy. The typographic family (ID 16) is Nordwand Mono MP with SemiBold style (ID 17); the legacy style (ID 2) remains Regular, following the upstream weight-specific GDI family convention. Its PostScript name (ID 6) is NordwandMonoMP-SemiBold. Regenerate it with [tools/fonts/add-terminal-glyphs.py](tools/fonts/add-terminal-glyphs.py) using the original SemiBold TTF and fonttools 4.67.0. The complete license is in [src/fonts/LICENSE-NordwandMono.txt](src/fonts/LICENSE-NordwandMono.txt).

The optional WebView2 prototype requires Microsoft's WebView2 SDK and runtime, which are not distributed here. Obtain them from Microsoft and follow their license terms.

JavaScript dependencies are installed separately with npm; their packages include their respective licenses. Zig is a separately installed toolchain.

`src/fonts/Hack-Regular.ttf` and `src/fonts/Hack-Bold.ttf` are unmodified upstream [Hack v3.003](https://github.com/source-foundry/Hack/tree/v3.003/build/ttf) by Source Foundry. Source Foundry work is MIT licensed, DejaVu work is public domain, and Bitstream Vera work carries its included license. Complete copyright, trademark, and permission notices are in [src/fonts/LICENSE-Hack.md](src/fonts/LICENSE-Hack.md).

SHA-256 (upstream v3.003):

- Hack-Regular.ttf: `15f55cc0c85a2988d2b4b3a8cdb5d77fdfbaf319e1bb5309d725db9818fb7125`
- Hack-Bold.ttf: `5bbf531eff7f8a0c2559c9a0656718e2828a012a9b1f60b5f54006d59a4de8d4`
