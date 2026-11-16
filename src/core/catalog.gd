class_name Catalog
extends RefCounted
## What the run (story mode) sells: perks, items and the services of the phone's
## contacts. Plain data, no scene access; what each effect does is RunState's rule
## (the effect hooks), so a new perk or item on an existing effect is data only.
## This is the tree draft v2 (docs/perk_research.md section 5, G's review, M9.5);
## every number is a placeholder for the balance pass.
##
## Text is translation keys (locale/ui.csv). Prices are at stake 1: the run asks the
## layer's stake times them, so a perk costs as much, in days of work, in every layer.
##
## Two ways to get a perk (the mixed tree, G):
##   the shelf   perks marked `shelf` are always on the phone, with requirements
##               shown and levels to plan for: what opens a new move (reading, the
##               loan, SAVINGS, the bet, picking a form, the tab; bigger batches wait
##               for M13)
##   the offers  every other perk is dealt in rounds (RunState.deal_offers): each
##               morning a pick of one among a few perks not held yet, and reward
##               rounds when a layer is paid (RunState.deal_reward); its requirements
##               are not shown. A dealt perk held is levelled up from the daily shelf's
##               upgrade slots (RunState.deal_upgrades) or a reward round's upgrade card
## Every dealt perk has a kind (kind()): "build" (the lines a build is made of; each
## is a branch: clearing, jackpot, small, batch, money, luck), "risk" (strong, with a
## price written at every level: `cost`), "twist" (a rule of the day changed) or "sure"
## (luck traded for certainty). Risk and twist perks have two levels.
##
## A level's `value` feeds the perk's `effect`; `extra` on a level puts more effects
## on at that level; `show` (when there) is what the text shows instead of the value,
## and a level's own `desc` replaces the perk's. `requires` are all needed,
## `requires_any` one of them. A dealt perk with `form` (a form's uid; the perks of a
## form, section 6b, are not written yet) is offered only while that form is on the
## machine (RunState.offerable).
##
## How a prize is paid (RunState.pay_ticket): the printed prize (a ticket CRUMBS split
## prints what it kept) times the bet, times
## one plus the sum of every "+%" (prize_pct, owe_pct's share, worth_pct, pity_pct,
## trash_pct, hunter_pct, noback_pct's days, STREAK's windows, loyal_pct or
## variety_pct, a HAPPY HOUR), times every "x" (top_x, mid_x and low_x on their prizes,
## stack_x on a ticket with two prizes or more, first_x on a box's first tickets, the
## snowball, a LUCKY COIN on its column, the opening's combo). An again_pct roll pays
## it all twice. ALL IN's x3 is paid on its own, when a window closes.
## "x" effects of two perks multiply (effect_x), "+" effects add (effect).
##
## Effects (value per level):
##   prize_pct    every prize +%                       (+ slot)
##   scrap_pct    a losing ticket gives back % of what it cost (cents saved up, paid in dollars)
##   top_x        top prizes times this                (x slot, multiplies)
##   mid_x        middle prizes times this
##   low_x        small prizes times this
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
##   bet          the machine's bet (price and prizes times it), fixed at the level
##                bought (no key changes it; `fixed` on the perk says so on the shelf)
##   streak_pct   + % a window in a row with a winner (+ slot; STREAK; a window is
##                WINDOW tickets opened, the player's, across columns, today's)
##   streak_cap   STREAK's + % goes no higher than this
##   all_in       a window that paid may be staked on the next: printed prize money in
##                it that reaches the bar (ALL_IN_SHARE of the staked window's, by each
##                ticket's form; more than 0 always) pays the stake x3 back, less loses
##                it (ALL IN; while it is held QUICK HANDS opens no further than the
##                window's end)
##   loan_pct     the house line + % of the layer's own
##   loan_x       the house line times this (LOAN SHARK)
##   rate_x       the loan interest times this (LOAN SHARK's price; LOW RATE's cut is
##                taken off first, so the rate never reaches zero)
##   fee_cut      NEW BOX costs % less
##   item_cut     items cost % less
##   rate_cut     the loan interest this many points less
##   owe_pct      + % of (what is owed over the house line, in %)   (+ slot; BORROWED LUCK)
##   free_peek    a free PEEK every day of play
##   pockets      room for this many more items
##   savings      every morning of a layer after its first, cash grows by % (the work line's perk)
##   worth_pct    + % per WORTH_STEP (times the stake) in cash   (+ slot)
##   reading      the box-reading level a perk of the chain reads at (BoxReading's
##                levels); the highest one held counts, not the sum
##   peek_n       PEEK sees this many tickets
##   pick_form    NEW BOX may put another of the scene's forms in the column (PICKY)
##   tab          tickets go on a tab, settled when the day ends (HOUSE ACCOUNT)
##   day_cut      every layer has this many days less (SHORT WEEK)
##   zero_low     small prizes pay nothing (FLARE ONLY)
##   zero_mid     middle prizes pay nothing
##   offer_more   this many more offers each time (DOUBLE DOWN)
##   debt_up      every layer's debt + % (DOUBLE DOWN's price)
##   noback_pct   + % per day of play since it was bought, for the run   (+ slot)
##   no_work      no more days of work this run (NO WAY BACK's price)
##   wage_cut     every day of work pays % less; on one, tickets may be bought (opened
##                the next day), as many as on a day of play (MOONLIGHTING)
##   refund_pct   an untorn ticket goes back to the machine for % of its price
##   seal         paying a layer takes this many boxes along into the next
##   loyal_pct    + % while one form alone was bought today   (+ slot)
##   variety_pct  + % per form bought today   (+ slot; the higher of LOYAL and VARIETY counts)
##   magnet       in every window of this many tickets of a box, one wins at least
##   insure       after this many losers in a row, the next ticket sold wins
##   stakeout     the first ticket sold on a day wins
##   marked       a column PEEKed at has its winners of the next MARKED_WINDOW come first
##   consolation  % of the losers taken from a box win the smallest prize (CONSOLATION)
##   packed       a box loaded from now on has % of its prizes bigger than the smallest
##                (tops and middles, picked from the seed) broken into smallest prizes
##                over its losers (PACKED; the box's money is the same; PENNY JAR and
##                STACKER pass those pieces over, TicketBox.pack)
##   crumbs       a winner taken from a box with a prize bigger than the smallest splits
##                it over up to this many of the next losers in it, each the smallest
##                prize, while it keeps the smallest at least (CRUMBS; the money is the same)
## The last three are the line that wins more often (docs/perk_research.md section 15):
## the ticket really is a winner (it shows it, STREAK and ALL IN count it), decided
## from the seed as it leaves the box (MachineLogic._take, TicketBox).
## A perk with `meta` is parked for the shop outside the run (M13): never on the shelf,
## dealt or sold in a run (perks_of, dealt, RunState.can_buy_perk), its effect still
## working when it is held (a save, the developer panel). QUICK HANDS, CHAIN and ENCORE
## (G, 2026-11-07: no batch opening in the run until then).
## Items are used up: each one held is one use. `use`: "column" (pick a column at the
## machine), "now" (used from the phone), "auto" (works by itself), "offer" (a key on
## a morning round of perk offers).
## Services: a contact sells them on the phone; `per_layer` caps them in each layer.

