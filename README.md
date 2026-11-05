# Last Sale

A relaxing low-poly pull-tab ticket game for Steam, being rebuilt in Godot 4 from a finished web prototype.

Start with `MIGRATION.md`. It holds the rules, tear physics, milestones and acceptance checklist.

- `reference/last-sale-preview.html`: runnable web build, works offline in Chrome or Edge
- `reference/last-sale-source.html`: readable source of that build, without the embedded audio
- `assets/audio/`: recorded sound effects and tear timing marks
- `assets/fonts/`: fonts under the SIL Open Font License

## Development

- Engine: Godot 4.7.2 (stable), Compatibility renderer.
- Open `project.godot` in Godot. Main scene for now: `src/table/test_table.tscn` (the core forms in turn on a grey table).
  `src/dev/m1_check.tscn` shows fonts, sounds and generated boxes.
- Tests (headless, no addons):

  ```
  godot --headless --path . res://tests/run_tests.tscn               # quick, ~25 s
  godot --headless --path . res://tests/run_tests.tscn -- --full     # acceptance: 5,000 boxes per form
  ```

- `tools/drive_table.tscn` plays one ticket of each form with synthetic input and saves screenshots:
  `godot --path . --resolution 1920x1080 res://tools/drive_table.tscn -- <output dir>`
- `tools/make_generator_golden.js` (Node) regenerates `tests/fixtures/generator_golden.json` from the
  web build's own generator; the Godot generator must match it bit for bit.

### Layout

- `src/core/`: plain logic with no scene access (random numbers, box generator, data classes)
- `src/data/`: data pack loading and validation
- `src/platform/`: thin platform layer (`Platform` autoload); offline backend only for now
- `docs/decisions.md`: where the code deliberately differs from MIGRATION.md or the web build
- `packs/core/`: built-in ticket forms, in the same format Workshop packs will use (see `packs/README.md`)
- `assets/`: engine-side fonts and machine sounds
