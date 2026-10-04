# Changelog

## 1.2.0 – Preview and layout improvements

- Health-loss colors in the indicator preview now use the same background layer as the live frames, so the preview reflects the color you selected.
- The GitHub control in About now opens a small window with the link selected. Use Copy (or Ctrl+C) to copy it, then OK to close the window.
- Closing Options now turns off the Party or Raid Group Filter preview and restores the live frames.
- Tidied the Layouts tab: clearer labels, a simpler layout selector, and dropdown titles placed beside their controls. Spacing labels are centered above their sliders.
- Renamed the preview control to “Test Debuffs.”
- Bumped the addon version to 1.2.0.

## 1.1.0 – Public release improvements

- Refined the README with supported server links, required and recommended addon links, installation instructions, supported commands, and a complete feature overview.
- Updated the in-game About page with the current description, credits, version, and a clickable GitHub link.
- Set Expressway as the default font across addon text, and set NotCell Texture, Flash animation, Power Color text, full downward gradient coverage, and automatic layout switching as defaults.
- Create the default Left Click target and Right Click menu binds for each character on first use.
- Improved the setup wizard guide preview so name, health, and power text colors and positions follow the selected layout; layout-filter previews use the current character name and class color.
- Fixed debuff preview testing so icons and display styles remain testable across selection, icon visibility, and overlapping preview states.
- Fixed options construction: the About page no longer assigns an unsupported hyperlink script to a plain frame, and an individual options page error no longer prevents other pages from being built.
- Preserved the addon’s existing unit-frame, click-casting, heal prediction, layout, setup, and import/export features.

## 1.0.0 – Initial public release

NotCell is a configurable party and raid unit-frame addon for World of Warcraft 1.12.1 / 1.18.1 clients.

- Solo, party, and raid frames with configurable layouts, sizing, indicators, and automatic layout switching.
- Click-casting for NotCell and Blizzard frames, with keyboard and mouse binds and character-specific profiles.
- Incoming-heal prediction through bundled HealComm 1.0.
- Buff, debuff, missing-buff, and healer indicators, with configurable placement and debuff display styles: Border Glow, Solid Tint, and Gradient.
- Appearance options for health and power bars, vertical or horizontal orientation, power-bar placement, fonts, textures, range fading, and frame width.
- Expressway as the default font, plus additional fonts and status-bar textures from pfUI-CustomMedia with visual previews in the options.
- Initial setup wizard with Light and Dark profiles, layout and bar choices, click-casting defaults, heal-prediction controls, indicator defaults, and a live guide preview.
- Live options previews with a selected-indicator filter and debuff testing, plus a draggable red frame handle and Party or Raid Group Filter previews that can be adjusted without joining a group.
- Dynamic options window sizing, out-of-range frame fading, and frame-width limits.
- Settings export and import for NotCell.
- Backported from Cell 3.3.5a and heavily inspired by the original Cell addon.

For the supported 1.18.1 client environment, NotCell uses ClassicAPI, SuperWoW, and UnitXP3.