const OFFERS := 3                ## cards a round of perk offers (a bonus from outside the run adds to it)
const SHELF := 4                 ## items on the phone's shelf each day (never rerolled)
const ITEM_CAP := 3              ## items held at once, before pockets
const OFFER_REROLL := 20         ## stake 1; doubles with each reroll of the same round
const FIRST_TICKETS := 20
const FORTUNE_TRIES := 12
const WORTH_STEP := 100
const WINDOW := 10               ## STREAK and ALL IN: a window is this many tickets opened (G)
const MARKED_WINDOW := 10        ## MARKED: the PEEKed column's winners of this many come first
const QUEUE_WINDOW := 20         ## QUEUE JUMP: winners moved into the next this many
const QUEUE_MOVES := 5
## CONSOLATION's share of losers that win the smallest prize, at levels 1 and 2. Section
## 15 had 10 / 20 when the smallest prizes were $25; at $5 on a $1 ticket that would
## add 40 to 85% to the return, so 5 / 10 (about +20 / +40%, FAT PRIZES' range; winners
## from about 15 in 100 to 19 / 23). The balance pass tunes it here.
const CONSOLATION := [5, 10]
## ALL IN's bar (G, 2026-11-07: a push wins about half the time on every form; the x3
## stays): the next window wins when its printed prizes reach this percentage of the
## staked window's, each ticket of the staked window counted at its own form's share
## (form uid -> percent). Measured with SimData.push_odds on the run's small boxes at the
## run's payout 0.735 (M9.7 item 10, windows of ten, 1000 boxes a form): Hot Plate 0.48,
## Lucky Spur 0.45, Pecking Order 0.50, One Flock 0.51, Nugget Rush 0.53, Peckeye 0.47.
## P is flat between bars and jumps at the window's price steps (Lucky Spur: 0.56 up to
## 50%, 0.47 from 51% to 60%), so these are the nearest steps to a half. Big Catch (bar
## 100%: 0.28) and Ka-Bawk! (bar 50%: 0.19) pay on so few tickets (4.7 and 2.6 in 100)
## that no bar reaches half; G (2026-11-07) keeps them as they are: those two forms
## simply do not suit the ALL IN line, and a player finds that out. A form without a row (a Workshop form) uses
## ALL_IN_DEFAULT, the middle of the core forms'. Kept here beside the perk's other
## numbers (CONSOLATION) rather than in the form's json: it is ALL IN's balance,
## measured by the simulator.
const ALL_IN_SHARE := {"core:catch": 100, "core:plate": 60, "core:spur": 60, "core:order": 45,
	"core:kabawk": 50, "core:flock": 45, "core:nugget": 45, "core:peckeye": 60}
