class_name Catalog
extends RefCounted
## What the run (story mode) sells: perks, items and the services of the phone's
## contacts. Plain data, no scene access; what each effect does is RunState's rule
## (the effect hooks), so a new perk or item on an existing effect is data only.
## The tree and the numbers were settled with G in the perk-tree talk (docs/roadmap.md,
## "技能树"); the numbers are still the balance pass's to tune.
##
## Text is translation keys (locale/ui.csv). Prices are at stake 1: the run asks the
## layer's stake times them, so a perk costs as much, in days of work, in every layer.
##
## Perks are not on a shelf: every morning of a run and after every day, the run deals
## a few of them (OFFERS) out of those whose requirements are met, weighted by rarity
## (RunState.deal_offers). They stay for the whole run and go up a level at a time. Each
## level's `value` feeds the perk's `effect`; `show` (when there) is what the text shows
## instead of the value, and a level's own `desc` replaces the perk's.
##
## How a prize is paid (RunState.pay_ticket): the printed prize times the bet, times
## one plus the sum of every "+%" (prize_pct, debt_pct, worth_pct, pity_pct, trash_pct,
## hunter_pct, a HAPPY HOUR), times every "x" (top_x on top prizes, stack_x on a ticket
## with two prizes or more, first_x on a box's first tickets, the snowball, a LUCKY
## COIN, the opening's combo and an ALL IN). An again_pct roll pays it all twice.
##
## Effects (value per level):
##   prize_pct    every prize +%                       (+ slot)
##   scrap_pct    a losing ticket gives back % of what it cost (cents saved up, paid in dollars)
##   top_x        top prizes times this
##   stack_x      a ticket with two prizes or more times this
##   trash_pct    + % per 100 losing tickets opened in the layer   (+ slot)
##   snowball     every box cleared (its last sale) multiplies every prize by
##                1 + value/100 for the rest of the run
##   hunter_pct   + % per top prize opened in the layer   (+ slot)
##   luck         % chance that a losing box loaded into the machine is passed over
##   last_sale_x  the last-sale prize times this
##   first_x      the first FIRST_TICKETS tickets of a box times this
##   pity_pct     + % per losing ticket in a row before this prize   (+ slot)
##   flow_line    a box loaded after one was cleared never loses
##   fortune      LUCKY STREAK keeps passing over (up to FORTUNE_TRIES boxes)
##   batch        tickets opened at once from the tray (OPEN key)
##   combo_pct    in one opening, every winner after the first adds this % to the
##                opening's multiplier (x slot)
##   again_pct    in one opening, % chance that a winner pays again
##   bet          the machine's top bet (price and prizes times it)
##   all_in       once a play day: a column's box bought out and opened at once, prizes
##                times this
##   loan_pct     the house line + % of the layer's own
##   fee_cut      NEW BOX costs % less
##   item_cut     items cost % less
##   rate_cut     the loan interest this many points less
##   debt_pct     + % while the principal owed is half the line or more   (+ slot)
##   free_peek    a free PEEK every day of play
##   pockets      room for this many more items
##   savings      the morning after a day of play, cash grows by %
##   worth_pct    + % per WORTH_STEP (times the stake) in cash   (+ slot)
##   reading      the box-reading level (BoxReading), one per perk of the chain
##   peek_n       PEEK sees this many tickets
## Items are used up: each one held is one use. `use`: "column" (pick a column at the
## machine), "now" (used from the phone), "auto" (works by itself), "offer" (a key on
## the day's perk offers).
## Services: a contact sells them on the phone; `per_layer` caps them in each layer.

const OFFERS := 3                ## perk offers dealt each time (a bonus from outside the run adds to it)
const SHELF := 4                 ## items on the phone's shelf each day
const ITEM_CAP := 3              ## items held at once, before pockets
const OFFER_REROLL := 20         ## stake 1; doubles with each reroll the same day
const SHELF_REROLL := 10
const FIRST_TICKETS := 20
const FORTUNE_TRIES := 12
const WORTH_STEP := 100
const RARITY_WEIGHT := {"common": 10, "rare": 5, "legendary": 2}
const ITEM_WEIGHT := {"common": 10, "rare": 4, "legendary": 1}

