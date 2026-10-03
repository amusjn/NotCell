<div align="center">

[![RavenCraft](https://img.shields.io/badge/RavenCraft-1.18.1-1f1f1f?style=for-the-badge&labelColor=555555)](https://ravencraft.io) [![CapyCraft](https://img.shields.io/badge/CapyCraft-1.18.1-8b5a2b?style=for-the-badge&labelColor=555555)](https://capycraft.io) [![OctoWoW](https://img.shields.io/badge/OctoWoW-1.18.1-9027df?style=for-the-badge&labelColor=555555)](https://octowow.st)

[![ClassicAPI](https://img.shields.io/badge/ClassicAPI-Required-cb1c43?style=for-the-badge&labelColor=555555)](https://github.com/brues-code/ClassicAPI) [![SuperWoW](https://img.shields.io/badge/SuperWoW-Required-cb1c43?style=for-the-badge&labelColor=555555)](https://github.com/balakethelock/SuperWoW) [![SuperCleveRoidMacros](https://img.shields.io/badge/SuperCleveRoidMacros-Recommended-f28c00?style=for-the-badge&labelColor=555555)](https://github.com/brues-code/SuperCleveRoidMacros)

# NotCell

A party and raid unit-frame for World of Warcraft 1.12 — **ClassicAPI is required.**

Originally backported from [Cell 3.3.5 backport](https://github.com/Keoo88/Cell-3.3.5-backport). Credits to the original [Cell](https://github.com/enderneko/Cell) author and contributors. NotCell was heavily inspired by Cell.

</div>

## Features

- Solo, party, and raid unit frames with separate layouts, sizing, settings, and indicators.
- Automatically switches layouts as you move between solo, party, and raid groups.
- Click-casting for NotCell and Blizzard unit frames, configured in NotCell options, with keyboard and mouse binds.
  - Keep click-casting profiles specific to each character.
- Incoming-heal prediction powered by bundled HealComm.
- Choose how debuffs appear on your frames.
- Additional fonts and status bar textures from [pfUI-CustomMedia](https://github.com/mr-rosh/pfUI-CustomMedia).
- Adjust frame size, health and power bar orientation, and bar placement.
- See settings changes immediately in the live preview frame.
- Use the Group Filter to preview party and raid layouts without joining a group.
- Export and import NotCell settings.

## Installation

1. Download and copy the NotCell folder into `Interface\AddOns\` so the file `Interface\AddOns\NotCell\NotCell.toc` exists.
2. Start the game and, in character selection, ensure the NotCell addon is enabled.
3. Set your Script Memory (MB) to 0.
4. On first use, follow the setup window or skip it and open it later with `/notcell setup` or through the options window.

## Slash commands

- `/notcell` — show the command list.
- `/notcell opt` — open options.
- `/notcell options` — open options.
- `/notcell setup` — open setup.
- `/notcell show` / `/notcell hide` — show or hide NotCell frames.
- `/notcell blizz show` / `/notcell blizz hide` — show or hide supported Blizzard group frames.

## Configuration

Open the options with `/notcell opt` or `/notcell options`. Configure appearance, layouts, click-casting, and indicators. Click-casting profiles are saved per character; other settings are shared across the account.

## Credits

- [Cell](https://github.com/enderneko/Cell) and its original author and contributors.
- The [Cell 3.3.5 backport](https://github.com/Keoo88/Cell-3.3.5-backport).
- [pfUI-CustomMedia](https://github.com/mr-rosh/pfUI-CustomMedia) for additional fonts and status bar textures.
- [ClassicAPI](https://github.com/brues-code/ClassicAPI), [SuperWoW](https://github.com/balakethelock/SuperWoW), and the bundled HealComm library.

## License

NotCell is distributed under the MIT License. See [LICENSE](LICENSE).
