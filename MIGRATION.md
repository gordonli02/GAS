# Last Sale: Godot migration brief

## What this is
Last Sale is a relaxing low-poly pull-tab ticket game for Steam. The player feeds bills into a machine, buys tickets and tears them open by hand. There is no real money, no in-app purchase and no way to withdraw value.

The web prototype is finished and approved by the project owner, G. It is the reference for behaviour, feel and look. This project rebuilds it in Godot 4 as the long-term codebase.

Later goals shape the architecture but are not part of this migration:
- a full roguelike mode with deal reading, NPCs and items
- Steam Workshop packs for ticket designs and tables
- Steam Playtest, then a paid release

## Files in this kit
- `reference/last-sale-preview.html`: runnable reference. Open it in Chrome or Edge. It works offline.
- `reference/last-sale-source.html`: readable source of that build, about 100 KB. Recorded audio was removed from it. Read this for exact geometry, colours, ticket art and prop layouts.
- `assets/audio/`: G's own recordings, safe to ship.
  - `tear_01.wav` to `tear_08.wav`: eight real rips
  - `tear_marks.json`: start time in seconds of each crackle in each rip
  - `dispense_loop.wav`, `dispense_stop.wav`, `bill_insert.wav`, `machine_button.wav`
- `assets/fonts/`: Alfa Slab One, Oswald and VT323 under the SIL Open Font License.

`reference/last-sale-source.html` is the authority for anything this brief does not state. If the brief and the running preview disagree, trust the preview and tell G.

## Non-negotiable behaviour

### Money
- Start with $200 cash and $0 machine credit.
- Bills: $5, $10, $20, $50, $100. Cash moves to credit when the bill finishes feeding, about 2.05 s after the click. The bill sound starts 16% into that animation.
- Tickets cost $1 of credit.
- Prizes go straight to cash. They never go back to credit.
- `CASH OUT` returns all credit to cash.
- `LOAN $200` appears only when cash is under $5, credit is under $1, and the player holds no tickets. A loan does not count in NET.
- NET = won minus spent. Spending is recorded at purchase, so unopened tickets count as spent.

### Ticket forms
All three forms print the same prize table: 6 WIN $500, 6 WIN $500, 10 WIN $100, 75 WIN $25.

| Form | Kind | Palette direction | Tiers |
|---|---|---|---|
| Big Catch | Single large flap | Cool blue, cyan, teal, violet | walleye, bobber, boot, worm |
| Hot Plate | Five windows | Red, orange, pink, amber | egg, stack, mug, pie |
| Lucky Spur | Banded, folded 16:10 card | Green, magenta, lime, hot pink | shoe, star, hat, cactus |

Ticket copy must stay exact: `PAYABLE IN EGG MONEY.` and `©Ben Kraptu apt.` The back mark is `BK`.

The printed counts are decoration. A box holds its own real counts, listed in the developer panel.

### Boxes
Each form has its own box. The seed picks a box type first, then prizes are composed to land on that result.

Box size: 900 to 1,100 tickets in steps of 10.

| Type | Chance | Net as share of gross |
|---|---|---|
| 大亏 | 10% | -75% to -55% |
| 中亏 | 15% | -55% to -35% |
| 小亏 | 20% | -35% to -12% |
| 盈亏平衡 | 20% | -6% to +6% |
| 小赚 | 18% | +12% to +35% |
| 中赚 | 12% | +35% to +80% |
| 大赚 | 5% | +80% to +160% |

