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
  Two modes (menu, MODE): free play, and the story's run (a debt in three layers; `docs/roadmap.md`).
  Esc or the MENU key opens the player menu. In debug builds the backquote key opens the developer panel
  (rooms, a free ticket of any form, box seeds and counts, reset of tickets and money, lamp step, sound bench).
  Dev scenes: `src/table/test_table.tscn` (the core forms in turn, no economy), `src/dev/m1_check.tscn` (fonts, sounds, boxes).
- Save: one versioned JSON file, `user://save.json` (Windows: `%APPDATA%\Godot\app_userdata\Last Sale\save.json`),
  with the settings, the free-play session and the run in progress. Delete it to start over.
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
- `tools/preview_machine.tscn` renders the machine with 8, 6 and 4 columns (`--columns=8,6`, `--room=bar`;
  up to four columns stand in one cabinet, more in two; a room that names its forms caps the count):
  `godot --path . --resolution 1920x1080 res://tools/preview_machine.tscn -- <output dir>`
- `tools/preview_tickets.tscn` holds a ticket of each form at the table and saves three pictures of it
  (dealt, turned over, open; `--forms=plate,kabawk` for some of them):
  `godot --path . --resolution 1920x1080 res://tools/preview_tickets.tscn -- <output dir>`
- `tools/import_symbol_art.py` puts the tier symbols into `packs/core/art/` from their source
  pictures in `docs/art_redo/` (painted outside the code; needs Python with Pillow): replace a
  source picture, run it again. `tools/make_ticket_art.py` draws what is still drawn in code (the
  Nugget Rush nuggets and One Flock's flag; needs the Godot path in `GODOT`);
  `tools/make_new_forms.py` writes the five M8.6 forms and their layouts; `tools/make_core_layouts.py`
  the built-in layouts and Hot Plate's square one. A card's shape is layout data: Hot Plate is square,
  One Flock 21:9, Ka-Bawk! 21:9 on end. `tools/render_ticket_art.gd` renders every form's front and insides.
  `tools/art_proposals.py` drew earlier style proposals in `docs/m8.6/` (not used by the game).
- `tools/make_icon.gd` renders the game icon (`assets/icon/icon.png`, the window and .exe icon) from the
  Big Catch front: `godot --path . -s res://tools/make_icon.gd`, then export again.
- `tools/drive_table.tscn` plays one ticket of each form with synthetic input and saves screenshots:
  `godot --path . --resolution 1920x1080 res://tools/drive_table.tscn -- <output dir>`
- `tools/drive_run.tscn` plays the story mode the same way (cards, a day at the machine, NEW BOX, LOAN,
  last sale, LEAVE, work, paying into the next layer, reload, deadline, a run cleared by work alone).
- `tools/sim_runs.tscn` plays bots through whole runs and prints clear rates, for the numbers in
  `src/core/run_config.gd`: `godot --headless --path . res://tools/sim_runs.tscn -- --runs=200`
- `tools/drive_game.tscn` plays the full loop (bills, PLAY ALL, camera swing, leaving rules, cash out, loan,
  menu, language, developer panel, save and reload) and checks the money identity every frame; its save file
  goes under the output dir. `tools/preview_pile.tscn` renders the discard pile at several sizes;
  `tools/preview_win_pile.tscn` renders every room's table with the discard pile and the winners' pile,
  for placing the winners' pile (`--at=x,z` tries another spot).
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

- `src/core/`: plain logic with no scene access (random numbers, box generator, economy, machine, tray, navigation rules,
  the run: `run_state.gd`, `run_config.gd`, `run_sim.gd`)
- `src/data/`: data pack loading and validation
- `src/rooms/`: the three rooms, built from code with a port of the web build's low-poly kit (`room_kit.gd`)
- `src/platform/`: thin platform layer (`Platform` autoload); offline backend only for now
- `src/save/`: the save file (`SaveFile`, `Save` autoload); `src/core/session_state.gd` says what a session keeps
- `src/ui/`: HUD, menu, the run's card, LCD look, language (`Lang` autoload); `src/dev/`: developer panel and dev scenes
- `docs/roadmap.md`: what comes after the demo (G's decisions, in Chinese)
- `locale/ui.csv`: player text, English and Chinese (keys are the English text)
- `docs/decisions.md`: where the code deliberately differs from MIGRATION.md or the web build
- `packs/core/`: the eight built-in ticket forms, in the same format Workshop packs will use (see `packs/README.md`)
- `src/machine/`: the machine (one or two cabinets of columns and a console). `Game.FORM_UIDS` lists every
  form sold; a room may name fewer for its machine (`RoomSet.ROOMS[id].forms`)
- `assets/`: engine-side fonts, machine sounds and room textures
