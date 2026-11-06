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
  they held; an opened ticket in hand goes on the pile. So no ticket crosses a day or a layer.
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