Composition:
1. `total` = gross × (1 + a random value in the type's range), rounded to the nearest $25.
2. `tops` = floor(total × random 0.10 to 0.40 / 500). Each top prize goes to one of the two $500 tiers at 50/50.
3. `mids` = floor((total - tops × 500) × random 0.10 to 0.25 / 100).
4. `$25` count = whatever is left, divided by 25.
5. Fill the rest with losers and shuffle with Fisher-Yates.

Every ticket has a serial unique in its box: one letter A to Z plus six digits. Losing tickets show digit groups with no group of all-equal digits. Single flap and jar use lengths 4, 4, 3 in random order. Five windows use 4, 3, 4, 3, 4 in random order. Each digit has a spelled-out caption and a small mark digit. Winners on a five-window ticket appear in one random window.

Use a seeded generator so a seed reproduces a box. It does not need to match the JavaScript output bit for bit, but it must pass the same distribution tests.

When a box sells out, the next seed loads and restocks at 18 tickets per second. Sales wait for stock.

### Machine
- Three column buttons, one per form. Keys 1, 2, 3 press the same buttons.
- A column press sells 1 ticket.
- The red round PLAY ALL button arms the machine. The next column press sells min(100, credit) tickets, then disarms. Space toggles PLAY ALL when credit is available.
- Dispense rate is 16.35 tickets per second. `dispense_loop.wav` plays at pitch scale 1.5 while running, and `dispense_stop.wav` plays when it ends.
- Tickets of mixed forms share one tray and open in purchase order.
- The camera returns to the table automatically 0.7 s after dispensing ends if credit is under $1 and tickets are in the tray. With credit left, it stays.
- The machine LCD shows credit and a status line: INSERT BILL, SELECT A TICKET, READING BILL, or a flashing PLAYALL.

### Table and machine navigation
- Fov 42. Table camera at (0, 5.6, 10.5) looking at (0, 2.2, 0), with slight mouse parallax.
- The machine stands on the floor behind and to the right of the table. Positions are in the `scenes` config in the source.
- Clicking the machine from the table swings the camera to it in 0.6 s. As the camera arrives, the machine rotates to face the player squarely.
- In the machine view, clicking anything that is not the machine returns to the table. Clicks must respect occlusion: the front-most object decides.
- `B` toggles the view.
- Leaving for the machine with an opened ticket discards it first. An untouched ticket returns to the tray. A partly torn ticket blocks leaving.
- With an empty tray, the player can stay at the table. Space or clicking the machine goes back to it. Clicking the empty table does nothing.

### Bill window
A separate LCD-style window sits to the right of the machine, at about the height of the machine LCD, with an arrow pointing at the bill slot. It holds the five bills and CASH OUT. It shows only in the machine view.

## Tearing: the core of the game
Sizes in world units: ticket 1.4 × 2.0, thickness 0.016, margin 1.4 × 16 / 420. Jar card 2.12 × 1.325.

### Paper model
A flap is a subdivided plane hinged at x = 0, width `w`, height `h`. For each vertex:

```
open = 1 - f / w
slope = 0.55 * (1 - open^2)
d = y - yGrab
foldX(y) = clamp(f + slope * abs(d) + k * d, 0, w + 0.6)
distance = x - foldX(y)
if distance <= 0: stay flat
else theta = distance / r
  if theta < PI: X = foldX + r sin(theta), Z = r (1 - cos(theta))
  else:          X = foldX - (distance - PI r), Z = 2 r
```

- `r` starts at 0.085 and eases to 0.04 as a flap settles.
- Flat shading on the flap mesh is part of the look.
- The revealed area next to the fold gets a soft dark gradient that follows `foldX`.
- The flap's inner face is dark grey speckled paper.

### Input
- The free edge follows the pointer: target `f = (pointerX + grabOffset + w) / 2`.
- Peeling starts only when the press lands on the ticket. The grabbed height sets `yGrab`, so the tear starts where the player pressed.
- `k` follows vertical drag: `clamp((pointerY - grabY) * 0.45, -0.42, 0.42)`. Dragging up peels from the bottom, dragging down peels from the top.
- Before the first break, the flap resists: `f` stays within 0.05 of closed until the pull passes 0.1, then it pops.
- On release, a flap past 45% open finishes by itself. Otherwise it springs back.
- `f` follows its target with a rate of 30 per second when held and 16 otherwise.
- Auto-finish speed is 2.8 widths per second.
- Space tears the next unopened flap from a random top or bottom corner.

### Sound while tearing
Each flap picks one random rip. Divide progress into 15 steps. As steps pass, map them to crackle indices using `tear_marks.json` and play the audio slice between the two crackle marks with a short fade. Slow hands make slow crackles. Play any remaining slice when the flap auto-finishes. Do not substitute a looping tear sound.

### Three kinds
- **Single flap:** one flap covers the back and hinges on the left.
- **Five windows:** five flaps hinge on the left. Pressing within 0.095 of the boundary between two unopened neighbours tears both together, each peeling from the shared edge. The feature is never explained to the player.
- **Jar:** step one happens on the front: drag `BREAK BAND` sideways past 0.34, or press Space. The ticket cannot flip until then, and an unbanded ticket cannot return to the tray. Step two flips the card. Step three peels one flap upward from the bottom, hinged at the top edge, while the card slides down to keep both halves in view. Loser digits sit in three vertical columns with dashed dividers.

### Ticket timing
Deal 0.42 s, flip 0.24 s, flap settle 0.22 s, toss 0.34 s. Winners pulse the ticket, shake the camera and fire confetti. Used tickets stack on a messy pile, capped at 36 meshes.

## Look
- Clean low-poly, flat shaded, no retro filter.
- Three rooms: Diner, Bar, Bingo Hall. Rebuild every prop from the source, including the breakfast plate, jukebox, flip phone reading TONYMARKET, false-teeth glass and BAIL piggy bank.
- Ticket faces are generated from data at runtime so every ticket can show its own serial.
- UI uses the green LCD language throughout. Player text stays in English for now. Do not show a tutorial or hint text.
- The developer panel is hidden from players. Backquote toggles it in debug builds. It shows box details, switches tables, hands out a free ticket of any form, offers a reset for tickets and money, and has per-sound file replacement and volume.
- Esc or MENU opens the player menu: table choice, master volume, sound toggle, resume.

## Architecture requirements
- Data-driven from day one. Built-in ticket forms load through the same pack format future Workshop items will use: a manifest plus images and audio. Packs contain data only, never scripts.
- Keep the box generator as plain logic with no scene dependencies, so unit tests and a future roguelike mode can call it.
- Keep input, paper simulation, ticket content, machine, economy and audio in separate modules.
- No Steam code during migration, but keep a thin platform layer so GodotSteam can be added later.
- Save settings and session state through one save module with a version number.

## Milestones
Stop after each milestone and tell G what to test.

1. Project setup, audio and fonts imported, generator ported with automated tests.
2. A single ticket on a grey table: the single-flap tear with sound. G approves the feel against the web build before anything else proceeds.
3. Five windows and jar tickets.
4. Machine, economy, tray, discard pile and camera travel.
5. Three rooms.
6. LCD UI, menu, developer panel, save.
7. Windows export and a full playthrough against the checklist below.

## Acceptance checklist
- 5,000 generated boxes per form match the type shares and net ranges, with no duplicate serials in a box and no all-equal loser groups.
- cash + credit = 200 + loans + won - spent, at every step.
- Tear crackles follow hand speed. Five-window pairs work from every boundary.
- A jar ticket cannot flip with its band on.
- Navigation rules above hold with an empty tray, a held ticket, an opened ticket and a partly torn ticket.
- Stable 60 fps on integrated graphics at 1080p.
