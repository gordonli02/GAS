# Decisions

Where this codebase deliberately differs from `MIGRATION.md` or the web build, and why.
Newest last. "G" is the project owner.

## Before milestone 1
- **No CLEAR button.** The web HUD had a CLEAR button that zeroed the session ledger. G dropped it,
  so `cash + credit = 200 + loans + won − spent` always holds (a bill being fed counts as cash).
- **B and the TABLE/MACHINE button follow the web build**: with an opened ticket they do nothing;
  only clicking the machine discards the ticket and goes to the machine.
- **Generator is bit-exact with the web build** (stronger than the brief asked): same seed, same box,
  checked against golden data from the web code.
- **Layouts are pack data.** G asked that packs can define the whole ticket look, not just colours,
  so the three ticket kinds are layout files (`packs/core/layouts/`) in the format in
  `packs/README.md`. Packs may ship fonts; all four hinge edges are supported; card sides 0.8–2.6;
  at most one band, across the middle; paper feel is not pack-tunable.
- **Synthesized sounds are baked to WAV.** The web build synthesized deal, flip, toss, pop and win
  sounds at runtime; they were rendered once from the web code (`tools/export_web_art.js`).
- **Tier symbols are images.** The web build drew them with canvas code; they were exported from that
  code as PNGs, a small and a large variant (stroke weight differs with size, as on the web).
- **Player text will be localized** (English and Chinese at release). Printed ticket copy stays as
  pack data.

## Milestone 3 review
- **Lucky Spur band breaks two ways** (`band.breaks`): drag sideways past 0.34 and it slides off
  (web behaviour), or drag up or down past 0.34 and it tears in the middle, the halves falling left
  and right. Which one is read from the first 0.03 of hand travel. Space picks one at random.
- **Lucky Spur flap also opens with a sideways swipe** (`side_pull`): swiping along the bottom tears
  from the bottom corner the hand moves away from (swipe right: bottom-left), opening half the swipe
  distance, the same rate as an upward pull. Upward pulls work as before.

