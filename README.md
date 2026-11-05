# Last Sale

A relaxing low-poly pull-tab ticket game for Steam, being rebuilt in Godot 4 from a finished web prototype.

Start with `MIGRATION.md`. It holds the rules, tear physics, milestones and acceptance checklist.

- `reference/last-sale-preview.html`: runnable web build, works offline in Chrome or Edge
- `reference/last-sale-source.html`: readable source of that build, without the embedded audio
- `assets/audio/`: recorded sound effects and tear timing marks
- `assets/fonts/`: fonts under the SIL Open Font License

## Development

- Engine: Godot 4.7.2 (stable), Compatibility renderer.
- Open `project.godot` in Godot. Main scene: `src/game/game.tscn` (the Diner, Bar or Bingo Hall with table, machine and money).
  Esc or the MENU key opens the player menu. In debug builds the backquote key opens the developer panel
  (rooms, a free ticket of any form, box seeds and counts, reset of tickets and money, lamp step, sound bench).
  Dev scenes: `src/table/test_table.tscn` (the core forms in turn, no economy), `src/dev/m1_check.tscn` (fonts, sounds, boxes).
- Save: one versioned JSON file, `user://save.json` (Windows: `%APPDATA%\Godot\app_userdata\Last Sale\save.json`),
  with the settings and the session in progress. Delete it to start over.
- Tests (headless, no addons):

  ```
  godot --headless --path . res://tests/run_tests.tscn               # quick, ~25 s
  godot --headless --path . res://tests/run_tests.tscn -- --full     # acceptance: 5,000 boxes per form
  ```

- Export (needs the Godot 4.7.2 export templates; Windows x86_64 is enough):

  ```
  godot --headless --path . --export-release "Windows Desktop" builds/windows/LastSale.exe
  godot --headless --path . --export-debug "Windows Verify" builds/verify/LastSaleVerify.exe
  ```

  Ship the whole `builds/windows` folder: the export plugin (`addons/last_sale_export`) puts the
  built-in packs and the licence texts next to the executable. The verify build also carries the
  tools; in it, `-- <args> --run-tool=res://tools/drive_game.tscn` (or `bench_fps.tscn`) runs a tool.
  For a demo to send around, the "Windows Demo" preset (custom feature `single_exe`) makes one
  self-contained executable: the export plugin puts `packs/core` and the licence texts inside the .pck.

  ```
  godot --headless --path . --export-release "Windows Demo" builds/demo/LastSale.exe
  ```
  `docs/acceptance.md` holds the checklist results and how to measure frame times elsewhere.
- `tools/make_icon.gd` renders the game icon (`assets/icon/icon.png`, the window and .exe icon) from the
  Big Catch front: `godot --path . -s res://tools/make_icon.gd`, then export again.
- `tools/drive_table.tscn` plays one ticket of each form with synthetic input and saves screenshots:
  `godot --path . --resolution 1920x1080 res://tools/drive_table.tscn -- <output dir>`
- `tools/drive_game.tscn` plays the full loop (bills, PLAY ALL, camera swing, leaving rules, cash out, loan,
  menu, language, developer panel, save and reload) and checks the money identity every frame; its save file
  goes under the output dir. `tools/preview_pile.tscn` renders the discard pile at several sizes.
- `tools/preview_rooms.tscn` screenshots every room from the table and the machine
  (`--gains=h,k,p` overrides the light gains, used to fit them against the web build).
- `tools/export_room_art.js` (Node) re-exports the room textures in `assets/rooms/` from the web build's
  own canvas code: run it, open http://localhost:8765/ in a browser.
- `tools/subset_cjk_fonts.py` cuts the bundled Chinese fonts down to the characters in `locale/ui.csv`;
  run it after adding Chinese text (a test fails until you do). `tools/measure_cjk.gd` prints where the
  Chinese sits against each Latin font's capitals (`godot --path . -s res://tools/measure_cjk.gd`);
  `tools/preview_cjk.tscn` renders the machine view and the menu in English and Chinese.
- `tools/make_generator_golden.js` (Node) regenerates `tests/fixtures/generator_golden.json` from the
  web build's own generator; the Godot generator must match it bit for bit.

### Layout

- `src/core/`: plain logic with no scene access (random numbers, box generator, economy, machine, tray, navigation rules)
- `src/data/`: data pack loading and validation
- `src/rooms/`: the three rooms, built from code with a port of the web build's low-poly kit (`room_kit.gd`)
- `src/platform/`: thin platform layer (`Platform` autoload); offline backend only for now
- `src/save/`: the save file (`SaveFile`, `Save` autoload); `src/core/session_state.gd` says what a session keeps
- `src/ui/`: HUD, menu, LCD look, language (`Lang` autoload); `src/dev/`: developer panel and dev scenes
- `locale/ui.csv`: player text, English and Chinese (keys are the English text)
- `docs/decisions.md`: where the code deliberately differs from MIGRATION.md or the web build
- `packs/core/`: built-in ticket forms, in the same format Workshop packs will use (see `packs/README.md`)
- `assets/`: engine-side fonts, machine sounds and room textures