const ALL_IN_DEFAULT := 65
const RARITY_WEIGHT := {"common": 10, "rare": 5, "legendary": 2}
## The deal at each layer (RunState.deal_offers, deal_reward), one entry per layer, the last one
## for any layer after it: the weight of each rarity (0 deals none) and the kinds left
## out (G, docs/perk_research.md section 5.12). Layer 1 is mostly common, a few rare,
## a legendary now and then (G: the first layer must be able to raise a player's
## ceiling) and no risk; layer 2 opens everything at RARITY_WEIGHT; layer 3 weighs
## legendary up. The weights are placeholders.
const DEAL := [
	{"rarity": {"common": 10, "rare": 3, "legendary": 1}, "no_kinds": ["risk"]},
	{"rarity": {"common": 10, "rare": 5, "legendary": 2}, "no_kinds": []},
	{"rarity": {"common": 10, "rare": 5, "legendary": 5}, "no_kinds": []},
]
## The pool of entry cards the starter round deals three from (RunConfig.starter, an
## experiment for roadmap 十三.5; RunState.starter_cards; a config may replace it,
## RunConfig.starter_cards). Not tied to the build lines. G's list, 2026-11-16; generic
## entry cards are to be added, and the rule stays off until the pool is big enough.
## problems() holds it to starter_problems.
const STARTER := ["penny", "scrap", "consolation"]
const ITEM_WEIGHT := {"common": 10, "rare": 4, "legendary": 1}
const KINDS := ["shelf", "build", "risk", "twist", "sure"]
const KIND_NAMES := {"shelf": "THE SHELF", "build": "BUILD", "risk": "RISK", "twist": "TWIST", "sure": "CERTAINTY"}
## Branches of dealt perks that are a kind of their own; the others are build lines.
const KIND_BRANCHES := {"shelf": "shelf", "risk": "risk", "twist": "twist", "sure": "sure"}