## Milestone 4
- **Discard pile grows by ranges** (G's design, replaces "capped at 36 meshes"): one card per
  ticket for the first 12, then a fixed heap per range of tickets opened plus up to 5 of the latest
  on top (`src/table/pile_model.gd`). Cards come from one seeded drop sequence, settle onto the slope
  under them and slide off spots steeper than ~18°, choosing the lowest of three spots, so the pile
  rises into a mound. At most 185 cards are drawn, in one batch per form.
- **A tossed ticket lands on its pile spot facing the way it will lie.** The web build snapped to a
  random turn on landing.
- **The cash readout and ledger (top left) arrived with the economy in milestone 4**, in the green
  LCD style; the menu and developer panel stay in milestone 6. The web build's narrow-screen
  TABLE/MACHINE button is not ported (desktop only); B does the same.

## Milestone 4 review
- **Motor loop at 1.5x speed but its own pitch.** MIGRATION.md (and the web build) played
  `dispense_loop.wav` at pitch scale 1.5, which also raised it. G wanted the speed without the pitch:
  `dispense_loop_fast.wav` is the loop time-compressed with WSOLA (`tools/time_stretch_loop.py`):
  rhythm 92 -> 62 ms, low peak 284 -> 275 Hz (pitch-scaled playback: 426 Hz). Played at pitch 1.0.
- **LOAN is always available, within a limit.** The web build offered it only when the player was
  stuck. The limit is a placeholder (`Economy.LOAN_LIMIT`, $1000 total) until the credit-line design
  is worked out with the later game modes.
- **Lit arcade buttons on the machine.** The three column buttons are square lit push buttons in a
  black bezel and PLAY ALL a lit red dome in a ring bezel, after G's reference photos. The lamp look
  is painted into unshaded textures: the Compatibility renderer ignores emission textures, and its
  glow brightens the whole frame, so neither is used. PLAY ALL's outer metal ring is as tall as the
  machine LCD beside it. Lamp brightness comes in four presets (`MachineView.lamp_preset`, 0 brightest
  ... 3 most muted; `tools/preview_lamps.tscn` renders them); G picked 1 (the second step).
- **PLAY ALL blinks only in the machine view**; seen from the table it stays lit.
- **While a ticket is open the status line shows just its number** (e.g. "00001", no "TICKET").
- **UI style "A, refined LCD"** (G's pick of three mockups): dark metal plates with screws, recessed
  backlit LCD glass with a pixel grid, lit green bill keys and chrome CASH OUT / LOAN keys, the
  remaining house line under them. The top-left plate shows cash, status and HELD / OPENED / NET.
- **The full ledger is on a notepad on the table** (kept from the "in the world" mockup), written in
  Patrick Hand (SIL OFL, `assets/fonts/`, from Fontsource 5.3.0), also available to packs as `hand`.

## Milestone 5: rooms
- **Rooms are code, not pack data.** The props are built in `src/rooms/` from a port of the web build's
  construction kit; the per-room config (background, fog, lights, machine placement) is a table in
  `room_set.gd` that a test checks against the web source. Rooms could become pack data later; nothing
  in the pack format covers them yet.
- **Geometry is three.js r128's, vertex for vertex** (box, cylinder, lathe, plane, icosahedron, torus,
  same start angles and triangle order), so the low-poly facets fall where they did on the web.
- **Textures are the web build's own canvas drawings**, exported once to `assets/rooms/*.png` by
  `tools/export_room_art.js` (nearest-filtered with mipmaps, like the web build). Signs stay in English.
- **Lighting is converted, then fitted.** Godot has no hemisphere light: ambient carries the sky/ground
  average and two shadowless directional lights (one negative) add and remove half the difference.
  Spot and point lights drop the inverse-square term to keep the web build's linear falloff. Godot
  lights in linear space and the web build did not, so each room has three gains (hemisphere, key,
  points) fitted by least squares to the web build rendered from the same camera.
- **Every room mesh catches clicks**, like the web build's raycast against the whole room, so a prop in
  front of the machine blocks a click on it. Hidden rooms' colliders are switched off.
- **F1/F2/F3 switch rooms in debug builds**, for testing until the developer panel (milestone 6).
  **[ and ] step the red buttons' lamp brightness** (debug builds); the default is the brightest step.
- **Layout departs from the web build where G asked (M5 review):** the diner breakfast sits in front
  of the player, the jukebox and the pie plate moved in from the table edge, and the bar's pint and
  flip phone moved apart and clear of the ticket tray. drive_game checks that nothing on the table
  sits under the tray or the notepad or comes within 0.25 of the edge.
- **The machine's fill light has no distance falloff** (like the room points). Godot's default 1/d
  falloff made a hot spot on the diner booth the light stands against; the energy keeps the machine
  face lit as in M4.
- **Square buttons have stripes on their bezels**, painted after the banding G liked on the panel
  around PLAY ALL; the lit caps stay clean, like PLAY ALL's dome. The PLAY ALL stripes themselves are
  not painted: they are shadow banding from the key light on the dark panel, kept because G likes them.

## Milestone 6: menu, developer panel, save, Chinese
- **The save keeps the whole session** (G's pick; the web build kept only settings): money and the
  ledger, every box's seed and progress, the tray, the discard pile, plus the settings. A ticket in hand
  that is not revealed yet (even partly torn, or with its band broken) goes back to the front of the
  tray and is dealt again untouched; a revealed one was already paid and counts on the pile. A bill
  being fed is saved as credit; tickets still queued in the machine are dropped (never paid for). The
  game autosaves every 2 s (written only when something changed) and on quit or closing the window.
  A save that does not add up, or cannot be read, is set aside and the game starts fresh.
- **The game starts at the machine** after a reload, as on a fresh start.
- **Menu extras** (G's pick): QUIT and FULLSCREEN, besides the brief's table, volume, sound and resume;
  plus LANGUAGE. The menu does not pause the machine (web build). Current choices show inverted
  (dark cap, lit text), as the web build's pressed keys.
- **A MENU key on the top-left plate** (the web build had MENU beside TABLE and CLEAR).
- **Chinese is finished in this milestone** (G's pick): every player string has English and Chinese
  (`locale/ui.csv`), the language follows the system until the player picks one. Ticket print, the
  machine's printed labels (PULL-TABS, form names, PLAY ALL) and room signs stay English (art and
  pack data). Fonts: the LCD faces fall back to Fusion Pixel 12px, the notepad hand to LXGW WenKai;
  both OFL, cut down to the characters used and renamed (LXGW WenKai reserves its name).
- **Pixel Chinese is as tall as the English capitals** (G picked this over a larger look after a side
  by side, `tools/preview_cjk.tscn`): same font size as the English, each character exactly the
  capitals' height and on the same baseline. VT323's capitals are 0.56 em and Oswald's 0.81, so the
  pixel font is cut twice (`cjk-pixel-lcd`, `cjk-pixel-cond`), lifted one grid row onto the baseline
  and scaled to each; `tools/measure_cjk.gd` shows heights equal and centres within half a pixel at
  every size used. Small Chinese text gets few pixels per stroke; G accepted that.
- **The menu keeps the larger Chinese** (G): the pixel font at 3/4 of full size, no menu text under
  size 24, so the menu's Chinese is all one size, through font variations with their own fallback
  (`LcdStyle.menu_look`). 继续 is in synthetic bold and at 24 like 退出 (RESUME stays 26 in English).
- PLAYALL reads 全下 (G).
- **2D vertices snap to whole pixels** (`rendering/2d/snap/snap_2d_vertices_to_pixel`): VT323's
  baseline falls on a half pixel, which drew the Chinese on the green keys blurred (继续).
- **Chrome keys share the green keys' black bezel, corners and inset** (G, M6 review), only the cap
  is metal.
- **Developer panel** follows the web build's bench, in Chinese with the system font: tables, forms
  (picking one shows its box and hands out a free ticket, not counted as spent), new box from a seed,
  the box's real counts and expectation, reset of tickets and money (boxes stay), the lamp step
  (replaces [ and ]; it replaced F1-F3 for rooms too), and the sound bench: a file replaces a sound,
  each with its own volume 0-200%. Replacement files are copied next to the save. A replaced tear is
  cut into equal steps (no crackle marks), and the band then plays the pop, as on the web.
