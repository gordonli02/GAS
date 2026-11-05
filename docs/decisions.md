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