const STANDARD := {
	"branches": [
		{"id": "shelf", "name": "THE SHELF"},
		{"id": "clearing", "name": "CLEAR THE BOX"},
		{"id": "jackpot", "name": "JACKPOT"},
		{"id": "small", "name": "SMALL PRIZES"},
		{"id": "batch", "name": "ALL AT ONCE"},
		{"id": "money", "name": "MONEY"},
		{"id": "luck", "name": "LUCK"},
		{"id": "often", "name": "WIN MORE OFTEN"},
		{"id": "risk", "name": "RISK"},
		{"id": "twist", "name": "TWIST"},
		{"id": "sure", "name": "CERTAINTY"},
	],
	"perks": [
		# The shelf: always on the phone, requirements shown, to plan for.
		{"id": "read1", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "READ THE FLARE", "desc": "SAYS IF A TOP PRIZE IS STILL IN",
			"requires_any": {"closer": 1, "regular": 1}, "effect": "reading", "levels": [{"price": 200, "value": BoxReading.FLARE}]},
		# The chain's second and third places (docs/roadmap.md 数值方向 三.10), at those
		# places' prices: READ THE BOX, HOT OR COLD, COUNT IT and KEEP BOOKS left it
		# (read2..read5; a save holding them loads without them), so these have ids of
		# their own.
		{"id": "flow", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "READ THE FLOW", "desc": "SAYS ABOUT HOW MANY WERE SOLD AND WHAT THEY PAID",
			"requires": {"read1": 1}, "effect": "reading", "levels": [{"price": 350, "value": BoxReading.FLOW}]},
		{"id": "readleft", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "ROUGH COUNT", "desc": "SAYS ABOUT HOW MANY ARE LEFT, TO THE NEAREST 50",
			"requires": {"flow": 1}, "effect": "reading", "levels": [{"price": 600, "value": BoxReading.LEFT}]},
		{"id": "informant", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "INFORMANT", "requires": {"read1": 1},
			"effect": "peek_n", "levels": [{"price": 100, "value": 50, "desc": "PEEK SEES THE NEXT 50"},
				{"price": 250, "value": 100, "extra": {"free_peek": 1}, "desc": "PEEK SEES THE NEXT 100, AND ONE IS FREE EVERY DAY OF PLAY"}]},
		{"id": "credit", "branch": "shelf", "shelf": true, "rarity": "common", "name": "GOOD CREDIT", "desc": "HOUSE LINE +%d%%",
			"effect": "loan_pct", "levels": [{"price": 60, "value": 50}, {"price": 150, "value": 100}, {"price": 400, "value": 200}]},
		{"id": "lowrate", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "LOW RATE", "desc": "LOAN INTEREST %d%%", "requires": {"credit": 1},
			"effect": "rate_cut", "levels": [{"price": 100, "value": 5, "show": 10}, {"price": 250, "value": 10, "show": 5}]},
		# SAVINGS is the work line's perk (RunConfig): every morning, cash grows; no
		# requirement, so it can be bought first thing. Its numbers set the layers' debts.
		{"id": "savings", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "SAVINGS", "desc": "EVERY MORNING: CASH +%d%%",
			"effect": "savings", "levels": [{"price": 50, "value": 10}, {"price": 150, "value": 20}, {"price": 400, "value": 30}]},
		{"id": "regular", "branch": "shelf", "shelf": true, "rarity": "common", "name": "REGULAR", "desc": "NEW BOX FEE -%d%%",
			"effect": "fee_cut", "levels": [{"price": 60, "value": 50}, {"price": 150, "value": 75}]},
		{"id": "haggler", "branch": "shelf", "shelf": true, "rarity": "common", "name": "HAGGLER", "desc": "ITEMS -%d%%",
			"effect": "item_cut", "levels": [{"price": 100, "value": 25}]},
		{"id": "pockets", "branch": "shelf", "shelf": true, "rarity": "common", "name": "BIG POCKETS", "desc": "ROOM FOR %d ITEMS",
			"effect": "pockets", "levels": [{"price": 80, "value": 2, "show": 5}, {"price": 200, "value": 5, "show": 8}]},
		# QUICK HANDS waits for the shop outside the run (M13, G 2026-11-07): `meta`, so it
		# is never on the shelf, dealt or sold in a run; its effect still works when held.
		{"id": "multi", "branch": "shelf", "shelf": true, "meta": true, "rarity": "common", "name": "QUICK HANDS", "effect": "batch", "levels": [
			{"price": 80, "value": 5, "desc": "OPEN 5 AT ONCE"},
			{"price": 200, "value": 20, "desc": "OPEN 20 AT ONCE"},
			{"price": 400, "value": 9999, "desc": "OPEN THE WHOLE TRAY AT ONCE"}]},
		# HIGH ROLLER is the bet itself (G, part 14): the level bought, never undone.
		{"id": "bet", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "HIGH ROLLER", "desc": "BET X%d: PRICE AND PRIZES", "fixed": true,
			"effect": "bet", "levels": [{"price": 300, "value": 2}, {"price": 900, "value": 5}, {"price": 2500, "value": 10}]},
		{"id": "picky", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "PICKY", "desc": "NEW BOX: PICK WHICH TICKET GOES IN", "requires": {"regular": 1},
			"effect": "pick_form", "levels": [{"price": 150, "value": 1}]},
		{"id": "account", "branch": "shelf", "shelf": true, "rarity": "rare", "name": "HOUSE ACCOUNT", "desc": "TICKETS ON A TAB, SETTLED WHEN YOU LEAVE", "requires": {"credit": 1},
			"effect": "tab", "levels": [{"price": 200, "value": 1}]},
		# Build: clearing boxes (around the last sale).
		{"id": "closer", "branch": "clearing", "rarity": "common", "name": "CLOSER", "desc": "LAST SALE PRIZE X%d",
			"effect": "last_sale_x", "levels": [{"price": 80, "value": 3}, {"price": 250, "value": 6}]},
		{"id": "firstpull", "branch": "clearing", "rarity": "rare", "name": "FIRST PULL", "desc": "A BOX'S FIRST 20 TICKETS X%d",
			"effect": "first_x", "levels": [{"price": 150, "value": 3}, {"price": 400, "value": 5}]},
		{"id": "assembly", "branch": "clearing", "rarity": "legendary", "name": "ASSEMBLY LINE", "desc": "A BOX CLEARED IS FOLLOWED BY ONE THAT DOES NOT LOSE",
			"requires": {"closer": 1}, "effect": "flow_line", "levels": [{"price": 500, "value": 1}]},
		{"id": "snowball", "branch": "clearing", "rarity": "legendary", "name": "SNOWBALL", "desc": "EVERY BOX CLEARED: ALL PRIZES X1.1 FOR THE RUN",
			"requires": {"closer": 1}, "effect": "snowball", "levels": [{"price": 1500, "value": 10}]},
		# Build: the jackpot (Big Catch, Ka-Bawk!).
		{"id": "bigfish", "branch": "jackpot", "rarity": "rare", "name": "BIG FISH", "desc": "TOP PRIZES X%d",
			"effect": "top_x", "levels": [{"price": 300, "value": 2}, {"price": 900, "value": 4}]},
		{"id": "pity", "branch": "jackpot", "rarity": "rare", "name": "DUE A WIN", "desc": "EVERY LOSER IN A ROW: NEXT PRIZE +%d%%",
			"effect": "pity_pct", "levels": [{"price": 200, "value": 1}, {"price": 500, "value": 2}]},
		{"id": "hunter", "branch": "jackpot", "rarity": "legendary", "name": "JACKPOT HUNTER", "desc": "EVERY TOP PRIZE: PRIZES +%d%% THIS LAYER",
			"requires": {"bigfish": 1, "read1": 1}, "effect": "hunter_pct", "levels": [{"price": 1800, "value": 10}]},
		# Build: small prizes (Hot Plate, Nugget Rush).
		{"id": "penny", "branch": "small", "rarity": "common", "name": "PENNY JAR", "desc": "SMALL PRIZES X%d",
			"effect": "low_x", "levels": [{"price": 100, "value": 2}, {"price": 300, "value": 3}]},
		{"id": "stacker", "branch": "small", "rarity": "rare", "name": "STACKER", "desc": "A TICKET WITH TWO PRIZES OR MORE X%d",
			"effect": "stack_x", "levels": [{"price": 500, "value": 3}]},
		{"id": "scrap", "branch": "small", "rarity": "common", "name": "SCRAP DEALER", "desc": "A LOSING TICKET GIVES BACK %d%% OF ITS PRICE",
			"effect": "scrap_pct", "levels": [{"price": 100, "value": 10}, {"price": 300, "value": 25}]},
		{"id": "trashking", "branch": "small", "rarity": "legendary", "name": "TRASH KING", "desc": "PRIZES +%d%% PER 100 LOSERS THIS LAYER",
			"requires": {"scrap": 1}, "effect": "trash_pct", "levels": [{"price": 600, "value": 5}]},
		# Build: all at once. CHAIN and ENCORE act on one opening of QUICK HANDS, so they
		# wait for M13 with it (`meta`: never dealt in a run; the effects still work).
		{"id": "combo", "branch": "batch", "meta": true, "rarity": "rare", "name": "CHAIN", "desc": "ONE OPENING: EVERY MORE WINNER +%d%%", "requires": {"multi": 1},
			"effect": "combo_pct", "levels": [{"price": 400, "value": 50}, {"price": 1200, "value": 100}]},
		{"id": "again", "branch": "batch", "meta": true, "rarity": "rare", "name": "ENCORE", "desc": "ONE OPENING: %d%% OF WINNERS PAY AGAIN", "requires": {"multi": 2},
			"effect": "again_pct", "levels": [{"price": 300, "value": 15}, {"price": 900, "value": 30}]},
		# On the window of WINDOW tickets (G, part 3): what is left of the line in a run.
		# ALL IN is the old perk's name on the window stake (G renamed DOUBLE UP back,
		# 2026-11-07); it needs STREAK 1 (G, 2026-11-07: CHAIN went out with QUICK HANDS).
		# The next window wins at ALL_IN_SHARE of the staked one's printed prizes.
		{"id": "streak", "branch": "batch", "rarity": "rare", "name": "STREAK", "effect": "streak_pct", "levels": [
			{"price": 300, "value": 25, "extra": {"streak_cap": 100}, "desc": "EVERY 10 OPENED WITH A WINNER: PRIZES +25% MORE, UP TO +100%"},
			{"price": 800, "value": 40, "extra": {"streak_cap": 160}, "desc": "EVERY 10 OPENED WITH A WINNER: PRIZES +40% MORE, UP TO +160%"}]},
		{"id": "allin", "branch": "batch", "rarity": "legendary", "name": "ALL IN",
			"desc": "10 OPENED PAID: STAKE IT ON THE NEXT 10. THEY PRINT AT LEAST HALF TO ALL OF THIS, BY THE TICKET: X3 BACK. LESS: GONE",
			"requires": {"streak": 1}, "effect": "all_in", "levels": [{"price": 2000, "value": 1}]},
		# Build: money that makes money (with SAVINGS off the shelf).
		{"id": "worth", "branch": "money", "rarity": "legendary", "name": "NET WORTH", "desc": "PRIZES +2%% PER %s IN CASH", "money": true, "requires": {"savings": 1},
			"effect": "worth_pct", "levels": [{"price": 1500, "value": 2, "show": 100}]},
		{"id": "middle", "branch": "money", "rarity": "rare", "name": "MIDDLE CUT", "desc": "MIDDLE PRIZES X%d",
			"effect": "mid_x", "levels": [{"price": 300, "value": 2}, {"price": 800, "value": 3}]},
		# Luck: no line, anyone's.
		{"id": "luck", "branch": "luck", "rarity": "common", "name": "LUCKY STREAK", "desc": "%d%% OF LOSING BOXES PASSED OVER",
			"effect": "luck", "levels": [{"price": 120, "value": 30}, {"price": 300, "value": 60}, {"price": 700, "value": 90}]},
		{"id": "fortune", "branch": "luck", "rarity": "legendary", "name": "FORTUNE", "desc": "LOSING BOXES PASSED OVER AGAIN AND AGAIN",
			"requires": {"luck": 3}, "effect": "fortune", "levels": [{"price": 1200, "value": 1}]},
		{"id": "prizes", "branch": "luck", "rarity": "common", "name": "FAT PRIZES", "desc": "EVERY PRIZE +%d%%",
			"effect": "prize_pct", "levels": [{"price": 150, "value": 25}, {"price": 400, "value": 50}, {"price": 1000, "value": 100}]},
		# Build: winning more often (G, section 15): more tickets win, the return barely
		# moves (CONSOLATION adds some; PACKED and CRUMBS put the same money on more tickets).
		{"id": "consolation", "branch": "often", "rarity": "common", "name": "CONSOLATION", "desc": "%d%% OF LOSERS WIN THE SMALLEST PRIZE",
			"effect": "consolation", "levels": [{"price": 100, "value": CONSOLATION[0]}, {"price": 300, "value": CONSOLATION[1]}]},
		{"id": "packed", "branch": "often", "rarity": "rare", "name": "PACKED", "desc": "BOXES LOADED FROM NOW ON: %d%% OF THE BIG PRIZES BROKEN INTO SMALLEST ONES, NOT FOR PENNY JAR OR STACKER",
			"effect": "packed", "levels": [{"price": 200, "value": 25}, {"price": 500, "value": 50}]},
		{"id": "crumbs", "branch": "often", "rarity": "rare", "name": "CRUMBS", "desc": "A PRIZE OVER THE SMALLEST CRUMBLES: UP TO %d OF THE NEXT LOSERS IN THE BOX WIN THE SMALLEST",
			"effect": "crumbs", "levels": [{"price": 250, "value": 5}, {"price": 600, "value": 20}]},
		# Risk: strong, with a price at every level.
		{"id": "shark", "branch": "risk", "rarity": "rare", "name": "LOAN SHARK", "desc": "HOUSE LINE X%d",
			"effect": "loan_x", "levels": [{"price": 150, "value": 2, "extra": {"rate_x": 2}, "cost": "INTEREST X2"},
				{"price": 400, "value": 3, "extra": {"rate_x": 3}, "cost": "INTEREST X3"}]},
		{"id": "debt", "branch": "risk", "rarity": "rare", "name": "BORROWED LUCK",
			"effect": "owe_pct", "levels": [{"price": 150, "value": 100, "desc": "PRIZES UP BY AS MUCH OF THE LINE AS YOU OWE", "cost": "ONLY WHILE YOU OWE"},
				{"price": 400, "value": 200, "desc": "PRIZES UP BY TWICE AS MUCH OF THE LINE AS YOU OWE", "cost": "ONLY WHILE YOU OWE"}]},
		{"id": "shortweek", "branch": "risk", "rarity": "rare", "name": "SHORT WEEK", "desc": "EVERY PRIZE +%d%%",
			"effect": "prize_pct", "levels": [{"price": 200, "value": 50, "extra": {"day_cut": 1}, "cost": "A DAY LESS IN EVERY LAYER"},
				{"price": 500, "value": 100, "extra": {"day_cut": 2}, "cost": "TWO DAYS LESS IN EVERY LAYER"}]},
		{"id": "flare", "branch": "risk", "rarity": "rare", "name": "FLARE ONLY", "desc": "TOP PRIZES X%d",
			"effect": "top_x", "levels": [{"price": 250, "value": 3, "extra": {"zero_low": 1}, "cost": "SMALL PRIZES PAY NOTHING"},
				{"price": 600, "value": 5, "extra": {"zero_low": 1, "zero_mid": 1}, "cost": "SMALL AND MIDDLE PRIZES PAY NOTHING"}]},
		{"id": "double", "branch": "risk", "rarity": "rare", "name": "DOUBLE DOWN",
			"effect": "offer_more", "levels": [{"price": 100, "value": 1, "extra": {"debt_up": 25}, "desc": "ONE MORE OFFER EVERY TIME", "cost": "EVERY DEBT +25%"},
				{"price": 300, "value": 2, "extra": {"debt_up": 50}, "desc": "TWO MORE OFFERS EVERY TIME", "cost": "EVERY DEBT +50%"}]},
		{"id": "noback", "branch": "risk", "rarity": "legendary", "name": "NO WAY BACK", "desc": "EVERY DAY OF PLAY: PRIZES +%d%% FOR THE RUN",
			"effect": "noback_pct", "levels": [{"price": 800, "value": 10, "extra": {"no_work": 1}, "cost": "NO MORE DAYS OF WORK THIS RUN"},
				{"price": 1500, "value": 15, "extra": {"no_work": 1}, "cost": "NO MORE DAYS OF WORK THIS RUN"}]},
		# Twist: a rule of the day changed.
		{"id": "moonlight", "branch": "twist", "rarity": "common", "name": "MOONLIGHTING", "desc": "A DAY OF WORK: BUY TICKETS FOR TOMORROW, THE WAGE -%d%%",
			"effect": "wage_cut", "levels": [{"price": 150, "value": 30}, {"price": 350, "value": 15}]},
		{"id": "returns", "branch": "twist", "rarity": "common", "name": "RETURNS", "desc": "AN UNTORN TICKET GOES BACK FOR %d%% OF ITS PRICE",
			"effect": "refund_pct", "levels": [{"price": 100, "value": 50}, {"price": 300, "value": 100}]},
		{"id": "seal", "branch": "twist", "rarity": "rare", "name": "SEAL",
			"effect": "seal", "levels": [{"price": 300, "value": 1, "desc": "PAY UP: A BOX COMES ALONG TO THE NEXT LAYER"},
				{"price": 700, "value": 2, "desc": "PAY UP: TWO BOXES COME ALONG TO THE NEXT LAYER"}]},
		{"id": "loyal", "branch": "twist", "rarity": "common", "name": "LOYAL", "desc": "ONE KIND OF TICKET ALL DAY: PRIZES +%d%%",
			"effect": "loyal_pct", "levels": [{"price": 120, "value": 30}, {"price": 300, "value": 60}]},
		{"id": "variety", "branch": "twist", "rarity": "common", "name": "VARIETY", "desc": "EVERY KIND BOUGHT TODAY: PRIZES +%d%%",
			"effect": "variety_pct", "levels": [{"price": 120, "value": 5}, {"price": 300, "value": 10}]},
		{"id": "magnet", "branch": "twist", "rarity": "rare", "name": "MAGNET", "desc": "EVERY %d TICKETS OF A BOX, ONE WINS AT LEAST",
			"effect": "magnet", "levels": [{"price": 250, "value": 20}, {"price": 600, "value": 10}]},
		# Sure: luck traded for certainty (a prize of the box moved forward).
		{"id": "insurance", "branch": "sure", "rarity": "rare", "name": "INSURANCE", "desc": "%d LOSERS IN A ROW: THE NEXT ONE WINS",
			"effect": "insure", "levels": [{"price": 200, "value": 30}, {"price": 500, "value": 15}]},
		{"id": "stakeout", "branch": "sure", "rarity": "common", "name": "STAKEOUT", "desc": "THE FIRST TICKET OF THE DAY WINS",
			"effect": "stakeout", "levels": [{"price": 150, "value": 1}]},
		{"id": "marked", "branch": "sure", "rarity": "legendary", "name": "MARKED", "desc": "A COLUMN PEEKED AT: ITS NEXT 10 WINNERS COME FIRST",
			"requires": {"informant": 1}, "effect": "marked", "levels": [{"price": 1000, "value": 1}]},
	],
	"items": [
		{"id": "peek", "kind": "INFO", "rarity": "common", "name": "PEEK", "desc": "WINNERS IN A COLUMN'S NEXT %d", "value": 50,
			"price": 20, "use": "column"},
		{"id": "magnifier", "kind": "INFO", "rarity": "common", "name": "MAGNIFIER", "desc": "SAYS IF A COLUMN'S NEXT TICKET WINS",
			"price": 8, "use": "column"},
		# TIP-OFF left (docs/roadmap.md 数值方向 三.10): it named a column by the prize
		# money left. BOX REPORT is parked until step 4: its new form says what the part of
		# a box other customers bought paid, which needs the boxes sold before they come
		# to the machine. A save holding either loads without it.
		{"id": "coin", "kind": "ECONOMY", "rarity": "common", "name": "LUCKY COIN", "desc": "A COLUMN'S NEXT PRIZE X2",
			"price": 40, "use": "column"},
		{"id": "whiteout", "kind": "ECONOMY", "rarity": "common", "name": "WHITE-OUT", "desc": "THE NEXT LOSER PAYS THE SMALLEST PRIZE",
			"price": 30, "use": "auto"},
		{"id": "happy", "kind": "ECONOMY", "rarity": "rare", "name": "HAPPY HOUR", "desc": "TODAY EVERY PRIZE +%d%%", "value": 50,
			"price": 80, "use": "now"},
		{"id": "safety", "kind": "ECONOMY", "rarity": "rare", "name": "SAFETY NET", "desc": "TODAY'S LOSS: %d%% BACK WHEN YOU LEAVE", "value": 30,
			"price": 50, "use": "now"},
		{"id": "overtime", "kind": "ECONOMY", "rarity": "common", "name": "OVERTIME", "desc": "TODAY'S SHIFT PAYS DOUBLE",
			"price": 60, "use": "now"},
		{"id": "cheat", "kind": "ECONOMY", "rarity": "legendary", "name": "CHEAT SHEET", "desc": "ONE PERK OFFER FOR FREE",
			"price": 400, "use": "offer"},
		{"id": "slip", "kind": "ACTION", "rarity": "common", "name": "RETURN SLIP", "desc": "EVERY UNOPENED TICKET IN THE TRAY GOES BACK, FULL PRICE",
			"price": 25, "use": "now"},
		{"id": "skip", "kind": "ACTION", "rarity": "common", "name": "FAST FORWARD", "desc": "A COLUMN'S NEXT %d GO UNSOLD", "value": 50,
			"price": 25, "use": "column"},
		{"id": "shuffle", "kind": "ACTION", "rarity": "rare", "name": "SHUFFLE", "desc": "SHUFFLES WHAT IS LEFT IN A BOX",
			"price": 30, "use": "column"},
		{"id": "mover", "kind": "ACTION", "rarity": "rare", "name": "MOVER", "desc": "A COLUMN'S BOX TRADES PLACES WITH THE NEXT COLUMN'S",
			"price": 40, "use": "column"},
		{"id": "copy", "kind": "ACTION", "rarity": "legendary", "name": "COPIER", "desc": "COPIES THE LAST ITEM YOU BOUGHT",
			"price": 150, "use": "now"},
		{"id": "sure", "kind": "SURE", "rarity": "rare", "name": "SURE THING", "desc": "A COLUMN'S NEXT TICKET WINS: ONE OF ITS PRIZES, MOVED UP",
			"price": 60, "use": "column"},
		{"id": "reel", "kind": "SURE", "rarity": "legendary", "name": "REEL IN", "desc": "A COLUMN'S NEXT TICKET IS ITS BIGGEST PRIZE LEFT",
			"price": 200, "use": "column"},
		{"id": "queue", "kind": "SURE", "rarity": "rare", "name": "QUEUE JUMP", "desc": "A COLUMN'S NEXT 20 GET 5 OF ITS WINNERS, MOVED UP",
			"price": 80, "use": "column"},
	],
	"contacts": [
		{"id": "lender", "name": "THE LENDER", "line": "LENDER LINE", "answers": true,
			"services": [{"id": "more_time", "name": "ONE MORE DAY", "desc": "THIS LAYER GETS ANOTHER DAY",
				"price": 250, "effect": "extra_day", "per_layer": 1}]},
		{"id": "unknown", "name": "UNKNOWN NUMBER", "line": "NOBODY PICKS UP", "answers": false, "services": []},
	],
}

