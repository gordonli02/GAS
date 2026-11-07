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

## Milestone 7: export
- **Built-in packs ship as a folder next to the executable** (`packs/core`), not inside the .pck:
  `packs/.gdignore` keeps the engine from importing pack files, which the loader reads raw, so
  they cannot travel in the .pck. `Platform.builtin_pack_dir()` uses the project folder in the
  editor and the executable's folder in an export. This is also how Workshop packs will arrive.
- **An editor export plugin** (`addons/last_sale_export`) copies the packs and the licence texts
  (font OFLs, Godot's licence and third-party notices) beside every export, from the editor or the
  command line, and keeps `builds/` out of the editor's scan.
- **Two presets**: "Windows Desktop" (release, no tests or tools) and "Windows Verify" (debug, with
  the tools). Exported Godot refuses a scene path on the command line, so debug builds take
  `--run-tool=<scene>` after `--`; release builds ignore it.
- **Missing or damaged ticket data shows a message** (English and Chinese) instead of a game that
  cannot run.
- **Parts made at declaration are freed when a node goes early** (`Orphans`): the game stopping
  before it adds them (missing data, a tool taking over) no longer leaves nodes behind at exit.
- **The dispenser motor now loops the whole recording** (G, after comparing): since M4 it had
  looped only the first 0.20 s of `dispense_loop_fast.wav` (0.98 s), because the engine's sounds
  are imported as QOA and the loop end was computed as if the data were 16-bit PCM
  (`data.size() / 2`). The loop end now comes from the stream's length.

## Milestone 8: the run (story mode)
The design is in `docs/roadmap.md` (G's decisions, in Chinese); this is how it landed in code.
- **Two modes, two save slots.** Free play is the demo, unchanged (web-exact boxes, the flat house
  loan). The run has its own table, money, boxes and pile. The save is version 2: `session` (free
  play) and `run` (`{state, session, day}`); a version 1 save carries over as free play. The menu's
  MODE keys switch; NEW RUN asks once (SURE?) before it throws a run away.
- **A run is three layers of debt** (`RunState`, numbers in `RunConfig`): each layer has its days,
  its debt, its stake, its wages and its house line. A day is the machine or a shift of work;
  the debt is paid in one go, any time, and the next layer starts at once on a new day. Leaving on
  the last day pays it or ends the run.
- **Working every day and spending nothing clears the run to the dollar** (G). The starting cash
  counts toward the first layer, so the last dollar of the last wage pays the last debt.
  `RunConfig.problems()` and `test_run` check it; one day off work, one dollar spent or one loan
  breaks it.
- **The wage follows the shifts worked in the layer, not in the run.** The roadmap first said "in
  the run"; that left a player who gambled through layer one with layer-one wages at layer three's
  stake, where a shift bought six tickets. The curve is not shown: the card shows today's wage only,
  and at that wage the layer's days never reach the debt.
- **The stage's numbers belong to the layer, not the scene.** A scene bought between runs may
  replace a layer's scene later (roadmap), so the scene is the look and `RunState.scenes` says
  which room each layer uses. For now: the player's table, then the other two rooms.
- **A stake multiplies price, prizes and bills** (`FormDef.scaled`): layer two sells the same forms
  at $5 with a $2,500 top prize and takes $25 to $500 bills. Same form id, so a seed gives the same
  box at every stake; painted art is cached per stake (`art_key`).
- **LOAN in the run**: the layer's line (a base that rises each layer, plus `loan_bonus` for perks
  to come), one step per press, 25% interest added once, all of it on top of what the layer asks.
  It starts clean in the next layer.
- **NEW BOX** (bill plate, or N) arms like PLAY ALL: the next column press changes that column's
  box for the fee, from cash. Tickets already bought keep their box.
- **Last sale**: the buyer of a box's last ticket gets the stage's prize at once, counted as won.
  Run only; free play stays as the web build.
- **LEAVE asks first, then throws unopened tickets away** (G, M8 review; at first tickets still to
  open blocked it, which meant opening a hundred tickets to end a day). The LEAVE card says how
  many would go; NEXT DAY or PAY on it confirms. They stay paid for and are never opened, whatever
  they held; an opened ticket in hand goes on the pile. So no ticket crosses a day or a layer (changed after M9: tickets now stay overnight within a layer; see "After M9").
- **Paying is always the player's own press** (G): PAY is a key on the cards and nothing presses
  it for them. The one exception is the deadline: ending the last day with the money there pays.
- **The run's card** (`RunCard`) carries the story beats, the day's choice, the shift worked, LEAVE
  and the settlement; nothing reaches the machine behind it. It has its own MENU key (it covers the
  HUD's). Story text is a first draft, English and Chinese.
- **Every number is a placeholder** until the balance pass. `tools/sim_runs` plays bots through
  whole runs. Without perks (500 runs each): a bot that buys blind clears 3% of runs and reaches
  the second layer in half of them; one that also uses the whole house line clears 8%.
- **Run statistics are kept from now on** (`RunState.stats`): tickets, shifts, loans, box changes,
  last sales, days spared. The settlement shows them; achievements and the money kept between runs
  (M13) will read them.

## Milestone 8.5: small fixes and feel
From G's own to-do list (2026-11-06); the plan is in `docs/roadmap.md`.
- **A ticket flies out of the machine as the form that was bought.** The flying tickets all shared
  the tray stack's picture, which showed the next ticket to be opened: usually a Big Catch. Each
  now has its own, in the bought form's card shape (Lucky Spur is wide). The machine's tray shows
  the ticket sold last on top; the wooden tray on the table still shows the one opened next.
- **Space opens a flap half again as fast** (`FlapSim.SPACE_SPEED`, 1.5): the tear and its settle,
  for a flap Space started. A tear the hand lets go of keeps its pace, and so do the deal, the
  flip and the toss.
- **Winners get a pile of their own** (looks only; the prize is paid on the reveal as before): a
  second `DiscardPile` behind the tray, across the table from the discards, dropped tighter
  (`Game.WIN_PILE_AT`, `WIN_PILE_SPREAD`; `tools/preview_win_pile.tscn` shows it in every room).
  It is saved inside the session's pile (`pile.wins`); a save from before has none and starts it
  empty.
- **A winner lies prize side up** (G, M8.5 review): on the winners' pile a card shows its own
  ticket's inside, the prizes it held and the digits of the groups that did not win, where the
  discard pile shows the printed front. So there a card is one ticket
  (`"<form>#<box seed>#<number>"`, kept in the save), painted once at half the hand's
  resolution and let go when no card shows it; the game finds the ticket again from its box's
  seed. The flaps themselves are not drawn on the pile.
- **TICKETS BACK SIDE UP** (menu; setting `back_first`, off by default): a ticket comes to the hand
  back side up, so there is no flip. A setting in both modes, not a perk (G). A banded ticket
  arrives with its band on: the band breaks first, from the back, by drag or Space, and until
  then the ticket can still go back to the tray (`TableNav`: a banded ticket back up was always
  one whose band was broken). It takes hold from the next deal.
- **Hot Plate and Lucky Spur win by group** (`win_display: "each_group"`, G): each window or column
  can win on its own, so a ticket holds up to five (Hot Plate) or three (Lucky Spur) prizes; a
  group that did not win prints its digits. Big Catch still wins as a whole ticket.
  - **The box is the web build's**: type, size and prize counts are rolled as before, so the money
    in a box and what a ticket is worth on average do not change. Only the deal differs: each
    prize lands on one group of one ticket (`BoxGenerator._deal_cells`). The golden test compares
    these two forms' boxes only; dealt the old way they still match ticket for ticket.
  - **Both modes** (G): free play's Hot Plate and Lucky Spur are no longer the web build's tickets.
    A save from before keeps its money and its place in each box, but the tickets left in those
    two forms' boxes (and any in the tray) are dealt anew.
  - **`BoxModel.stack_share` is 0.12** (proposed here, G agreed in the M8.5 review). G first chose
    "prizes land at random", but a box has about 34 prizes in 3,000 to 5,000 groups, so at random
    a ticket with two prizes turns up once in two boxes: the new rule would hardly ever show. With
    `stack_share`, a prize lands that often on a ticket that already holds one: about four such
    tickets a box, one with three now and then (200 boxes: Hot Plate 6,864 prizes on 6,033
    tickets, 743 holding two or more). 0 gives the plain random deal.
  - A ticket's `prize` is the sum, its `tier` the best of its groups (the sound and the shake follow
    the sum); `wins` lists the tier per group. A top prize in any group gives the ticket its verify
    code; Lucky Spur prints it in that column, Hot Plate's windows have no room for one (as before).
  - Lucky Spur's layout (`core:jar`) lost its whole-card winner: its columns have rects and a
    `win_slot`, and the dividers are always printed.
- **The developer panel's free ticket** puts back any untouched ticket in hand, front or back up
  (it only did so for one front up).

## Milestone 8.6: the machine and five new forms
The plan is in `docs/roadmap.md`; pictures are in `docs/m8.6/`.
- **The machine is the eight-column kind** G photographed (`ref images/ng3-8col.png`): two gold
  cabinets of columns with a black console between them. The roadmap asked for mockups first; the
  machine was built in the engine instead, with the number of columns a parameter
  (`MachineView.build` takes any list of forms; half stand left of the console, half right), and
  `tools/preview_machine.tscn` renders it with 8, 6 and 4 columns for G to pick from. It stands at
  8: one column per form.
- **A column** shows, top to bottom: the front of the ticket it sells (a wide ticket stands on its
  side, as in real machines), the stack of tickets left with its rule, a lit button, and a plate
  with the key that presses it, the form's name and the price. Keys 1-8 press the columns (1-3
  before). The whole column answers the pointer; only the button sells.
- **The LCD has three lines**: credit, status, and the column under the pointer or pressed last
  (number, name, price). It does not show how many tickets a box has left: that belongs to the
  box-reading perks (M9).
- **PLAY ALL is the button after the last column** (`Game.press_play_all`); it was index 3.
- **Tickets fly out of the column that sold them** into that cabinet's tray; each of the two trays
  holds its own stack, topped by the ticket sold last on that side.
- **The machine is rebuilt when the stage changes** (a layer's stake changes the print on the
  fronts and the prices on the plates; a layer may sell other forms). All its pictures are painted
  in one frame, so this takes a few frames.
