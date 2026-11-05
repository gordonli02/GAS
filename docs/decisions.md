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
