# Data packs

Built-in ticket forms load through the same pack format that Steam Workshop items will use.
A pack is a folder of **data only**: a manifest plus JSON, images and audio.

- Allowed file types: `json png jpg jpeg webp wav ogg mp3 txt md`. A pack holding any other file
  (scripts, scenes, `.tres`, binaries…) is rejected as a whole.
- Pack files are read as raw bytes (`Image.load_from_file`, `AudioStreamWAV.load_from_file`, …).
  Nothing in a pack goes through `load()`, so a pack can never bring code in.
- Every path in a pack is relative to the pack folder and must stay inside it (no `..`).
- `packs/.gdignore` keeps the Godot editor from importing pack files; the game reads them the way it
  reads a Workshop pack.

Where packs come from (`Platform.pack_dirs()`): `res://packs/core`, then each folder in
`user://packs/`, then whatever a store backend adds (Workshop folders, later).

## `pack.json` (format 1)

| Field | Required | Meaning |
|---|---|---|
| `format` | yes | `1` |
| `id` | yes | `a-z 0-9 _`, unique across packs |
| `version` | yes | free text |
| `name` | yes | text, or `{"en": "...", "zh": "..."}` (English required) |
| `author` | no | free text |
| `forms` | yes | list of form files |
| `tear_sounds` | no | `{"marks": "<json>", "clips": ["<wav/ogg>", ...]}`; marks file maps clip file name → rising crackle start times in seconds |

## Form file

| Field | Meaning |
|---|---|
| `id` | `a-z 0-9 _`, unique in the pack. Box seeds use `"<seed>|<id>"`. |
| `name`, `title`, `code`, `price` | printed copy; `title` is 1–3 words; `price` in whole dollars |
| `colors` | `edge`, `head`, `ink` and one `tiles` colour per tier, as `#rrggbb` |
| `tiers` | 3–8 entries: `key`, `label` (text or localized), `prize`, `printed_count` (decoration only), `role` and optional `symbol` image |
| `digit_groups` | loser digit group lengths, 2–6 each; shuffled per ticket |
| `win_display` | `whole` (the win replaces the inside) or `one_group` (the win shows in one group) |
| `layout` | presentation; `{"preset": "single" \| "windows" \| "jar"}` for now (see below) |
| `tear_sounds` | optional, same shape as in `pack.json`; overrides the pack's rips for this form |

Tier roles drive the box generator: one or more `top` tiers with the same prize, exactly one `mid`
and exactly one `low`, every prize a whole multiple of the `low` prize.

## Layout

Layouts must be customizable by packs. The planned format (designed in milestone 2, built out in
milestone 3) describes the card size, the printed face as layers (rects, images, text with bindings
such as the serial or a tier's printed count), where digit groups and wins print inside, and the
flaps (rectangles, hinge edge, cover art, which flaps may tear as a pair, optional band). The three
presets will then become ordinary layout files in the core pack.