- **A layer can name its columns**: `"forms": [form ids]` in a `RunConfig` layer; without it the
  machine sells every form the game started with. No layer names any yet.
- **The machine moved in every room** and turns less at rest (it is 12.7 wide, was 5.9): where
  the web build put it, the diner's booth, the bar's counter and the bingo hall's long table
  stood in front of it. `test_rooms` no longer compares its place with the web build; it checks
  that the machine clears the walls and the furniture. From the table the machine fills the right
  of the view and runs off its edge.
- **The machine view** keeps the machine within 0.58 of the window's width
  (`CameraRig.MACHINE_SHARE`), so the two HUD plates stand beside it.
- **Five new forms** on G's themes, each a new look on one of the three ways a ticket opens, with
  the same prize table and box rules (so the same odds): Pecking Order and Nugget Rush open like
  Hot Plate, Ka-Bawk! and Peckeye like Big Catch, One Flock like Lucky Spur. Their insides, flaps
  and band rules are the core layouts'; only the fronts (and One Flock's band) are their own,
  after real tickets: three of a kind per prize row, a menu board, the prize list set as text.
  Names and copy are first drafts.
- **Their art is drawn by a script** (`tools/make_ticket_art.py`): SVG in the web build's manner
  (flat fills, the same outline colour and weights, the same goggle eyes), turned into PNG by the
  engine's own SVG reader (`tools/raster_svg.gd`). `tools/make_new_forms.py` writes the forms and
  layouts.
- **Two additions to the layout format** (packs/README.md): `each_tier` takes `tiers` (cells for
  some tiers only, so tiers can differ in size or carry their own text), and `rect` takes `radius`.
- **Peckeye is a parody** of the spinach-eating sailor: its own name and drawing, nothing taken
  from the original. Worth another look before release.
- **Exports leave out `ref images/` and `docs/`** (the editor imports any picture in the project,
  and the presets export every resource).

### After G's first look at M8.6
- **The machine belongs to the scene** (G): a plainer venue has a smaller machine selling fewer
  forms. A room may name its forms (`RoomSet.ROOMS[id].forms`, `RoomSet.machine_forms`); without
  a list its machine sells every form. The bingo hall has four (Big Catch, Hot Plate, Lucky Spur,
  Pecking Order: which four is a first guess); the diner and the bar have all eight.
- **Up to four columns stand in one cabinet with the console on its right**
  (`MachineView.SINGLE_MAX`), after G's picture of the four-column machine; more columns split
  into two cabinets around the console. One cabinet has one tray.
- **Columns are a view of the machine** (`Game.columns`: indexes into `machine.forms`). In free
  play the machine keeps a box for every form whatever the room shows, so a box goes on where it
  was when the player comes back to a bigger machine, and tickets already bought of a form the
  room does not sell are opened as usual. In the run a layer's machine holds only what its
  scene sells (`Game._run_machine`); a layer's own `forms` list picks among those.
- **Changing rooms builds the machine anew** when its columns differ (`Game.set_room`, a few
  frames; a build overtaken by another gives up). PLAY ALL and NEW BOX are let go.
- **Only Lucky Spur has the paper band** (G). One Flock keeps the wide card and the three
  columns, without a band: it flips as soon as it is dealt.
- **Only living things have a face** (G): the bombs, nuggets, bell, rocket, spinach can, anchor
  and pipe are drawn without eyes and mouth. Lucky Spur's star and cactus lost theirs too: they
  are drawn again by `tools/make_ticket_art.py` as the web build drew them, less the face, so
  those two files are no longer the web build's export (`tools/export_web_art.js` would bring
  the faces back).