const USES := ["column", "now", "auto", "offer"]
const ITEM_KINDS := ["INFO", "ECONOMY", "ACTION", "SURE"]

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


## A perk's kind: "shelf" when it is on the shelf, else its branch's kind, "build"
## for a build line.
static func kind(p: Dictionary) -> String:
	if p.get("shelf", false):
		return "shelf"
	return str(KIND_BRANCHES.get(str(p.get("branch", "")), "build"))


## The deal at a layer (0-based): an entry of `table` (DEAL when empty; a run's is
## RunConfig.deal), the last one past the end.
static func deal(layer: int, table: Array = []) -> Dictionary:
	var t: Array = DEAL if table.is_empty() else table
	return t[clampi(layer, 0, t.size() - 1)]


## A perk's weight in a deal at a layer: its rarity's weight in `table` (DEAL when
## empty), 0 when the layer leaves its kind (or its rarity) out.
static func deal_weight(p: Dictionary, layer: int, table: Array = []) -> float:
	var d := deal(layer, table)
	if d.no_kinds.has(kind(p)):
		return 0.0
	return float(d.rarity.get(str(p.get("rarity", "")), 0))


## Whether a perk is parked for the shop outside the run (M13): not in a run's shop.
static func meta(p: Dictionary) -> bool:
	return bool(p.get("meta", false))


