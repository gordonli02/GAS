# Acceptance (milestone 7)

The checklist from `MIGRATION.md`, what checks each item, and the last result.
Automated results are from 2026-11-05 on Godot 4.7.2, Windows 10, RTX 4070 Ti.

| Item | Checked by | Result |
|---|---|---|
| 5,000 boxes per form match type shares and net ranges; no duplicate serials; no all-equal loser groups | `tests/test_generator_distribution.gd` with `--full` | Passed (354 s). Shares, e.g. Big Catch: 大亏 0.103, 中亏 0.157, 小亏 0.201, 盈亏平衡 0.184, 小赚 0.174, 中赚 0.127, 大赚 0.054 |
| cash + credit = 200 + loans + won − spent at every step | `test_economy.test_invariant_random_session` (60,000 random steps with `--full`); `drive_game` checks it every frame of a real session | Passed |
| Tear crackles follow hand speed | `test_flap_sim.test_slow_hands_make_slow_crackles`, `test_crackle_steps_cover_the_tear_once`; by ear: G | Passed (tests and G's playthrough) |
| Five-window pairs work from every boundary | `test_multi_flap.test_pairs_from_every_boundary` | Passed |
| A jar ticket cannot flip with its band on | `test_multi_flap.test_jar_cannot_flip_with_band_on` | Passed |
| Navigation with an empty tray, a held, an opened and a partly torn ticket | `test_navigation_and_pile.test_leaving_the_table`; `drive_game` plays each case | Passed |
| Stable 60 fps on integrated graphics at 1080p | `tools/bench_fps.tscn` on the target machine | **Open**: no integrated-graphics machine yet. RTX 4070 Ti: worst scene 0.97 ms mean, 1.86 ms worst-1% (budget 16.7 ms) |

## The exported build
- `drive_game` (85 checks) passes inside the exported verify build, which reads the packs
  next to the executable, the save and the Chinese fonts as a player's copy does.
- The release build starts, saves on closing the window and exits cleanly (5 runs, empty log);
  with its `packs` folder missing it shows a message instead of the game and exits cleanly.

## Run on another machine
Copy the whole `builds/windows` folder (LastSale.exe, `packs/`, `licenses/`). For frame times,
also copy `builds/verify` and run from a command prompt in that folder:

```
LastSaleVerify.console.exe --resolution 1920x1080 -- fps.txt --run-tool=res://tools/bench_fps.tscn
```

It plays the machine, dispensing, a 2,000-ticket pile and tearing in every room with vsync off
and writes mean, worst-1% and GPU frame times to `fps.txt`. Under 16.7 ms worst-1% is 60 fps.

## Manual playthrough (G)
Feel, sound and look are G's call; these are the moments to go through in the release build.
G played the release build through on 2026-11-05 (motor looping the whole recording): no problems.
1. First start: language follows Windows; the game starts at the machine with $200.
2. Bills, a single ticket, PLAY ALL on each column; the motor sound, the camera back to the table.
3. Open every form by hand: single flap, five windows (tear a pair at a boundary), jar (band both
   ways, sideways swipe). Listen to the crackles at slow and fast hands.
4. Leaving the table with an untouched, a partly torn and an opened ticket; empty tray.
5. Cash out, loan up to the limit, a winner (pulse, shake, confetti, LCD flash).
6. Menu: every room, volume, mute, full screen, both languages, quit.
7. Quit mid-tear and start again: the ticket is back in the tray untouched, money and pile as left.
8. A long session (a few hundred tickets): the pile grows by ranges, no slowdown.