- **The symbols are pictures now, not drawings in code** (G found the code-drawn ones too
  plain). Seven forms have new symbols: six painted by GPT image from G's prompts (Big Catch,
  Hot Plate, Pecking Order, Ka-Bawk!, One Flock, Peckeye; originals in `docs/art_redo/gpt/`), one
  redrawn as SVG (Lucky Spur; `docs/art_redo/6_jsr_spur/`, rendered with headless Chrome by
  `docs/art_redo/render.py` because it uses filters the engine's SVG reader lacks). Hot Plate
  had an SVG redraw first (`5_adcap_plate/`); G painted it again with GPT image and that took
  its place. G leaves the nuggets as they are. `tools/import_symbol_art.py` trims each source, gives every symbol the same margin and
  writes the two sizes into `packs/core/art/`; Peckeye's front picture is cut from the new sailor
  there too. `tools/make_ticket_art.py` now writes only what is still code-drawn (the nuggets,
  One Flock's flag), so it cannot overwrite the pictures; `tools/export_web_art.js` still would
  (first three forms). Each form has its own manner, as G chose them; the pack format is
  unchanged. The earlier proposals (`tools/art_proposals.py`, `docs/m8.6/style_*.png`) and the
  redraws G did not take (`docs/art_redo/1_…` to `5_…`) are not used.
- **Three forms changed shape** (G). The shape of a card is layout data (`card.size`,
  `card.canvas`), so nothing in the engine knows these three:
  - Hot Plate is square, 1.7 a side (`layouts/plate.json`, written by
    `tools/make_core_layouts.py`): the five windows, wider and lower, and a front of its own.
    `layouts/windows.json` stays as the built-in tall five-window card ("core:windows", which
    the pack format promises other packs); Pecking Order and Nugget Rush are built on it.
  - The long card is 21:9, 2.59 by 1.11: its long side is as long as a layout allows
    (`LayoutLoader.CARD_MAX`). One Flock has it lying (`strip` in `tools/make_new_forms.py`:
    one flap hinged along the top, the digit groups side by side). Ka-Bawk! has it standing
    (`tower`: one flap hinged on the left as on Big Catch, the groups one above the other).
  - What had to give in the game: the machine fits the ticket it shows into a box
    (`MachineView.SHOW_W` by `SHOW_H`), so a square card is no wider than the others; the
    table tray is as wide inside as the longest card (`TableTray.JW`); a card longer than a
    tray is deep lies turned in it (`TableTray.set_stack`, `MachineView.set_trays`).
  - `tools/preview_tickets.tscn` holds a ticket of each form at the table and saves it dealt,
    turned over and open, for looking at a shape in the game.

## Milestone 9: perks, items and the phone
The plan and the numbers are in `docs/roadmap.md` (M9, in Chinese); this is how it landed in code.
- **The phone** (`Phone`, a CanvasLayer over the run's card and under the menu) has LOAN, SHOP and
  CONTACTS; free play has LOAN only. It lies on the table (`TablePhone`, across from the notepad;
  clicking it opens it), and the HUD's PHONE key, P, and a PHONE key on the run's card open it too.
  Like the card it shows a translated state the game builds (`Game.phone_state`) and reports keys
  (`acted`); the game decides. Nothing reaches the table, the machine or the card while it is up;
  Esc puts it away before it opens the menu.
- **LOAN left the bill plate and the card** (G: it lives on the phone). The plate is the bills,
  CASH OUT and NEW BOX.
- **Perks, items and services are data** (`Catalog`), the rules are the effect hooks in `RunState`:
  `effect(name)` sums the levels of every perk on that effect, and the rules ask it
  (`prize_bonus`, `loan_limit`, `change_fee`, `last_sale_prize`, `luck`, `reading`). A new perk on an
  existing effect is data only. Effects: `prize_pct`, `luck`, `loan_line`, `fee_cut`, `last_sale_pct`,
  `reading`. Text is translation keys; `test_locale` checks every key the catalog shows.
- **The shop is open all the time in the run** and takes cash only (not machine credit); what it
  takes is `paid` in the ledger, so the identity holds. Prices are the catalog's times the layer's
  stake. Perks stay for the run; items are used up; a service may be capped per layer.
- **LUCKY STREAK passes losing boxes over when they load** (`MachineLogic.luck`): a box of a losing
  type is, with that chance, replaced by the next seed's box, once at most. The roll comes from the
  seed (`"<seed>|luck"`), so a seed always loads the same way and saved boxes, kept by their seed,
  are untouched. Boxes already in the machine do not change when the perk is bought.
- **A prize's bonus is paid with it** (`RunState.open_ticket`): the perk's share, rounded, plus the
  prize again for a LUCKY COIN (used up on the next winner). It counts as won. Free play is unchanged.
- **Box reading** (`BoxReading`) reads what the machine still holds: tickets sold are gone whether
  they were opened or not. Levels 1-3 show on the LCD's status line for the column named on its
  third line (pointed at or pressed last); level 3's prize counts take turns with the name on the
  third line. Level 4 turns the notepad into a page of boxes (opened, won), so the ledger's lines
  are off the notepad then (NET stays on the HUD). A BOX REPORT reads one box at level 3 until that
  box leaves the machine (`RunState.reports`, saved).
- **Items used on a column** (PEEK, BOX REPORT) arm the machine like NEW BOX: the phone goes away, the
  LCD blinks PICK A COLUMN, and the next column press reads that column instead of selling; PLAY ALL
  lets it go. Only at the machine on a day of play.
- **Contacts are a shell with a calling flow**: ring, then the contact picks up (a line, their
  services) or nobody does. Two placeholders: the lender (ONE MORE DAY, once a layer:
  `RunState.extra_days`) and an unknown number. Who is in the phone is M12.
- **The save keeps the run's purchases** in `RunState.to_dict` (`perks`, `items`, `extra_days`,
  `services`, `reports`); a run saved before M9 loads with nothing bought, so the save version did
  not change. Perks not in the catalog are dropped, levels are kept within the perk.
- **`tools/sim_runs` also prints what a dollar of tickets pays back** at some perk levels, boxes
  bought out whole (`RunSim.box_return`): about 1.00 without perks, 1.30 with FAT PRIZES at the top,
  1.56 with the three money and luck perks at the top. A `perks` bot buys perks before playing; it
  buys too few to change the clear rate yet (that is the balance pass).

### After M9 (G)
- **Unopened tickets stay overnight within a layer** (G). This replaces the M8 rule that LEAVE throws
  them away: leaving puts a ticket in hand that is not revealed back on top of the tray, and the tray
  is kept into the next day. They are thrown away (and counted in `stats.discarded`) only when the
  layer ends: paying it, or the end of its last day (`Game._layer_ended`). The day's cards say how many
  are waiting, and that paying now throws them away.
- **Putting a ticket back** (G): an untouched ticket in hand (what `TableNav` lets go back when leaving
  for the machine) goes back into the tray by a click on the wooden tray, or R. It goes to the bottom
  (`TicketTray.put_last`), so the next ticket comes up; with no other ticket in the tray nothing is dealt.
  The ticket flies there (`TicketFlow.send_away`, state AWAY).
- **The trash can** (G; `TrashCan`, at the near right of the table, in front of the tray): a click, or
  Delete, puts up a card first (both modes): THIS ONE (the unopened ticket in hand) or ALL (that and
  the whole tray). They stay paid for and are never opened. An opened ticket in hand just goes on its
  pile. "盒子" in G's note is read as the wooden tray of unopened tickets, not the machine's box.
- **The phone on the table opens the phone in every state of the ticket in hand** (it did not while a
  ticket was back side up).

## Perk tree and items (after M9, with G)
The tree, the numbers and why are in `docs/roadmap.md` ("技能树与道具", in Chinese); this is how it
landed in code. It replaces M9's six placeholder perks, four items, four reading levels and the
perk shop.
- **Perks are offered, not shelved** (G). `RunState._new_day` deals `Catalog.OFFERS` (plus
  `offer_bonus`, the hook for money kept between runs) at the start of the run, after every day and
  at each new layer: `deal_offers` draws from `offerable()` (requirements met, not at the top) by
  `Catalog.RARITY_WEIGHT`, a level up x1.5 and a perk with requirements x2, two branches at least.
  The draw is seeded by the run's seed, layer, day and reroll count, and the offers are saved, so
  loading never deals new ones. Any offer the cash covers can be bought (`buy_offer`); a reroll costs
  double each time in a day; `close_offers` with nothing bought gives a random item. The day's card
  shows the offers first (`Game._offer_card`, keys `offer_<k>`, `offer_free_<k>`, `offer_reroll`,
  `offer_done`); the phone's perk page is the tree to look at, one branch a page.
- **One prize formula** (`RunState.pay_ticket`): printed prize x bet x (1 + the "+%" effects) x the
  "x" effects, an ENCORE paying it twice; every prize in the run goes through it (by hand
  `open_ticket`, at once `open_batch`). The effect names and their slot are in `Catalog`'s header.
  Counters the effects need are run state and saved: `dry` (losers in a row), `snow` (boxes cleared
  under SNOWBALL), `layer_losers` and `layer_tops` (reset with the layer), `scrap` (SCRAP DEALER's
  cents, paid in whole dollars, since 10% of a $1 ticket is not a dollar).
- **An opening is one unit**: `open_batch` counts its winners (every prize on a ticket and every
  ENCORE, rolled from the box seed and ticket number) for CHAIN, and NET WORTH reads the cash the
  opening started with, so the prizes of one opening do not feed each other (with every perk at the
  top an ALL IN paid $100 million before that).
- **The machine** got a bet (`MachineLogic.bet`, `price(i)`; a tray entry keeps the bet it was bought
  at, and the save keeps it), FORTUNE's repeated passes (`luck_tries`, each on its own seed's roll) and
  ASSEMBLY LINE (`flow_line`: a box loaded after a sell-out is never a losing one). The rolls come from
  seeds, so a saved box is still found by its seed.
- **SHUFFLE reorders a box** (`TicketBox.shuffle_rest`): the tickets not sold yet are permuted from
  the seed and the shuffle count, and renumbered by their new places (`no` stays the index the tray
  and the pile look tickets up by). The machine's save keeps the cursor of each shuffle and replays
  them on load. A box that was changed out and is rebuilt only for the winners' pile
  (`Game._ticket_for`) is rebuilt unshuffled, so a winner bought after a shuffle from such a box may
  show another ticket's inside on the pile.
- **ALL IN and QUICK HANDS skip the hand**: the tickets go straight onto their piles
  (`DiscardPile.land_many`, one rebuild); ALL IN pays from credit, then cash (`Economy.spend`, counted
  as spent), and the box's last sale is paid as usual.
- **Items** have four uses: `column` (armed like NEW BOX, the next column press), `now` (from the
  phone: TIP-OFF, HAPPY HOUR, SAFETY NET, COPIER), `auto` (LUCKY COIN, WHITE-OUT, BOX KEY) and `offer`
  (CHEAT SHEET, a key on the offers card). Items are bought off a daily shelf (`deal_shelf`, seeded and
  saved), and held up to `item_cap()`.
- **Box reading is a chain of five perks** on the `reading` effect (one level each), so the tree can
  hang other perks off its first node. `BoxReading`: TOP IN / NO TOP, the box's nature by its type,
  heat, the exact numbers (`COUNT`, also a BOX REPORT's level), the notepad (`BOOKS`).
- **`tools/sim_runs`** has two more bots (`skip` never buys a perk; `build` only takes the money and
  luck engines) and prints the return of the builds in `RunSim.EV_SETS`.

## Milestone 9.6: ticket shapes (the run only)
The plan is `docs/roadmap.md` (M9.6, in Chinese); this is the first layer of it in code.
- **A form may carry a `shape`** (`FormDef.shape`, from the form's json; `PackLoader` checks it):
  `top` and `mid`, each a `[min, max]` share, and `prizes`, the form's prize table in the run
  (tier key to prize at stake 1).
  - The shares replace `BoxModel`'s top and mid shares in `BoxGenerator._roll`, so the money
    moves between the tiers while the box's type, size and prize money (set by its type, to the
    rounding of the smallest prize) are what they were: the same draws are made, with other
    ranges. So every form pays back the same on average, whatever its shape.
  - The prizes go on by `FormDef.shaped()`, a copy with its own tiers, the way `scaled()` puts a
    layer's stake on (`RunState.stage_forms` does `shaped()` then `scaled()`). Its tickets print
    its prizes (the layouts squeeze a wider number into the box), and `art_key` carries a `~`
    so its painted art is its own. The game only ever looks a form up in the machine
    (`Game._form_for`), so the run's tray, piles and saves all see the shaped form.
- **Only the run deals shapes** (G): `BoxModel.shapes`, set by `RunConfig.box_model`, and
  `shaped()` is called by the run alone. Free play's machine has no model and sells the pack's
  forms, so its boxes and tickets are the web build's still and the golden test did not move. A
  box is always rebuilt with its machine's model and form (`SessionState`, `Game`), so a saved
  run gets its shaped boxes back; a run saved before this gets other prizes in a box it was in
  the middle of (no save version bump, runs are in development).
- **The shapes, first guess** (stake 1; G to tune): Big Catch $1,000 / $100 / $25, top
  0.5–1.0, mid 0–0.1 (a $1,000 in about one box in five, little in between: the jackpot form);
  Ka-Bawk! $500 / $250 / $50, top 0.75–1.0, mid 0–0.1 (about 1.3 tops and 8 small prizes a box:
  all or nothing); Hot Plate $200 / $50 / $10, top 0–0.3, mid 0–0.05 (about 90 small prizes a
  box, 8 winners in 100 tickets); Nugget Rush $100 / $50 / $5, top 0–0.2, mid 0.1–0.3 (about
  150 nuggets a box, one ticket in eight wins); Lucky Spur $500 / $200 / $25, top 0.05–0.25, mid
  0.5–0.8 (two to four $200s, no top). Pecking Order, One Flock and Peckeye have no shape until
  their signature rules.
- **`tools/sim_runs` prints each form's boxes** in the run's model (`RunSim.form_table`): return,
  winners per 100 tickets, tops a box and the standard deviation of one ticket's prize, the
  measure of how bumpy a form is: about 4 for Nugget Rush, 5 for Hot Plate, 8 for a plain form,
  11 for Lucky Spur, 15 for Big Catch, 18 for Ka-Bawk!. The returns are all about 1.
- **`tools/preview_tickets` takes `--run`**: the forms as the run sells them, each opened on a top
  winner (a box with one is found and sold up to it). The pictures of the five shaped forms are in
  `docs/m9.6/`: the $1,000, $10 and $5 fit the layouts' boxes as they are.

## Milestone 9.5, step 1: wages and SAVINGS (the work line)
G, 2026-11-06: no more hidden raises; working alone is not enough, working and buying SAVINGS is
exactly enough. How it landed:
- **A layer has one `wage`** (`RunConfig.STANDARD`), the same every day; `RunState.wage` reads
  it, `shifts` stays a statistic. `last_wage` is the wage.
- **A layer's debt is not written in the config: it is the work line's cash on the last day**
  (`RunConfig.work_line`, filled into `layers[i].debt` by `from_dict`). The line: each morning
  after the first, cash grows by SAVINGS' percentage; then one level of SAVINGS is bought when
  the layer allows it (level k from layer k on, `line_buys`) and the cash is there; then the day
  is worked. So the rule holds by construction and the debts are as ugly as compound interest
  ($1,136 / $5,250 / $21,883 with the placeholders). `problems()` reports a debt that is not the
  line's, a layer where wages alone would meet the debt, and a line that never reaches the top
  of SAVINGS. `from_dict` takes a catalog (the standard one by default) for SAVINGS' numbers.
- **SAVINGS grows cash every morning**, a day of work included (it was the morning after play
  only), and has no requirement, so it can be bought first thing; `shelf: true` marks it for the
  fixed shelf (M9.5, not built yet). Placeholders: $50 / $150 / $400 for 10 / 20 / 30% a day
  (they were $300 / $800 / $2,000 for 4 / 7 / 10%). Wages: $150 / $700 / $2,500.
- **The simulator's work bot walks the line** (`RunSim._save`): it buys SAVINGS as `line_buys`
  says and nothing else, so it clears every layer with nothing left. `test_run` walks it too, and
  checks that one day off, one dollar spent, one loan, or never buying SAVINGS all fail.
- What went: "the player sees only today's wage and cannot add it up" (the wage is flat now);
  the price of the sure path is the SAVINGS it has to buy.
- **Found on the way: a first-day loan pays for itself.** The house line's interest is 25% once;
  SAVINGS compounds daily, so $100 borrowed on day one grows by about 46% over the first layer's
  four mornings and the line clears with money to spare. A loan on the last day (no morning to
  grow) still fails, and that is what `test_run` checks now. The rule "one loan and working is
  not enough" cannot hold with a one-off interest under any daily SAVINGS that outgrows its own
  price; the fix is G's call: interest that compounds daily like SAVINGS (the story is about
  compound interest, after all), or accepting borrow-to-invest as a line of play.
- **Loan interest compounds daily** (G, after the finding above): `RunConfig.loan_interest` is
  percent a day; `RunState.borrow` adds the principal only and `accrue`, each morning of a layer
  (with SAVINGS), adds the interest to everything owed. Placeholder 15% a day, above SAVINGS'
  first level, so a loan on the first day of the work line loses (the test is back); at
  SAVINGS 3 (30%) borrowing to invest wins, which is the money-makes-money build. LOW RATE now
  takes 5 / 10 points off (10% / 5% a day), never to zero. BORROWED LUCK keeps growing while a
  loan is kept, which G wanted. The phone says "INTEREST n% A DAY ON WHAT IS OWED" with LOW RATE
  taken off.
- **The line's checkpoints are in the config** (G: SAVINGS on the first day, then each level
  on time): `from_dict` fills `layers[i].savings_day` with the day of the layer the line buys
  on (1 / 2 / 4 with the placeholders), `problems()` insists the first is day 1, `line_text()`
  says it in words and `tools/sim_runs` prints it. Buying later than the checkpoint grows less,
  and the line falls short.

