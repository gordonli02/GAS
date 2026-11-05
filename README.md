# Last Sale

A relaxing low-poly pull-tab ticket game for Steam, being rebuilt in Godot 4 from a finished web prototype.

Start with `MIGRATION.md`. It holds the rules, tear physics, milestones and acceptance checklist.

- `reference/last-sale-preview.html`: runnable web build, works offline in Chrome or Edge
- `reference/last-sale-source.html`: readable source of that build, without the embedded audio
- `assets/audio/`: recorded sound effects and tear timing marks
- `assets/fonts/`: fonts under the SIL Open Font License

## Development

- Engine: Godot 4.7.2 (stable), Compatibility renderer.
- Open `project.godot` in Godot. Main scene: `src/game/game.tscn` (the Diner, Bar or Bingo Hall with table, machine and money;
  in debug builds F1/F2/F3 switch rooms and [ / ] step the red buttons' brightness until the developer panel arrives in milestone 6).
  Dev scenes: `src/table/test_table.tscn` (the core forms in turn, no economy), `src/dev/m1_check.tscn` (fonts, sounds, boxes).
- Tests (headless, no addons):

  ```
  godot --headless --path . res://tests/run_tests.tscn               # quick, ~25 s
  godot --headless --path . res://tests/run_tests.tscn -- --full     # acceptance: 5,000 boxes per form
  ```

- `tools/drive_table.tscn` plays one ticket of each form with synthetic input and saves screenshots:
  `godot --path . --resolution 1920x1080 res://tools/drive_table.tscn -- <output dir>`
- `tools/drive_game.tscn` plays the full loop (bills, PLAY ALL, camera swing, leaving rules, cash out, loan)
  and checks the money identity every frame; `tools/preview_pile.tscn` renders the discard pile at several sizes.
- `tools/preview_rooms.tscn` screenshots every room from the table and the machine
  (`--gains=h,k,p` overrides the light gains, used to fit them against the web build).
- `tools/export_room_art.js` (Node) re-exports the room textures in `assets/rooms/` from the web build's
  own canvas code: run it, open http://localhost:8765/ in a browser.
- `tools/make_generator_golden.js` (Node) regenerates `tests/fixtures/generator_golden.json` from the
  web build's own generator; the Godot generator must match it bit for bit.

### Layout

- `src/core/`: plain logic with no scene access (random numbers, box generator, economy, machine, tray, navigation rules)
- `src/data/`: data pack loading and validation
- `src/rooms/`: the three rooms, built from code with a port of the web build's low-poly kit (`room_kit.gd`)
- `src/platform/`: thin platform layer (`Platform` autoload); offline backend only for now
- `docs/decisions.md`: where the code deliberately differs from MIGRATION.md or the web build
- `packs/core/`: built-in ticket forms, in the same format Workshop packs will use (see `packs/README.md`)
- `assets/`: engine-side fonts, machine sounds and room textures