## ALL IN's share (percent) for a form, by its uid: ALL_IN_SHARE, or ALL_IN_DEFAULT.
static func all_in_share(form_uid: String) -> int:
	return int(ALL_IN_SHARE.get(form_uid, ALL_IN_DEFAULT))


## ALL IN's bar in dollars from a window's printed prizes each times its form's share
## (the sum of prize x percent): the share of it, rounded up, and never under $1 (an
## empty window always loses).
static func all_in_bar(weighted: int) -> int:
	return maxi(1, ceili(weighted / 100.0))


## Perks of a kind ("shelf" is the shelf, the others are dealt) a run sells (no `meta`).
func perks_of(kind_id: String) -> Array:
	var out := []
	for p in perks:
		if kind(p) == kind_id and not meta(p):
			out.append(p)
	return out


## The perks dealt as offers (everything off the shelf, but `meta`).
func dealt() -> Array:
	var out := []
	for p in perks:
		if not p.get("shelf", false) and not meta(p):
			out.append(p)
	return out


## Every translation key the catalog shows (tests check each has both languages).
func text_keys() -> Array:
	var out := ["COMMON", "RARE", "LEGENDARY"]
	for k in KIND_NAMES:
		out.append(KIND_NAMES[k])
	for b in branches:
		out.append(b.name)
	for p in perks:
		out.append(p.name)
		if p.has("desc"):
			out.append(p.desc)
		for l in p.levels:
			if l.has("desc"):
				out.append(l.desc)
			if l.has("cost"):
				out.append(l.cost)
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
		var k := kind(p)
		if (k == "shelf") != (p.get("branch", "") == "shelf"):
			out.append("perk %s: on the shelf and in branch %s" % [p.id, p.get("branch", "")])
		if (k == "risk" or k == "twist") and p.get("levels", []).size() != 2:
			out.append("perk %s: a %s perk has two levels (G)" % [p.id, k])
		for l in p.get("levels", []):
			if int(l.get("price", 0)) < 1:
				out.append("perk %s: a level without a price" % p.id)
			if not l.has("desc") and not p.has("desc"):
				out.append("perk %s: a level without words" % p.id)
			if k == "risk" and str(l.get("cost", "")) == "":
				out.append("perk %s: a risk perk's level without its price written" % p.id)
			if k != "risk" and l.has("cost"):
				out.append("perk %s: a cost on a perk that is not a risk" % p.id)
	for p in perks:
		for need in p.get("requires", {}).keys() + p.get("requires_any", {}).keys():
			var other := perk(need)
			var lv: int = p.get("requires", {}).get(need, p.get("requires_any", {}).get(need, 0))
			if other.is_empty():
				out.append("perk %s needs %s, which is not there" % [p.id, need])
			elif meta(other) and not meta(p):
				out.append("perk %s needs %s, which a run does not sell (meta)" % [p.id, need])
			elif lv > other.levels.size():
				out.append("perk %s needs %s at a level it does not have" % [p.id, need])
	out.append_array(deal_problems(DEAL))
	out.append_array(starter_problems(STARTER))
	for p in perks:
		if _circular(p.id, {}):
			out.append("perk %s needs itself" % p.id)
	for i in items:
		if int(i.get("price", 0)) < 1 or not USES.has(i.get("use", "")) or not ITEM_WEIGHT.has(i.get("rarity", "")) \
				or not ITEM_KINDS.has(i.get("kind", "")):
			out.append("item %s: price, use, kind or rarity" % i.id)
	for c in contacts:
		for s in c.get("services", []):
			if int(s.get("price", 0)) < 1 or int(s.get("per_layer", 0)) < 1:
				out.append("service %s: price or per_layer" % s.id)
	return out