## Milestone 9.5, step 2: the catalog as the tree draft v2, and every hook
The plan is `docs/roadmap.md` (M9.5, in Chinese) and the draft `docs/perk_research.md`
section 5; this is how it landed in code. Every number is a placeholder.
- **The catalog is the mixed tree** (`Catalog.STANDARD`). Sixteen perks carry `shelf: true`
  and sit in the `shelf` branch: the reading chain, INFORMANT (two levels: PEEK sees 50 /
  100, the second a free PEEK a day, HOUSE FRIEND merged in), GOOD CREDIT, LOW RATE,
  SAVINGS, REGULAR (-50 / -75%, never free), HAGGLER (-25%), BIG POCKETS and HIGH ROLLER
  (no requirement, G), QUICK HANDS, PICKY and HOUSE ACCOUNT. Everything else is dealt,
  and has a kind (`Catalog.kind`): `build` (six lines, each a branch: clearing, jackpot,
  small, batch, money, luck), `risk` (two levels, a `cost` key on each: LOAN SHARK,
  BORROWED LUCK, SHORT WEEK, FLARE ONLY, DOUBLE DOWN, NO WAY BACK), `twist` (two levels:
  MOONLIGHTING, RETURNS, SEAL, LOYAL, VARIETY, MAGNET) and `sure` (INSURANCE, STAKEOUT,
  MARKED). A level may carry `extra`, more effects put on at that level (SHORT WEEK's day
  cut, FLARE ONLY's zeroed prizes, LOAN SHARK's interest); `requires_any` is an "or"
  (READ THE FLARE needs CLOSER or REGULAR). `problems()` checks the kinds' rules.
  Gone: HOUSE FRIEND (into INFORMANT 2), the BOX KEY (a $25 coupon). Dealt perks hang off
  shelf perks where the draft says (JACKPOT HUNTER off READ THE FLARE, NET WORTH off
  SAVINGS, MARKED off INFORMANT, CHAIN and ENCORE off QUICK HANDS); `offerable()` deals
  only what is off the shelf, `buy_perk` sells the shelf. The form perks of section 6b
  wait for the signature rules (M9.6's second layer).
- **Two hooks, one for each slot**: `effect(name)` sums (the "+" effects, `extra` included)
  and `effect_x(name)` multiplies (the "x" ones: `top_x`, `mid_x`, `low_x`, `stack_x`,
  `first_x`, `last_sale_x`, `loan_x`, `rate_x`), so BIG FISH 2 and FLARE ONLY 2 together
  are x20 on a top prize. PENNY JAR and MIDDLE CUT multiply the small and middle tiers
  by the tier's role.
- **The risk perks' prices**: SHORT WEEK takes `day_cut` off `days()` (never below the day it
  is, so bought on the last day it changes nothing); DOUBLE DOWN adds `offer_more` to
  `offer_count()` and `debt_up` to `due()`; FLARE ONLY drops the zeroed tiers in
  `pay_ticket` (a ticket left with none is a loser in every respect); LOAN SHARK multiplies
  the line and the rate after LOW RATE's cut, so the two never reach zero; NO WAY BACK
  makes `can_work()` false and counts `noback_days` at the end of every day of play;
  BORROWED LUCK is `owe_pct()`: what is owed, interest included, as a share of the line,
  times the level (100 / 200%), nothing once repaid (G: "as much as you owe"; the
  half-the-line rule went).
- **The twists**: RETURNS and the RETURN SLIP go through `refund_tickets` and
  `Economy.refund` (cash back, no longer spent; the trash can's card says the share, and the
  trash pays it); LOYAL and VARIETY read `forms_today`, filled by `count_sales` with the
  form's uid (the game counts by form now), the higher of the two counts; MAGNET is the
  machine's (`MachineLogic.magnet`): when the last ticket of a window of N from the box's
  start is sold and none of the window won, the next small prize is moved onto it;
  SEAL keeps the hottest boxes (by `BoxReading` heat) at `pay(e, m)` in `sealed` and
  `new_machine` puts them in the next layer's machine from their seed (the same box at the
  new stake, prizes scaled, the log replayed); PICKY lets `change_box` take a form, which
  the machine's column sells from then on; HOUSE ACCOUNT is `Economy`'s tab
  (`tab_on`, `tab_limit`: the house line left; `buy` falls back to the tab, `power()` and
  `can_buy()` are what the machine asks instead of the credit), settled by `_settle_day`:
  cash first, the rest borrowed as principal (the day was interest free); MOONLIGHTING is
  `sale_cap` on the machine on a day of work (`work_tickets` less `day_tickets`) and
  `can_open()` false that day.
