# NotCell

NotCell is a party and raid unit-frame addon for the Vanilla API, backported from Cell and adapted for the WoW 1.12.1 / OctoWoW 1.18.1 client.

## Supported client

- World of Warcraft interface version **11200** (1.12.1)
- Tested target: **OctoWoW 1.18.1**

## Features

- Solo, party, and raid unit frames with per-layout sizing, growth, health fill, and power bar placement.
- Automatic layout switching when moving between solo, party, and raid groups.
- Click-casting on NotCell and supported Blizzard unit frames, including mouse and keyboard binds.
- Character-specific click-casting profiles and bindings.
- Incoming-heal prediction through bundled HealComm-1.0 and `UnitGetIncomingHeals` when supported.
- Text, status, role, leader, ready-check, raid mark, buff, debuff, missing buff, and healer indicators.
- Debuff display styles including border glow, solid tint, and gradient.
- Appearance controls for class/custom colors, opacity, statusbar textures, fonts, and out-of-range alpha.
- Live Options previews, selected-indicator isolation, draggable group previews, and a red frame-position handle.
- First-run setup wizard with Light/Dark modes, layout growth and bar direction controls, and a live guide preview.
- Layout import/export and visual previews in texture and font dropdowns.

## Dependencies

### Required

- OctoWoW 1.18.1 / WoW 1.12.1 with the **ClassicAPI client extension** installed and enabled.

### Optional integrations

- **SuperWoW / SuperWoWhook:** Enables HealComm's cast-event path where available. HealComm-1.0 is bundled; without SuperWoW it uses its supported fallback events and hooks.
- **LibSharedMedia-3.0:** If another addon provides it, NotCell can use its registered fonts and statusbar textures. NotCell also includes built-in options and does not require LibSharedMedia.

HealComm messages from other players require compatible HealComm support on their clients. NotCell also reads `UnitGetIncomingHeals` when the client API provides it.

## Installation

1. Copy the `NotCell` folder into `Interface\AddOns\` so the file `Interface\AddOns\NotCell\NotCell.toc` exists.
2. Keep the ClassicAPI client extension enabled.
3. Start the game and enable **NotCell** in the AddOns list if needed.
4. On first use, follow the setup window or skip it and open it later with `/notcell setup`.

### Upgrade from Cell

NotCell uses new SavedVariables names and a new addon folder, so the game does not automatically associate the old Cell settings file with NotCell. To carry settings over, close the game and back up the SavedVariables files first. Copy the account-level `Cell.lua` to `NotCell.lua` in `WTF\Account\<account>\SavedVariables\`; also copy each character's `Cell.lua` to `NotCell.lua` in that character's `WTF\Account\<account>\<realm>\<character>\SavedVariables\` folder. On its first load, NotCell migrates the old `CellDB`, `CellVanillaDB`, and `CellCharacterDB` tables to the new `NotCell*DB` tables. Keep the original files until you confirm the migration succeeded. Do not run both addons together during this migration.

## Slash commands

- `/notcell` — show the command list.
- `/notcell opt` or `/notcell options` — open Options.
- `/notcell setup` — open the setup wizard.
- `/notcell minimap show` — show the minimap button.
- `/notcell blizz hide` / `/notcell blizz show` — hide or restore supported Blizzard group frames. Player, Target, and Target of Target are not hidden.
- `/notcell healthcolor class` — use class-colored health bars.
- `/notcell healthcolor custom RRGGBB` — set a custom health bar color.
- `/notcell show` / `/notcell hide` — show or hide NotCell frames.
- `/notcell preview` — toggle a sample party preview.
- `/notcell preview party`, `status`, `raid10`, `raid20`, `raid25`, or `raid` — show sample units for that preview.

## First-run setup

The setup wizard runs once for a fresh NotCell installation and can be reopened at any time. It offers Light or Dark starting mode, frame growth direction, health fill direction, power bar direction and side, Heal Prediction, and Blizzard group-frame hiding. It also offers Healer Indicators and shows a single live guide frame that updates as choices change. The wizard can be skipped; skipped setup is not shown again automatically.

## Configuration

- **General:** setup, Blizzard frame visibility, minimap, tooltips, and general behavior.
- **Appearance:** colors, backgrounds, opacity, health and power bars, textures, fonts, and range fade.
- **Layouts:** layout profiles, group filters, sizing, spacing, growth, orientation, previews, and import/export.
- **Click-Castings:** per-character profiles and binds for NotCell and supported Blizzard unit frames.
- **Indicators:** text and icon indicators, aura filters, missing buffs, healers, and debuff display styles.
- **About:** version, credits, and quick tips.

Appearance, layout, indicator, and general settings are account-wide. Click-Casting profiles, bindings, profile names, and the active profile are per character.

## Credits

- The original **Cell** addon and its contributors, including enderneko.
- Vanilla backport and OctoWoW adaptation: **amusjn**.
- Bundled **HealComm-1.0** and its Ace2 support libraries; **LibStub** and **CallbackHandler**.
- **ClassicAPI** client extension and **SuperWoW** are maintained separately.

## License

License: **to be confirmed**. Please check the original Cell project and bundled library licenses before redistribution or modification.

## Screenshots

Screenshots will be added here.