## What is wrong with a table of rarity weights by layer (DEAL, or a config's
## RunConfig.deal): one entry per layer, three; a weight 0 or more for each rarity;
## known kinds left out; no risk in layer 1 (G).
static func deal_problems(table: Array) -> PackedStringArray:
	var out := PackedStringArray()
	if table.size() != 3:
		out.append("the deal: one entry per layer, three")
	for i in table.size():
		for r in RARITY_WEIGHT:
			if not table[i].rarity.has(r) or int(table[i].rarity[r]) < 0:
				out.append("the deal at layer %d: a weight for %s, 0 or more" % [i + 1, r])
		for k in table[i].no_kinds:
			if not KINDS.has(k):
				out.append("the deal at layer %d: no kind %s" % [i + 1, k])
	if not table.is_empty() and not table[0].no_kinds.has("risk"):
		out.append("the deal at layer 1: no risk (G)")
	return out


## What is wrong with a starter pool (STARTER, or a config's RunConfig.starter_pool):
## one card or more, no card twice, each a dealt perk that is there, not meta, with no
## requirements, and dealt in layer 1 by `table` (DEAL when empty).
func starter_problems(pool: Array, table: Array = []) -> PackedStringArray:
	var out := PackedStringArray()
	if pool.is_empty():
		out.append("the starter pool: no card")
	var seen := {}
	for c in pool:
		var id := str(c)
		var p := perk(id)
		if seen.has(id):
			out.append("the starter pool: %s twice" % id)
		elif p.is_empty():
			out.append("the starter pool: %s is not there" % id)
		elif p.get("shelf", false) or meta(p):
			out.append("the starter pool: %s is not dealt in a run" % id)
		elif not p.get("requires", {}).is_empty() or not p.get("requires_any", {}).is_empty():
			out.append("the starter pool: %s has requirements" % id)
		elif deal_weight(p, 0, table) <= 0.0:
			out.append("the starter pool: %s is not dealt in layer 1" % id)
		seen[id] = true
	return out


func _circular(id: String, seen: Dictionary) -> bool:
	if seen.has(id):
		return true
	seen[id] = true
	var p := perk(id)
	for need in p.get("requires", {}).keys() + p.get("requires_any", {}).keys():
		if _circular(need, seen.duplicate()):
			return true
	return false


static func _find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.id == id:
			return e
	return {}