const STANDARD := {
	"branches": [
		{"id": "money", "name": "MONEY"},
		{"id": "luck", "name": "LUCK"},
		{"id": "hands", "name": "HANDS"},
		{"id": "hustle", "name": "HUSTLE"},
		{"id": "reading", "name": "READING"},
	],
	"perks": [
		# Money: bigger prizes.
		{"id": "prizes", "branch": "money", "rarity": "common", "name": "FAT PRIZES", "desc": "EVERY PRIZE +%d%%",
			"effect": "prize_pct", "levels": [{"price": 150, "value": 25}, {"price": 400, "value": 50}, {"price": 1000, "value": 100}]},
		{"id": "scrap", "branch": "money", "rarity": "common", "name": "SCRAP DEALER", "desc": "A LOSING TICKET GIVES BACK %d%% OF ITS PRICE",
			"effect": "scrap_pct", "levels": [{"price": 100, "value": 10}, {"price": 300, "value": 25}]},
		{"id": "bigfish", "branch": "money", "rarity": "rare", "name": "BIG FISH", "desc": "TOP PRIZES X%d", "requires": {"prizes": 1},
			"effect": "top_x", "levels": [{"price": 300, "value": 2}, {"price": 900, "value": 4}]},
		{"id": "stacker", "branch": "money", "rarity": "rare", "name": "STACKER", "desc": "A TICKET WITH TWO PRIZES OR MORE X%d", "requires": {"prizes": 2},
			"effect": "stack_x", "levels": [{"price": 500, "value": 3}]},
		{"id": "trashking", "branch": "money", "rarity": "legendary", "name": "TRASH KING", "desc": "PRIZES +%d%% PER 100 LOSERS THIS LAYER",
			"requires": {"scrap": 1, "pity": 1}, "effect": "trash_pct", "levels": [{"price": 600, "value": 5}]},
		{"id": "snowball", "branch": "money", "rarity": "legendary", "name": "SNOWBALL", "desc": "EVERY BOX CLEARED: ALL PRIZES X1.1 FOR THE RUN",
			"requires": {"bigfish": 1, "closer": 1}, "effect": "snowball", "levels": [{"price": 1500, "value": 10}]},
		{"id": "hunter", "branch": "money", "rarity": "legendary", "name": "JACKPOT HUNTER", "desc": "EVERY TOP PRIZE: PRIZES +%d%% THIS LAYER",
			"requires": {"bigfish": 1, "read1": 1}, "effect": "hunter_pct", "levels": [{"price": 1800, "value": 10}]},
		# Luck: better boxes.
		{"id": "luck", "branch": "luck", "rarity": "common", "name": "LUCKY STREAK", "desc": "%d%% OF LOSING BOXES PASSED OVER",
			"effect": "luck", "levels": [{"price": 120, "value": 30}, {"price": 300, "value": 60}, {"price": 700, "value": 90}]},
		{"id": "closer", "branch": "luck", "rarity": "common", "name": "CLOSER", "desc": "LAST SALE PRIZE X%d",
			"effect": "last_sale_x", "levels": [{"price": 80, "value": 3}, {"price": 250, "value": 6}]},
		{"id": "firstpull", "branch": "luck", "rarity": "rare", "name": "FIRST PULL", "desc": "A BOX'S FIRST 20 TICKETS X%d", "requires": {"luck": 1},
			"effect": "first_x", "levels": [{"price": 150, "value": 3}, {"price": 400, "value": 5}]},
		{"id": "pity", "branch": "luck", "rarity": "rare", "name": "DUE A WIN", "desc": "EVERY LOSER IN A ROW: NEXT PRIZE +%d%%", "requires": {"luck": 1},
			"effect": "pity_pct", "levels": [{"price": 200, "value": 1}, {"price": 500, "value": 2}]},
		{"id": "assembly", "branch": "luck", "rarity": "legendary", "name": "ASSEMBLY LINE", "desc": "A BOX CLEARED IS FOLLOWED BY ONE THAT DOES NOT LOSE",
			"requires": {"closer": 1, "regular": 2}, "effect": "flow_line", "levels": [{"price": 500, "value": 1}]},
		{"id": "fortune", "branch": "luck", "rarity": "legendary", "name": "FORTUNE", "desc": "LOSING BOXES PASSED OVER AGAIN AND AGAIN",
			"requires": {"firstpull": 1, "luck": 3}, "effect": "fortune", "levels": [{"price": 1200, "value": 1}]},
		# Hands: many tickets at once, bigger bets.
		{"id": "multi", "branch": "hands", "rarity": "common", "name": "QUICK HANDS", "effect": "batch", "levels": [
			{"price": 80, "value": 5, "desc": "OPEN 5 AT ONCE"},
			{"price": 200, "value": 20, "desc": "OPEN 20 AT ONCE"},
			{"price": 400, "value": 9999, "desc": "OPEN THE WHOLE TRAY AT ONCE"}]},
		{"id": "combo", "branch": "hands", "rarity": "rare", "name": "CHAIN", "desc": "ONE OPENING: EVERY MORE WINNER +%d%%", "requires": {"multi": 1},
			"effect": "combo_pct", "levels": [{"price": 400, "value": 50}, {"price": 1200, "value": 100}]},
		{"id": "again", "branch": "hands", "rarity": "rare", "name": "ENCORE", "desc": "ONE OPENING: %d%% OF WINNERS PAY AGAIN", "requires": {"multi": 2},
			"effect": "again_pct", "levels": [{"price": 300, "value": 15}, {"price": 900, "value": 30}]},
		{"id": "bet", "branch": "hands", "rarity": "rare", "name": "HIGH ROLLER", "desc": "BET UP TO X%d: PRICE AND PRIZES", "requires": {"multi": 1},
			"effect": "bet", "levels": [{"price": 300, "value": 2}, {"price": 900, "value": 5}, {"price": 2500, "value": 10}]},
		{"id": "allin", "branch": "hands", "rarity": "legendary", "name": "ALL IN", "desc": "ONCE A DAY: BUY A BOX OUT, OPEN IT AT ONCE, X%d",
			"requires": {"combo": 1, "bet": 1}, "effect": "all_in", "levels": [{"price": 2000, "value": 2}]},
		# Hustle: money that makes money.
		{"id": "credit", "branch": "hustle", "rarity": "common", "name": "GOOD CREDIT", "desc": "HOUSE LINE +%d%%",
			"effect": "loan_pct", "levels": [{"price": 60, "value": 50}, {"price": 150, "value": 100}, {"price": 400, "value": 200}]},
		{"id": "regular", "branch": "hustle", "rarity": "common", "name": "REGULAR", "desc": "NEW BOX FEE -%d%%",
			"effect": "fee_cut", "levels": [{"price": 60, "value": 50}, {"price": 150, "value": 100}]},
		{"id": "haggler", "branch": "hustle", "rarity": "common", "name": "HAGGLER", "desc": "ITEMS -%d%%",
			"effect": "item_cut", "levels": [{"price": 100, "value": 15}]},
		{"id": "lowrate", "branch": "hustle", "rarity": "rare", "name": "LOW RATE", "desc": "LOAN INTEREST %d%%", "requires": {"credit": 1},
			"effect": "rate_cut", "levels": [{"price": 100, "value": 15, "show": 10}, {"price": 250, "value": 25, "show": 0}]},
		{"id": "debt", "branch": "hustle", "rarity": "rare", "name": "BORROWED LUCK", "desc": "OWING HALF THE LINE: PRIZES +%d%%", "requires": {"credit": 1},
			"effect": "debt_pct", "levels": [{"price": 150, "value": 25}, {"price": 400, "value": 50}]},
		{"id": "friend", "branch": "hustle", "rarity": "rare", "name": "HOUSE FRIEND", "desc": "A FREE PEEK EVERY DAY OF PLAY", "requires": {"regular": 1},
			"effect": "free_peek", "levels": [{"price": 300, "value": 1}]},
		{"id": "pockets", "branch": "hustle", "rarity": "common", "name": "BIG POCKETS", "desc": "ROOM FOR %d ITEMS", "requires": {"haggler": 1},
			"effect": "pockets", "levels": [{"price": 80, "value": 2, "show": 5}, {"price": 200, "value": 5, "show": 8}]},
		{"id": "savings", "branch": "hustle", "rarity": "rare", "name": "SAVINGS", "desc": "MORNING AFTER PLAY: CASH +%d%%", "requires": {"lowrate": 1},
			"effect": "savings", "levels": [{"price": 300, "value": 4}, {"price": 800, "value": 7}, {"price": 2000, "value": 10}]},
		{"id": "worth", "branch": "hustle", "rarity": "legendary", "name": "NET WORTH", "desc": "PRIZES +2%% PER %s IN CASH", "money": true, "requires": {"debt": 1},
			"effect": "worth_pct", "levels": [{"price": 1500, "value": 2, "show": 100}]},
		# Reading: late and dear; the low levels only hint (BoxReading).
		{"id": "read1", "branch": "reading", "rarity": "rare", "name": "READ THE FLARE", "desc": "SAYS IF A TOP PRIZE IS STILL IN",
			"requires": {"closer": 1, "regular": 1}, "effect": "reading", "levels": [{"price": 200, "value": 1}]},
		{"id": "read2", "branch": "reading", "rarity": "rare", "name": "READ THE BOX", "desc": "SAYS IF THE BOX WAS BORN FAT OR LEAN",
			"requires": {"read1": 1}, "effect": "reading", "levels": [{"price": 350, "value": 1}]},
		{"id": "read3", "branch": "reading", "rarity": "rare", "name": "HOT OR COLD", "desc": "SAYS IF WHAT IS LEFT RUNS HOT OR COLD",
			"requires": {"read2": 1}, "effect": "reading", "levels": [{"price": 600, "value": 1}]},
		{"id": "read4", "branch": "reading", "rarity": "legendary", "name": "COUNT IT", "desc": "EXACT COUNT AND PRIZES LEFT",
			"requires": {"read3": 1}, "effect": "reading", "levels": [{"price": 900, "value": 1}]},
		{"id": "read5", "branch": "reading", "rarity": "legendary", "name": "KEEP BOOKS", "desc": "THE NOTEPAD KEEPS EVERY BOX",
			"requires": {"read4": 1}, "effect": "reading", "levels": [{"price": 1200, "value": 1}]},
		{"id": "informant", "branch": "reading", "rarity": "rare", "name": "INFORMANT", "desc": "PEEK SEES THE NEXT %d",
			"requires": {"read1": 1}, "effect": "peek_n", "levels": [{"price": 100, "value": 20}, {"price": 200, "value": 30}]},
	],
	"items": [
		{"id": "peek", "kind": "INFO", "rarity": "common", "name": "PEEK", "desc": "WINNERS IN A COLUMN'S NEXT %d", "value": 10,
			"price": 20, "use": "column"},
		{"id": "magnifier", "kind": "INFO", "rarity": "common", "name": "MAGNIFIER", "desc": "SAYS IF A COLUMN'S NEXT TICKET WINS",
			"price": 8, "use": "column"},
		{"id": "tip", "kind": "INFO", "rarity": "rare", "name": "TIP-OFF", "desc": "NAMES THE HOTTEST COLUMN, NO NUMBERS",
			"price": 35, "use": "now"},
		{"id": "report", "kind": "INFO", "rarity": "rare", "name": "BOX REPORT", "desc": "READS ONE BOX IN FULL",
			"price": 60, "use": "column"},
		{"id": "coin", "kind": "ECONOMY", "rarity": "common", "name": "LUCKY COIN", "desc": "DOUBLES THE NEXT PRIZE",
			"price": 40, "use": "auto"},
		{"id": "whiteout", "kind": "ECONOMY", "rarity": "common", "name": "WHITE-OUT", "desc": "THE NEXT LOSER PAYS THE SMALLEST PRIZE",
			"price": 30, "use": "auto"},
		{"id": "happy", "kind": "ECONOMY", "rarity": "rare", "name": "HAPPY HOUR", "desc": "TODAY EVERY PRIZE +%d%%", "value": 50,
			"price": 80, "use": "now"},
		{"id": "safety", "kind": "ECONOMY", "rarity": "rare", "name": "SAFETY NET", "desc": "TODAY'S LOSS: %d%% BACK WHEN YOU LEAVE", "value": 30,
			"price": 50, "use": "now"},
		{"id": "cheat", "kind": "ECONOMY", "rarity": "legendary", "name": "CHEAT SHEET", "desc": "ONE PERK OFFER FOR FREE",
			"price": 400, "use": "offer"},
		{"id": "key", "kind": "ACTION", "rarity": "common", "name": "BOX KEY", "desc": "THE NEXT NEW BOX IS FREE",
			"price": 15, "use": "auto"},
		{"id": "skip", "kind": "ACTION", "rarity": "common", "name": "FAST FORWARD", "desc": "A COLUMN'S NEXT %d GO UNSOLD", "value": 10,
			"price": 25, "use": "column"},
		{"id": "shuffle", "kind": "ACTION", "rarity": "rare", "name": "SHUFFLE", "desc": "SHUFFLES WHAT IS LEFT IN A BOX",
			"price": 30, "use": "column"},
		{"id": "copy", "kind": "ACTION", "rarity": "legendary", "name": "COPIER", "desc": "COPIES THE LAST ITEM YOU BOUGHT",
			"price": 150, "use": "now"},
	],
	"contacts": [
		{"id": "lender", "name": "THE LENDER", "line": "LENDER LINE", "answers": true,
			"services": [{"id": "more_time", "name": "ONE MORE DAY", "desc": "THIS LAYER GETS ANOTHER DAY",
				"price": 250, "effect": "extra_day", "per_layer": 1}]},
		{"id": "unknown", "name": "UNKNOWN NUMBER", "line": "NOBODY PICKS UP", "answers": false, "services": []},
	],
}