- **A sure win moves a prize of the box forward** (G, section 7), never makes one.
  `TicketBox.swap` is the primitive, logged in `ops` with the shuffles (`{"s": cursor}` /
  `{"m": [a, b]}`), `replay` rebuilds a saved box from its seed and the log (the machine's
  save carries `ops` and the column each box is in; a save with `shuffles` from before
  still loads). On it: `pull_winner(to, which)` (the next winner, the next small prize, the
  biggest, or one at random from the seed and the log), `front_load` (MARKED: a PEEKed
  column's next ten, winners first) and `scatter` (QUEUE JUMP: five winners into the next
  twenty). The machine asks the run before every ticket through a callable (`sure_next`,
  `RunState.claim_sure`): STAKEOUT's first ticket of the day, INSURANCE's ticket after the
  losers in a row; one at a time (`sure_armed`) until a ticket is opened. The SURE items
  (SURE THING, REEL IN, QUEUE JUMP) and the LUCKY COIN (now a column item: `coin_on`, the
  form's next prize) are used on a column like PEEK; a SURE item with nothing left to
  move is not used up.
- **Items**: PEEK and FAST FORWARD do 50; OVERTIME (a shift paid twice: used before the day
  is chosen, or after a shift, once); MOVER (a column's box and form trade places with the
  next column's, `MachineLogic.swap_columns`; the view is rebuilt); the RETURN SLIP;
  the three SURE items in a kind of their own. The BOX KEY is gone.
- **What the game wires now and what waits for the phone's pages (M9.5 task 4)**: the
  shelf is bought from the tree page (a BUY key on a shelf perk's card); RETURNS and the
  slip go through the trash can and the phone; the column items say what they did. Not
  wired yet: PICKY's choice of form at NEW BOX (the logic takes a form, the machine has no
  picker), SEAL picks the hottest boxes itself (G's draft lets the player choose),
  MOONLIGHTING's day of work does not go to the machine yet (the flow ends the day after
  the shift), HOUSE ACCOUNT's tab has no line on the LCD. The developer panel's "every
  perk" leaves the risk perks out (their prices would close the run's doors).
- **The simulator** keeps its bots; `build` buys QUICK HANDS off the shelf by its own rule
  and its list is the dealt perks of the draft; a bot that cannot work (NO WAY BACK) plays
  instead. Task 5 remakes the bots (gamble, the build lines, the exploit checks).

## Milestone 9.5, step 3: dealing
The rules are `docs/perk_research.md` section 5 ("12. 发牌规则") and `docs/roadmap.md`
M9.5; this is how they landed. The weights are placeholders.
- **A deal table per layer** (`Catalog.DEAL`, one entry per layer, the last one for any
  layer after it; `Catalog.deal(layer)`): each rarity's weight and the kinds left out.
  Layer 1: common 10 / rare 3 / legendary 1 (G, after a first look: the first layer
  must be able to raise a player's ceiling, so a legendary comes now and then once
  one is open), no risk; layer 2: 10 / 5 / 2 (the old `RARITY_WEIGHT`, which stays as
  the list of rarities); layer 3: 10 / 5 / 5. `Catalog.deal_weight(p, layer)` is a
  perk's weight there, 0 when left out, and `problems()` checks the table (three
  entries, a weight 0 or more for every rarity, known kinds, layer 1 without risk).
- **`RunState.offerable()` is the layer's**: a perk the layer's deal leaves out is not
  offerable at all, so the REROLL key greys out when nothing is left to deal.
- **`deal_offers()`** draws by the layer's weights, still x1.5 for a level up and x2 for
  a perk with requirements, from the same seed (seed, layer, day, reroll). The first
  `Catalog.OFFERS` of a deal hold two kinds at least and two branches: when the last of
  those would leave one kind, it is drawn again among the other kinds; failing that
  (the pool has one kind), among the other branches. Offers past the first three
  (DOUBLE DOWN, `offer_bonus`) are drawn freely. Two kinds means two branches (risk,
  twist and sure are each a branch of their own), so the branch rule only matters when
  the pool is all build.
- **The offers card** (`Game._offer_card`) shows each offer's kind (`Catalog.KIND_NAMES`)
  and, through `_perk_text`, a risk perk's cost. The rarity is not written (G): the
  line is in its colour (`Phone.rarity_color`: gold, blue, plain for common; a card
  line may carry a Color as its third element). Still no requirements on it (those
  are the shelf's).
- **The perks of a form** (section 6b) are not written; the hook is there: a dealt perk
  with `form` (a form's uid) is offerable only when `offerable(forms)` /
  `deal_offers(forms)` is given that uid. Nobody passes the machine's forms yet, so such
  a perk would never be dealt until the callers do.

## Milestone 9.5, step 4: the shop's pages, form tags, the leftover UI
The draft is `docs/perk_research.md` section 5 (parts 1, 2, 6 and 12); this is how the
phone's shop, the tags and the UI step 2 left behind landed.
- **The SHOP app has three pages** (`Phone.shop_tab`: `shelf`, `today`, `items`; keys
  `tab_shelf`, `tab_today`, `tab_items`). SHELF lists every shelf perk in the catalog's
  order as a card (`shelf_<perk id>`, `Phone.row()` finds a card for the tools): level,
  what it does now and next, its price here, what it needs (requirements show here
  only, G), and a BUY key (`buy_perk_<perk id>`, greyed when it cannot be bought).
  Under it YOUR BUILD: the dealt perks held (`build_<perk id>`), level, kind in the
  rarity's colour, what they do; nothing to buy. TODAY is the morning's card again:
  each offer (`offer_<k>`: name and level, kind in the rarity's colour, the text with a
  risk perk's cost; BUY `buy_offer_<k>`, FREE `offer_free_<k>` with a CHEAT SHEET),
  then REROLL (`reroll_offers`) and SKIP FOR AN ITEM (`skip_offers`, only while nothing
  was bought), then the day's item shelf (`buy_<item id>`, NEW SHELF `reroll_shelf`).
  ITEMS is what is held, with USE. The per-branch tree is gone; so are the branch and
  perk selection of the old page.
- **The offers last the day** (G: "当天有效，钱够随时买"). `close_offers(take_item := false)`
  only puts the card away; with `take_item` and nothing bought (`can_skip_offers()`)
  the round is given up for an item and the offers go. `buy_offer` and `reroll_offers`
  ask for offers, not for the card (`offers_open` is only "the morning's card is up"
  now); `_new_day` deals anew. The morning card gained LATER (chrome), shown only while
  SKIP is the other way out: once something is bought, DONE does the same thing. The
  sim's bots call `close_offers(true)`, so a bot that bought nothing still gets its
  item and the numbers did not move.
- **Form tags** (G, section 6): `FormDef.tags`, translation keys from the form's json
  (`"tags": [...]`), out of `FormDef.TAGS` (JACKPOT FORM, ALL OR NOTHING, SMALL PRIZES
  FORM, MIDDLE PRIZES FORM, BY GROUP). `PackLoader` rejects a non-list, an unknown tag,
  and BY GROUP on a form that does not win by group (`win_display` other than
  `each_group`), so the tag cannot lie. Big Catch is a jackpot form, Ka-Bawk! all or
  nothing, Hot Plate and Nugget Rush small prizes by group, Lucky Spur middle prizes by
  group; Pecking Order, One Flock and Peckeye have none until their signature rules (M9.6's
  second layer). They show on the LCD's third line after the column's name and price,
  joined by " · ", in the run only; nowhere else yet (the codex is M13).
- **PICKY**: with NEW BOX armed, a column press puts up "WHICH TICKET GOES IN?" (a key
  per form the layer sells, `pick_<form id>`, rows of four, `pick_back`); the fee is
  checked first, the box changes with the form and the machine view is rebuilt.
- **SEAL**: the PAY key, when SEAL is held and more columns have tickets left than it
  keeps, puts up "WHICH BOX COMES ALONG?" (`seal_<machine column>`: COLUMN n · FORM ·
  k LEFT, `seal_back`), one box a card until the perk's count is chosen, then pays.
  `RunState.pay(e, m, keep)` seals the columns in `keep` first, the hottest for the
  rest (an empty `keep` is the old rule); `seal_choices(m)` lists the columns.
- **MOONLIGHTING**: the SHIFT DONE card has TO THE MACHINE (`machine`, greyed when the
  cap is used up). The machine sells with the cap on (`_moonlight`, `_selling()`; the
  card's keys now `run.apply` the machine after the day is chosen, so the cap comes on
  with the shift and goes with the next day of play), the LCD says NOTHING MORE TODAY
  at the cap, and the tickets wait in the tray: `_take_ticket` refuses to deal and QUICK
  HANDS refuses to open while `not run.can_open()` ("OPEN THEM TOMORROW"), and the
  machine does not walk back to the table after a sale. LEAVE goes back to the SHIFT
  DONE card. The visit is not saved: a reload puts the SHIFT DONE card up again.
- **HOUSE ACCOUNT**: the LCD's first line is "$ x CREDIT · TAB $y" while the tab holds
  something (the tab alone when the credit is 0); the LEAVE card says ON THE TAB and
  that it is settled when you leave.

## Milestone 9.5, step 5: the simulator and the exploit checks
The plan is `docs/roadmap.md` (the clear-rate targets and M9.5 task 5) and
`docs/perk_research.md` section 5 (parts 3, 8 and 11); this is how it landed.
- **The bots** (`RunSim.BOTS`): `mixed` became `gamble` (plays by default, works only
  when its cash is under `GAMBLE_DAY`, 25 tickets at the machine's cheapest price, or
  when it can pay the layer). The build bots are one table, `RunSim.LINES`: per bot the
  dealt perks it takes (in order of preference), the shelf perks it buys (every level,
  while each costs at most `share` of the cash, 60%; SAVINGS only on the work line's
  checkpoints), and the forms (`FormDef.id`) its column is picked among when the machine
  sells one. `build` is the generic one (any line's engines, QUICK HANDS); `clearing`
  (CLOSER, FIRST PULL, ASSEMBLY LINE, SNOWBALL; REGULAR), `jackpot` (BIG FISH, DUE A WIN,
  JACKPOT HUNTER; REGULAR then READ THE FLARE: the line has no CLOSER, and REGULAR is
  the other way to open READ THE FLARE, which JACKPOT HUNTER needs; Big Catch and
  Ka-Bawk!), `small` (PENNY JAR, STACKER, SCRAP DEALER, TRASH KING; Hot Plate and Nugget
  Rush), `batch` (CHAIN, ENCORE, ALL IN; QUICK HANDS and HIGH ROLLER), `money` (NET
  WORTH, MIDDLE CUT; SAVINGS; Lucky Spur). A bot with HIGH ROLLER bets as the perks bot
  does (the most it can while it holds a hundred tickets), one with ALL IN buys a column
  out once a day of play when the money is there. `churn` buys FIRST PULL and REGULAR
  whenever it can pay for them, and at the machine buys 20 tickets of a column, then
  NEW BOX (cashing out the credit for the fee if needed), again and again.
- **`summary()`** adds `layer_rates` (of the runs that reached a layer, the share that
  paid it; the three multiply to `cleared`), `return_fees` (prizes over tickets and NEW
  BOX fees), `fees`, and `best`: the 50th / 90th / 99th percentile (nearest rank,
  `percentiles()`) of each run's `stats.best_prize`, in dollars. `best_prize` is set by
  `pay_ticket` on every winning path (one at a time, a batch, ALL IN all go through it),
  and now by `cleared_box` for the last-sale prize too.
- **`tools/sim_runs`** defaults to 300 runs a bot and prints, per bot: cleared overall,
  layers 1 / 2 / 3 conditional, days, tickets, return, return with fees, perks, the three
  percentiles, then the roadmap's target where there is one, whether it is met (build
  20 to 30%; gamble and perks within 5 points; borrow, blind and skip under theirs) and
  whether the bot keeps its place against the next one down in build > gamble > perks >
  borrow >= blind ~ skip (blind and skip within 3 points count as equal), and a line
  saying whether the ordering holds. Then the return-per-dollar table (`EV_SETS`, now
  with each line's full set, the daily small-prizes combo, the "astronomical" one with
  `snow` set to 10 boxes cleared, FLARE ONLY 2 + BIG FISH 2; ALL IN and NET WORTH do
  nothing in `box_return`, so the batch and money lines are shown without them;
  `box_return` plays at the top bet now), each form alone with and without DUE A WIN 2,
  the churn exploit at fixed perks (`RunSim.churn_return`, `CHURN_SETS`,
  `--churn-boxes=`), and the forms' table as before.
- **Plugged: FIRST PULL x REGULAR.** While FIRST PULL is held, `change_fee()` is at least
  its multiplier x `Catalog.FIRST_TICKETS` x the layer's stake x `bet_max()`; REGULAR's
  cut comes first. The brief said the stake; the top bet is in too, because FIRST PULL
  multiplies the bet as well and a bet raised after the change would dodge a floor at
  the bet of the moment (without HIGH ROLLER it is the same number: $100 at FIRST PULL
  2 and stake 1).
- **Checked, already plugged**: LOAN SHARK 2 on LOW RATE 2 is still 15% a day, and
  BORROWED LUCK at a full line pays +100% / +200% only while owed (`test_perks`).
  Borrowing the whole line on day 1 and buying SAVINGS up to 3 as soon as the cash is
  there does not clear the first layer at 15% a day (`test_run`: $972 in cash on the last
  day against $1,487 due, $351 of it the loan).
- **Not plugged by rule**: SEAL x HIGH ROLLER x SNOWBALL is what the 99th percentile
  measures; DUE A WIN on Ka-Bawk! is printed per form (below).
- **One 300-run pass** (seeds SIM-0 .. SIM-299; overall, then layers 1 / 2 / 3
  conditional; best prize p50 / p90 / p99 in dollars):
  build 1.0% (45 / 10 / 23; 150 / 575 / 3,000), gamble 12.0% (47 / 52 / 49; 250 / 4,000 /
  10,500), perks 2.7% (51 / 16 / 33; 150 / 750 / 5,200), borrow 5.0% (53 / 25 / 39; 400 /
  2,500 / 10,500), blind 0.7% (50 / 12 / 11; 200 / 1,000 / 2,500), skip 0.7% (48 / 10 / 13;
  150 / 1,000 / 2,500); the lines: clearing 0.7% (48 / 18 / 8), jackpot 0.3% (35 / 9 / 11),
  small 3.3% (53 / 25 / 26), batch 0% (41 / 7 / 0), money 0% (38 / 8 / 0); churn 0% (it
  never pays layer 1). The ordering fails at build (under gamble) and perks (under
  borrow): building does not pay yet, as the roadmap expected (the first layer's debt
  and the perk prices are the balance pass's). The churn bot's return is 0.932 on
  tickets and 0.622 with the fees; at fixed FIRST PULL 2 + REGULAR 2 the churn pays 5.02
  on tickets and 0.837 with the $100 fee (REGULAR 2 alone makes the fee $6: without the
  floor the same churn would pay about 5.02 x 20 / 26 = 3.9 a dollar). Per form with DUE A WIN 2 (24 boxes, no perks / pity 2): Big
  Catch 0.97 / 2.03, Hot Plate 1.13 / 1.35, Lucky Spur 1.15 / 2.44, Pecking Order 1.05 /
  1.68, Ka-Bawk! 1.15 / 3.02, One Flock 0.94 / 1.60, Nugget Rush 0.94 / 1.07, Peckeye
  1.06 / 1.59: the long losing streaks of Ka-Bawk! make DUE A WIN worth three times the
  ticket there, three times what it is on the small-prize forms.
- **Read with care**: `box_return` plays every box in one layer, so the effects that
  grow with the layer or the run (SNOWBALL, TRASH KING, JACKPOT HUNTER) grow over all 48
  boxes: the clearing set's 33.1, the small set's 41.3 and the hunter set's 3.2 are
  that, not what a layer of play gives.

## Milestone 9.5, steps 6 and 7: the fixed bet, the wage cut, DOUBLE UP and STREAK on the window, the panel
The plan is `docs/roadmap.md` (M9.5 tasks 6 and 7) and `docs/perk_research.md` section 5
(parts 2, 3, 5 and 14, G's decisions after step 5); this is how it landed.
- **HIGH ROLLER is the bet.** `RunState.bet()` is HIGH ROLLER's value at the level bought
  (1 without it); the `bet` field, `bet_max()`, `bets()`, the BET key (`Game.cycle_bet`,
  the HUD's key and `run_key("bet")`, the change state's `bet`) are gone. `apply()` puts it
  on the machine as before; a tray entry keeps the bet it was bought at. The perk carries
  `fixed: true` and the shelf card says CANNOT BE UNDONE under what it does (through
  `_perk_state`, for any perk with the flag). Its text is now "BET X%d: PRICE AND PRIZES"
  (it said "up to"). The save no longer writes `bet`; an old save's `bet` is ignored.
  FIRST PULL's floor on the NEW BOX fee is `... x stake() x bet()`: the same number as
  with `bet_max()`, and now there is only the one bet to dodge it with.
- **MOONLIGHTING cuts the wage.** The effect is `wage_cut` (percent): 30 / 15 at levels 1 /
  2 (placeholders). `RunState.shift_wage()` is `wage()` less the cut, on every day of work
  while the perk is held (G), tickets bought or not; `work()`, `last_wage()` and OVERTIME's
  pay on a day already worked all use it (OVERTIME doubles what is paid). `wage()` stays
  the stage's wage: `RunConfig` and the work line never hold the perk. The sale cap is
  gone everywhere (`RunState.sale_cap()`, `MachineLogic.sale_cap` / `may_sell()`, the
  `"no_more"` return, NOTHING MORE TODAY on the LCD); after the shift the machine sells as
  on a day of play and opening is still refused (`can_open()`). The day's card says WAGE
  TODAY after the cut; SHIFT DONE says the wage paid and, under it, "MOONLIGHTING: THE
  WAGE -n%"; TO THE MACHINE is never greyed. `day_tickets` stays (STAKEOUT's).
- **ALL IN is gone**: the perk, `all_in` effect, `can_all_in` / `all_in` / `all_in_used` /
  `stats.all_ins`, the key, `_all_in_at`, the HUD button, drive_run's checks, `test_all_in`,
  its three locale rows. `Economy.spend` stays (a test uses it).
- **The window** (`Catalog.WINDOW` = 10, G): every ticket paid through `pay_ticket` (by
  hand, in a batch, the simulator's) counts in it: `window_n`, `window_printed` (the
  sum of `t.prize`, before the bet and every perk), `window_paid` (what it paid into the
  ledger, SCRAP DEALER's give-back included) and `window_wins` (tickets paid as a prize:
  a WHITE-OUT's loser counts, a FLARE ONLY zeroed one does not). The tenth closes it
  (`_close_window`): STREAK, then a pending DOUBLE UP, then `last_window = {printed,
  paid}` and the counters start over. A batch closes windows as it goes, so a batch of
  20 from an empty window closes two, and the STREAK a window earns already counts on the
  tickets after it in the same batch. `reset_window()` (every morning, the panel) clears
  the window, the last one, the streak and a pending push. All of it is saved;
  `from_dict` starts a window that does not add up afresh.
- **STREAK** (`streak`, rare, batch line, build): `streak_pct` 25 / 40 a window with
  `extra: {"streak_cap": 100}` / 160. A closed window with a winner adds one to `streak`,
  one without sets it to 0; while the perk is not held windows are not counted (buying it
  starts from 0). `prize_pct` adds `streak_pct()` = `mini(streak_cap, streak_pct x
  streak)`. Its text is a level `desc` each ("EVERY 10 OPENED WITH A WINNER: PRIZES +25%
  MORE, UP TO +100%"), as QUICK HANDS does, so the cap shows.
- **DOUBLE UP** (`doubleup`, legendary, batch line, requires CHAIN 1, $2000, effect
  `double_up`). `can_push(e)`: the perk, nothing pending, nothing opened since a window
  closed (`window_n == 0`), that window paid something (`push_offer()`, its pay) and the
  cash covers it. `push(e)` takes the stake out of cash (`e.pay`, `stats.staked`) and
  keeps `push_stake` and `push_printed` (that window's printed sum). The next window's
  close settles it: printed sum greater than `push_printed` pays `e.bonus(stake x 3)`
  (`stats.push_won`, and `best_prize` if bigger), as much or less loses the stake
  (`stats.push_lost`); then a new push may go on that window. No threshold for a second
  push in a row (G). Printed, never paid, so HIGH ROLLER or FAT PRIZES bought between the
  windows do not help (a test buys FAT PRIZES between and still loses).
  - **Decided here: a push pending when the day ends is lost** (`reset_window` counts it in
    `push_lost`). G's rule is that the window never crosses a day; refunding it would let
    a player stake and walk away for free. The LEAVE card says so ("THE STAKE ON DOUBLE UP
    ($n) IS LOST") while one is pending.
  - **Decided here: the card is asked only when an opening ends on a window** (the rule of
    `window_n == 0`). By hand that is every tenth ticket; QUICK HANDS 5 every second
    opening; QUICK HANDS 20 from an empty window every opening. An opening that leaves
    a window half open is not asked even if it closed one on the way (mixing hand and
    batch openings can do that); the brief's "the last window closed" in other words.
- **The game**: `_after_opening` runs after every opening (`_on_revealed` by hand,
  `open_many`): it says a push settled (DOUBLE UP WON $n with the win sound and flash, or
  DOUBLE UP LOST $n), updates the HUD's cash, and when `can_push` puts up the DOUBLE UP?
  card (`_pushing`, the PICKY / SEAL pattern): STAKE $n, what the next ten must print,
  what comes back, the cash; PUSH IT (`push`) and KEEP IT (`keep`). Pushing says STAKED
  $n. Chinese: 押一把 / 连庄 / 押上 / 不押 / 押金.
- **The simulator**: the bots buy a level of HIGH ROLLER (where their shelf list has it:
  the batch line) only while the cash left after paying for it holds `HIGH_ROLLER_CASH`
  (25) tickets of the machine's cheapest form at the new bet (`_rolls`); `_bet` is gone.
  The perks bot never had HIGH ROLLER (it buys dealt offers only, and the perk is on the
  shelf), so its `_bet` call was dead and nothing replaces it. The batch line takes
  CHAIN, ENCORE, STREAK, DOUBLE UP and pushes after every opening that can, while the
  stake is under half its cash; with DOUBLE UP it buys `PUSH_BUY` (20) tickets at a time
  instead of 25 so its openings end on a window. `box_return` stakes every window it can
  (the stake counted as spent, the x3 as won) and takes a `"form"` key in the perk
  levels to play one form alone. `RunSim.push_odds(base_forms, boxes)`: per form, boxes
  in the run's model opened in windows of ten one after another, the share of windows
  after one that paid whose printed sum beats it; `tools/sim_runs` prints it
  (`--push-boxes=N`, 100 by default). `EV_SETS`: the batch row is `{multi 2, combo 2,
  again 2, streak 2}`, and one row per line of the combo table (猎大奖, 清盒, 小奖, 保险
  on Ka-Bawk!, 押一把, 连庄, 钱生钱, 封盒, and the two cross rows), each with a comment
  naming it and what box_return cannot see (REEL IN, NET WORTH's cash, SEAL, reading);
  the column is filled after the lead's run.
- **The developer panel** (run section, Chinese labels): 换一批 perk stays; 指定发 perk
  is a field for a perk id and a key (`Game.dev_run("deal", id)`): a dealt perk not at
  its top level goes first in today's offers (a duplicate dropped) and the offers card
  shows (it shows itself only in the morning; later the phone's TODAY page has it); an
  unknown or shelf id only warns in the log. 给确定性道具 (`"sure_items"`) adds one SURE
  THING, REEL IN and QUEUE JUMP past the pockets' room; 开票窗清零 (`"window"`) is
  `reset_window()` (a pending stake counts as lost).
- **drive_run** (not run here): the BET / ALL IN block is now a check that the panel's
  "every perk" left the bet at x10 and no key, then HIGH ROLLER is taken off so the rest
  plays at x1; DOUBLE UP is taken off after the panel's perks (its card would stop the
  drive); the shift's wage check expects MOONLIGHTING 2's 15% cut.
- **The numbers of a 300-run pass after this step** (the lead's, Haiku in three parallel
  runs): the bots are where step 5 left them (build 1.0%, gamble 12.0%, perks 2.3%,
  borrow 5.0%, blind 0.7%, skip 0.7%, small 4.7%, clearing 0.3%, jackpot 0.3%, batch
  and money 0%, churn 0.62 with fees). `push_odds`, no perks: P from 0.01 (Ka-Bawk!) to
  0.28 (Nugget Rush), Hot Plate 0.18; the x3 breaks even at 1/3, so DOUBLE UP loses on
  every form when every window is pushed blind (the 押一把 row returns 1.03, the
  information row 0.61). The balance pass has to retune it (odds by form, or a lower
  bar); a player who pushes only on a PEEK or a reading will do better than these P.
  The combo table's 期望回报 column is filled from the `EV_SETS` rows.
- **G's changes after this step (2026-11-07)**: G renamed DOUBLE UP back to ALL IN (梭哈;
  id `allin`, effect `all_in`; 押上 / 不押 stay). Its card now asks after every window:
  while ALL IN is held `batch_size()` stops at the window's end (OPEN 20 opens ten, the
  card, then ten), `_close_window` sets `window_closed` and the game puts the card up
  when `take_window_closed()` and `can_push` hold (the rule of an opening ending on a
  window above is gone); the simulator's `PUSH_BUY` went with it. Held items on the
  phone say under the card when they can be used (`why`) if USE is greyed or absent,
  and the ITEMS page says how items are used when something is held.

## After M9.5: the smallest prizes, for G's first game
G played a run (2026-11-07): the forms felt hopeless, only Nugget Rush was fine, and the
return must stay where it is. So the money is split into more, smaller prizes: the
smallest prize of each form's run table (`shape.prizes`) went down (Big Catch $25 to $5,
Ka-Bawk! $50 to $5, Hot Plate $10 to $5, Lucky Spur $25 to $2) and Pecking Order, One
Flock and Peckeye got a prize-only shape ($500 / $500 / $100 / $5; their shares wait
for their signature rules). The box's prize money is its type's as before, so every
form pays back the same; a box of ten hundred $1 tickets now holds about fifteen
winners in a hundred (Lucky Spur and Peckeye eighteen, Ka-Bawk! eight, Nugget Rush
thirteen, unchanged) against three to eight before. A side effect: ALL IN's blind P
(a window of ten beating the last) rose from 0.01-0.28 to 0.14-0.34, at the x3
break-even, so its retune may not be needed. The pictures in `docs/m9.6/` still show
the old smallest prizes. Box size was not touched: a smaller box cannot hold the
$1,000 top at $1 a ticket (roadmap M9.7 has the two ways out). G's list after this
game is `docs/roadmap.md` M9.7.

## M9.7, item 6: one-click open and winners to the table
Two settings on the menu, under TICKETS BACK SIDE UP and wired the same way (SaveFile
`SETTINGS`, `Save.setting`, a menu signal, `Game.toggle_*` pushing the value into
`flow`). Both are off by default, kept in the save (a file from before them reads with
both off; no new save version, since missing settings are filled from the defaults), and
work in free play and the run; the preview tools (`use_save` off) keep both off.
- **ONE-CLICK OPEN** (一键开票; setting `one_click`): one click on the table, or Space,
  opens the whole ticket (`TicketFlow.open_all`): the band breaks (Lucky Spur, one of its
  ways at random, as Space breaks it), a ticket front up turns over (the usual flip), and
  then every flap still closed tears open by itself the way Space opens one flap, all at
  once. Only the first flap's rip is heard, so a five-column ticket does not play five
  rips on top of each other; the paper flecks still fly from every flap. No new reveal:
  the flaps settle, `_reveal` runs and `revealed` pays through `Game._on_revealed` exactly
  as by hand (run hooks, ALL IN's window, the win sound and confetti). A ticket dealt back
  side up skips the flip; one already partly torn opens the rest. While it is on, a click
  anywhere on the table opens a ticket lying back up (before, a click off the paper did
  nothing there). It takes hold at once. Tickets cannot be dragged open while it is on.
- **WINNERS TO THE TABLE** (奖票自动放桌上; setting `auto_wins`): a winner (a printed prize,
  the same test that picks the winners' pile on a click), once revealed, lies in hand for
  `TicketFlow.WIN_SHOW_TIME` (1.2 s, new: there was no delay of this kind to reuse) so the
  prize is seen, then goes to the winners' pile by `collect()`, exactly as a click sends it,
  and the next ticket is dealt. It waits while the menu, the phone or a run card (ALL IN's,
  say) is over the table, and goes as soon as it is closed. A click before the time is up
  still sends it at once. Losers are unchanged: they stay in hand until clicked, as winners
  did before (a click sends any opened ticket to its pile; nothing is dragged), since the
  setting names winners. Letting losers go too would be one condition in `TicketFlow._process`.
- **Tests**: `tests/test_one_click.gd` runs `TicketFlow` on a real `TicketView` of each of
  the eight core forms (flaps and band from the layout, nothing painted), front up and back
  up, winner and loser: one click opens it with no more input and reveals once, paying and
  counting what opening by hand with Space pays; with the setting off a click does what it
  did. A winner goes to the winners' pile after the pause, a loser stays, and a card over the
  table holds the winner. `tests/test_save.gd` round-trips both settings.

## M9.7, item 5: the item tray on the table
G chose code shapes per room, like the room props. A small tray of the room's own lies
on the table in the run (`ItemTray`, built with its own `RoomKit` and no per-mesh
colliders: one click box around the whole tray, lid included, with meta `items`):
- **Diner**: a tin serving tray with a paper napkin in it, its front rim bent in on the
  right where it took a knock. **Bar**: a cigar box, red paper lining, the lid up past
  upright with its cream and red label facing the player. **Bingo hall**: a light blue
  plastic organiser, two compartments for the items and a third holding a red dauber
  standing and a green one lying down.
- **Where**: the near left, mirroring the trash can (`Game.ITEM_TRAY_AT`, x a share of
  the tray's offset as for the winners' pile, turned 0.3 toward the player): in front of
  the discard pile, left of the notepad, below the held ticket, so it never sits under
  the ticket in hand and clicks on the ticket still reach the paper. The same spot in all
  three rooms; `tests/test_item_tray.gd` checks it clears every room's props on a wide
  and a 4:3 window. A full discard pile can reach its back edge.
- **Tokens**: one per item held (the catalogue's order), up to eight; past that the rest
  are implied. A shape per kind (INFO a card with an ink line, ECONOMY a coin, ACTION a
  block, SURE a gem) in the phone's rarity colour (cream, blue, gold). Laid again only
  when what is held changes.
- **Free play** has no items and the phone has no SHOP there, so the tray is put away
  (hidden, its click box off). In the run it shows even when empty.
- **The picker** (`ItemPicker`, the run card's plate and LCD look): clicking the tray at
  the table opens it. It shows the very rows of the phone's ITEMS page: `Game.items_state`
  (taken out of `phone_state`, which now merges it in) builds them for both, so USE is lit
  or grey by the same `_can_use` and the same reason (`_use_why`) shows under a grey or
  missing USE. USE on either goes through `Game.use_item` (taken out of `_on_phone`), so an
  item does the same from both; a column item (or TIP-OFF) puts the phone and the picker
  away, the others leave the picker up with the new numbers, as the phone stays up.
  BACK, Esc or a click beside the plate closes it. While it is up nothing reaches the
  table or the machine, and a revealed winner waits (`_may_auto_collect`), as for the
  phone and the run card. With nothing held it says so and points at the phone's shop
  (one new line in `locale/ui.csv`, no new Chinese characters). The phone's ITEMS page
  stays as it was.
- Since the tray is at the table and column items are used at the machine
  (`_can_use`: `at_machine`), their USE is always grey on the picker, with the phone's
  reason under it. Only RETURN SLIP, HAPPY HOUR, SAFETY NET, OVERTIME and COPIER can be
  used from the tray. If G wants the tray to start a column item, USE there could take the
  player to the machine with the item aimed; that would change the rule, so it is not done.

## M9.7 item 3: the line that wins more often
G picked three of section 15's five (`docs/perk_research.md`): CONSOLATION, PACKED and
CRUMBS, in a new build line `often` (WIN MORE OFTEN, 多中). All three act as the ticket
leaves the box (`MachineLogic._take`, after the sure win and MAGNET), decided from the
seed and logged in the box's `ops` (`{"w"}`, `{"c"}`, `{"p"}`; `TicketBox.replay` does
them again), so the ticket really is a winner: its face, STREAK's window, ALL IN's
printed sum and the win pile all see it. `TicketBox.counts` follow, so reading the box
stays true.
- **CONSOLATION** (安慰奖, common, $100 / $300, effect `consolation`): a loser wins the
  smallest prize `Catalog.CONSOLATION` = 5 / 10 times in a hundred (rolled from the seed
  and the place). **Decided here: half of section 15's 10 / 20.** Those were for $25
  smallest prizes; at $5 on a $1 ticket they would add 40 to 85% to the return. At 5 /
  10 it is about +20 / +40% (FAT PRIZES' range) and winners go from about 15 in 100 to 19
  / 23. New money: the box's prize total grows by it.
- **PACKED** (多装点, rare, $200 / $500, effect `packed`): a box that goes on the machine
  while it is held (the machine's `packed`, also given to `MachineLogic.new` so a
  layer's first boxes count; boxes already on the machine stay as they were, the card
  says FROM NOW ON) breaks middle prizes into smallest ones: up to +25 / +50% smallest
  prizes, rounded to whole middle prizes, the money the same to the coin.
  **Decided here: middle prizes only** (`TicketBox.PACK_ROLES`), G's "钱从中奖那份匀";
  top prizes stay. Since the smallest prizes came down most of a box's money is in them
  already, so it lands where middle prizes are: Lucky Spur the full +25 / +50%, Nugget
  Rush +19 / +21%, Pecking Order +15%, Hot Plate, Big Catch and Ka-Bawk! almost nothing
  (60 boxes each). With tops too it was Hot Plate +7%, Big Catch +1 / +5%, and a Hot
  Plate box could lose its only top. The card says UP TO.
- **CRUMBS** (碎奖, rare, $250 / $600, effect `crumbs`): a winner taken splits over the
  next 1 / 2 losers still in its box, each the smallest prize; the ticket keeps the rest
  (`cut` on the ticket, `cut_total` on the box), only while it keeps at least the
  smallest prize, fewer pieces when fewer losers are left, and a piece never splits.
  **Decided here: the pieces are the smallest prize and the ticket prints what it kept**
  ($100 becomes $95, a $95 under the boot). The brief wanted every piece a table prize
  and the total exact; with tables like $1000 / $100 / $5 no two prizes add up to a
  third, so the kept amount cannot be one. `RunState.pay_ticket` takes the cut off the
  best tier's prize (before the role's x); `TicketArt.interior` prints it on the group
  of that tier for a form that wins by group. It adds few winners now (only middle and
  top prizes split, and there are few): Lucky Spur +1.5 / +3%, the others under 1%.
- **The simulator**: the small line takes CONSOLATION, PACKED and CRUMBS after PENNY
  JAR and STACKER (CRUMBS after SCRAP DEALER), the batch line CRUMBS (for CHAIN);
  `EV_SETS` has a row for each and three combos. Not run here.
- **Tests** (`test_perks`): the share of losers turned against 5 / 10% within a point,
  their prize and the box's counts; PACKED's money and tops unchanged, the count up to
  the share (the full share on Lucky Spur), boxes already on the machine untouched;
  CRUMBS's total paid per box unchanged, pieces on the next losers, edges (fewer losers,
  no second split); all three the same from a seed and replayed from the log.

## M9.7, items 5 and 6 after G's look: tokens used by a click, losers away too
- **A token is its item's USE** (G: no USE key needed). Each token in the item tray has
  a click box of its own (meta `item`, the item's id); the tray's own box now stops at
  its floor (the bar's lid has one of its own), so a click on a token reaches the token
  and a click on a rim goes on down to the tray, which still opens the picker for
  reading. `Game.use_token` uses the item through `use_item`, as the phone and the
  picker do. **A column item** (PEEK, LUCKY COIN and the rest) takes the player to the
  machine the way clicking the machine does (`TableNav`: a ticket untouched goes back to
  the tray, an opened one to its pile first) and aims it there (`aim`, the phone's), so
  the next column press is it and PLAY ALL lets it go. Column items still act at the
  machine; only the token walks the player there. The phone and the picker keep USE grey
  for them at the table, as before. **Decided here**: a ticket half torn in hand keeps
  the player at the table, so the token says ALREADY TORN (as putting it back does; no
  new line); while a ticket is moving it does nothing. TIP-OFF, a NOW item used at the
  machine, stays grey at the table and does not walk there.
- **What a token cannot do it says**: on the status line under the cash, the phone's
  reason (`_use_why`; COPIER its rule, the card's text). Nothing else changes.
- **The tip**: pointing at a token shows a small plate beside the pointer (`Hud.set_tip`):
  the item's name, what it does, and the reason when it cannot be used now. It goes when
  the pointer leaves the token, at the machine and under any card or the menu. The
  other props keep only the pointing hand.
- **TICKETS AWAY BY THEMSELVES** (开完自动收票; the save key stays `auto_wins`, which saves
  already have): a loser now goes to the discard pile by itself too, after
  `TicketFlow.LOSE_SHOW_TIME` (0.5 s); a winner after `WIN_SHOW_TIME` (1.2 s) as before. A
  click sends either at once; both wait while the menu, a run card, the phone or the
  picker is up. The new label fits the menu as it is (the key's text 262 px of the 364 px
  it gets; the menu stays 400 wide). No new Chinese characters, so the fonts are as they were.
- **Tests**: `test_item_tray` (a click box per token with its id, rays onto a token and onto
  the floor, a NOW token against the phone's USE, PEEK's token to the machine aimed, tokens
  that cannot be used changing nothing and saying why, the tip); `test_one_click` (a loser
  goes after LOSE_SHOW_TIME with the setting on, stays with it off, waits for a card).
  `tools/drive_run.gd` clicks the tray's floor for the picker, then points at LUCKY COIN's
  token and clicks it (not run here: it opens a window).

## M9.7 item 4, and the batch line and the line that wins more often after G's look
G's decisions after item 3 (2026-11-07); the plan is `docs/roadmap.md` M9.7 items 3 and 4.
- **ALL IN wins about half the time on every form, the x3 kept.** The next window wins
  when its printed prizes reach a share of the staked window's printed prizes (more than
  $0 always). The share is per form, `Catalog.ALL_IN_SHARE` (form uid -> percent) with
  `ALL_IN_DEFAULT` 75 for a form without a row. **Decided here: in the catalog, not the
  form's json**: it is the perk's balance, found by the simulator, kept beside the other
  perk numbers (CONSOLATION); the json holds the form's own odds. Each ticket of the
  staked window counts at its own form's share (`window_bar`, the sum of prize x
  percent; `Catalog.all_in_bar` rounds it up to dollars, $1 at least), so a window of
  two forms has a fair bar. `last_window` carries `bar`; a push keeps it as `push_need`;
  `RunState.push_target()` is what the card shows. Both are saved; a run saved before
  gets the old rule (more than the window). Blind P (`RunSim.push_odds`, 200 boxes):
  Big Catch 100% 0.53, Hot Plate 100% 0.50, Lucky Spur 100% 0.52, Pecking Order 75%
  0.50, Ka-Bawk! 50% 0.54, One Flock 75% 0.50, Nugget Rush 70% 0.49, Peckeye 100% 0.54.
  Windows print in steps of the smallest prize, so P jumps between bars (at 100% "as
  much" already wins; at 101% P falls to 0.15-0.34; Ka-Bawk! is 0.44 at 55%, 0.54 at
  50%). With P near 0.5 and x3 a push is worth 1.5 stakes: G's call. The card in
  game.gd still says "MORE THAN" the window's printed sum: it is the main session's to
  wire (`push_target()`, "AT LEAST").
- **QUICK HANDS, CHAIN and ENCORE wait for the shop outside the run (M13).** They carry
  `"meta": true`: `Catalog.perks_of` and `dealt()` skip them (so the shelf, the deal and
  the phone's lists), `RunState.can_buy_perk` refuses them, and a saved offer of one is
  dropped. Their effects and code are untouched, so a save or the developer panel's
  "every perk" (which sets every non-risk perk, these too) still opens in batches; M13
  turns them back on. `Catalog.problems` reports a perk of the run that needs a meta one.
  ALL IN needs STREAK 1 instead of CHAIN 1.
- **The simulator**: the `batch` bot stays, as the window line (STREAK, ALL IN, MAGNET,
  CRUMBS, CONSOLATION, HIGH ROLLER), opening one ticket at a time; `build` takes STREAK
  where it took CHAIN and ENCORE, and no shelf perk. `EV_SETS` rows holding QUICK HANDS,
  CHAIN or ENCORE stay as "what if" rows marked M13, each beside a row without them; the
  押一把 rows take STREAK 1. `push_odds` takes a `shares` override and prints the share.
- **CRUMBS** (5 / 20): a prize bigger than the smallest breaks over up to 5 / 20 of the
  next losers in its box, each the smallest prize; the ticket keeps the rest, the smallest
  at least. It was 1 / 2 pieces; `crumble` already had this rule, only the levels and
  text changed. Winners per 100 (60 boxes, none / 1 / 2): Big Catch 14.3 / 14.4 / 14.9,
  Hot Plate 16.3 / 16.4 / 16.8, Lucky Spur 19.0 / 20.2 / 24.0, Pecking Order 14.2 /
  14.9 / 16.6, Ka-Bawk! 8.5 / 9.2 / 10.9, One Flock 13.7 / 14.4 / 16.1, Nugget Rush
  12.4 / 14.3 / 16.3, Peckeye 16.4 / 17.0 / 18.7. Big Catch and Hot Plate hold one or two
  prizes over the smallest a box, so it stays small there.
- **PACKED** (25 / 50%): of the prizes bigger than the smallest a box holds when it goes
  on the machine (tops and middles, every prize on a ticket), that share is broken into
  smallest prizes, each picked from the seed, its ticket keeping one and losers picked
  from the seed taking the rest; same money to the coin. **Decided here: the fraction of
  a prize is rolled from the seed** (rounding sent Big Catch's one big prize to 0% at
  level 1 and 100% at level 2). Winners per 100 (none / 1 / 2): Big Catch 14.3 / 14.9 /
  17.0, Hot Plate 16.3 / 16.6 / 16.8, Lucky Spur 19.0 / 25.6 / 31.5, Pecking Order 14.2
  / 15.1 / 15.9, Ka-Bawk! 8.5 / 11.9 / 14.5, One Flock 13.7 / 14.5 / 15.3, Nugget Rush
  12.4 / 13.4 / 14.4, Peckeye 16.4 / 17.1 / 18.1. `TicketBox.PACK_ROLES` is gone.
- **Stacking** (`box_return`, 6 boxes a form): PENNY JAR 2 alone 2.53; with PACKED 2 it
  was 2.87 (+0.34, over the 0.25 line), so **the smallest prizes PACKED makes are not
  small prizes to PENNY JAR nor prizes to STACKER**: `pack` counts them on the ticket
  (`packed`), `pay_ticket` pays them as printed and leaves them out of STACKER's count.
  After: PACKED 2 + PENNY JAR 2 2.53 (+0.00); PENNY JAR 2 + STREAK 2 5.04, with PACKED 2
  5.43; STREAK 2 2.07, with PACKED 2 2.23; CRUMBS 2 + PENNY JAR 2 2.75 (+0.22, under the
  line, left as it is: its pieces do take PENNY JAR); PACKED or CRUMBS alone 1.047 (no
  perks 1.047). The card says NOT FOR PENNY JAR OR STACKER. Rarity and prices unchanged.
- **Text**: ALL IN's, PACKED's and CRUMBS's descriptions in both languages (CRUMBS has one
  text now, with the count); one new character (半), so the CJK fonts were cut again.
- **Tests**: `test_run_sim` checks every form's blind P within 0.45-0.55 (40 boxes on
  other seeds; 60 with `--full`) and that the old bar was under 0.4; `test_perks` the bar
  by form and for mixed and empty windows, the three parked perks never shelved, dealt
  or sold (every layer, 30 rerolls) and still working when held, the save of the new
  window fields, CRUMBS on all eight forms at 5 / 20, PACKED's share per box and in all,
  its money, determinism and replay, and its pieces passed over by PENNY JAR and STACKER.
