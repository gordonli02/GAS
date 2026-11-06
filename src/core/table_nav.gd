class_name TableNav
extends RefCounted
## What leaving the table for the machine does to the ticket in hand.
## Rules from MIGRATION.md "Table and machine navigation" and the web build:
## an opened ticket is discarded first (only when the player clicks the machine;
## B and the view button do nothing then, as in the web build), an untouched
## ticket goes back to the tray, a partly torn one (or a banded ticket whose band
## is broken) blocks leaving. Pure logic.

enum Action { GO, RETURN_THEN_GO, DISCARD_THEN_GO, STAY }
## The ticket in hand: none, front up, back up, opened, or moving (deal/flip/toss).
enum Hand { NONE, FRONT, BACK, OPENED, MOVING }


## has_band: the layout has a band; band_on: still on; any_torn: some flap has torn;
## machine_click: the player clicked the machine (rather than B / the view button).
static func leave(hand: Hand, has_band: bool, band_on: bool, any_torn: bool, machine_click: bool) -> Action:
	match hand:
		Hand.NONE:
			return Action.GO
		Hand.OPENED:
			return Action.DISCARD_THEN_GO if machine_click else Action.STAY
		Hand.FRONT:
			if not has_band or band_on:
				return Action.RETURN_THEN_GO
		Hand.BACK:
			# With a band the back is normally reached by breaking it; dealt back side up
			# (the "back first" setting) the band can still be on, and the ticket untouched.
			if (not has_band or band_on) and not any_torn:
				return Action.RETURN_THEN_GO
	return Action.STAY