const USES := ["column", "now", "auto", "offer"]

var branches: Array = []
var perks: Array = []
var items: Array = []
var contacts: Array = []


static func standard() -> Catalog:
	return from_dict(STANDARD)


static func from_dict(d: Dictionary) -> Catalog:
	var c := Catalog.new()
	c.branches = d.get("branches", []).duplicate(true)
	c.perks = d.get("perks", []).duplicate(true)
	c.items = d.get("items", []).duplicate(true)
	c.contacts = d.get("contacts", []).duplicate(true)
	return c


func perk(id: String) -> Dictionary:
	return _find(perks, id)


func item(id: String) -> Dictionary:
	return _find(items, id)


func contact(id: String) -> Dictionary:
	return _find(contacts, id)


## A service by its id, whichever contact sells it.
func service(id: String) -> Dictionary:
	for c in contacts:
		var s := _find(c.get("services", []), id)
		if not s.is_empty():
			return s
	return {}


func branch_perks(branch_id: String) -> Array:
	var out := []
	for p in perks:
		if p.branch == branch_id:
			out.append(p)
	return out


## Every translation key the catalog shows (tests check each has both languages).
func text_keys() -> Array:
	var out := ["COMMON", "RARE", "LEGENDARY"]
	for b in branches:
		out.append(b.name)
	for p in perks:
		out.append(p.name)
		if p.has("desc"):
			out.append(p.desc)
		for l in p.levels:
			if l.has("desc"):
				out.append(l.desc)
	for i in items:
		out += [i.name, i.desc, i.kind]
	for c in contacts:
		out += [c.name, c.line]
		for s in c.get("services", []):
			out += [s.name, s.desc]
	return out


## What is wrong with the data, as text; empty when it holds together.
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	var ids := {}
	var branch_ids := []
	for b in branches:
		branch_ids.append(b.id)
	for p in perks:
		if ids.has(p.id):
			out.append("perk %s twice" % p.id)
		ids[p.id] = true
		if not branch_ids.has(p.get("branch", "")):
			out.append("perk %s: no branch %s" % [p.id, p.get("branch", "")])
		if not RARITY_WEIGHT.has(p.get("rarity", "")):
			out.append("perk %s: rarity" % p.id)
		if str(p.get("effect", "")) == "":
			out.append("perk %s: no effect" % p.id)
		if p.get("levels", []).is_empty():
			out.append("perk %s: no levels" % p.id)
		for l in p.get("levels", []):
			if int(l.get("price", 0)) < 1:
				out.append("perk %s: a level without a price" % p.id)
			if not l.has("desc") and not p.has("desc"):
				out.append("perk %s: a level without words" % p.id)
	for p in perks:
		for need in p.get("requires", {}):
			var other := perk(need)
			if other.is_empty():
				out.append("perk %s needs %s, which is not there" % [p.id, need])
			elif int(p.requires[need]) > other.levels.size():
				out.append("perk %s needs %s at a level it does not have" % [p.id, need])
	for p in perks:
		if _circular(p.id, {}):
			out.append("perk %s needs itself" % p.id)
	for i in items:
		if int(i.get("price", 0)) < 1 or not USES.has(i.get("use", "")) or not ITEM_WEIGHT.has(i.get("rarity", "")):
			out.append("item %s: price, use or rarity" % i.id)
	for c in contacts:
		for s in c.get("services", []):
			if int(s.get("price", 0)) < 1 or int(s.get("per_layer", 0)) < 1:
				out.append("service %s: price or per_layer" % s.id)
	return out


func _circular(id: String, seen: Dictionary) -> bool:
	if seen.has(id):
		return true
	seen[id] = true
	for need in perk(id).get("requires", {}):
		if _circular(need, seen.duplicate()):
			return true
	return false


static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.id == id:
			return e
	return {}
