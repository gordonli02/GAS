class_name Economy
extends RefCounted
## Money and the session ledger. Pure logic, no scene access.
## Rules (MIGRATION.md "Money"): start with $200 cash and $0 credit; a bill moves
## to credit when it finishes feeding; tickets are paid from credit; prizes go to
## cash; CASH OUT moves credit to cash; a loan adds cash but never counts in NET.
## Invariant: cash + credit + bill being fed = 200 + loans + won - spent.
## A run (RunState) adds its own lines: a starting cash of its own, wages and other
## income (`earned`), repayments, fees and purchases (`paid`), and bills at the stage's
## stake. The invariant then reads start + loans + won + earned - spent - paid.

const START_CASH := 200
const LOAN := 200
## Total the house will lend. Placeholder until the credit-line design is settled
## (G: the loan is always available, within a limit; to be designed with later modes).
const LOAN_LIMIT := 1000
const BILLS := [5, 10, 20, 50, 100]
const BILL_TIME := 2.05          ## seconds from click to credit
const BILL_SOUND_AT := 0.16      ## share of the feed when the bill sound starts

var start_cash := START_CASH
var bills: Array = BILLS     ## what the bill slot takes (a stage scales them with its stake)
var cash := START_CASH
var credit := 0
var loans := 0
var spent := 0
var won := 0
var earned := 0      ## wages and other income that is not a prize
var paid := 0        ## repayments, fees, purchases: cash spent on anything but tickets
var opened := 0      ## tickets opened
var wins := 0        ## winning tickets opened
var bill := 0        ## value of the bill being fed, 0 when none
var bill_t := 0.0    ## 0..1 progress of the bill
var _bill_heard := false


func net() -> int:
	return won - spent


func balanced() -> bool:
	return cash + credit + bill == start_cash + loans + won + earned - spent - paid


func can_insert(value: int) -> bool:
	return bill == 0 and bills.has(value) and cash >= value


## Starts feeding a bill: the cash leaves now, the credit arrives later.
func insert(value: int) -> bool:
	if not can_insert(value):
		return false
	cash -= value
	bill = value
	bill_t = 0.0
	_bill_heard = false
	return true


## Advances the bill. Returns {"sound": true} when its sound should start and
## {"credited": value} when it lands in credit.
func step_bill(dt: float) -> Dictionary:
	var ev := {}
	if bill == 0:
		return ev
	bill_t = minf(1.0, bill_t + dt / BILL_TIME)
	if not _bill_heard and bill_t >= BILL_SOUND_AT:
		_bill_heard = true
		ev.sound = true
	if bill_t >= 1.0:
		credit += bill
		ev.credited = bill
		bill = 0
	return ev


## Pays for a ticket. Spending is recorded at purchase, so unopened tickets count.
func buy(price: int) -> bool:
	if credit < price:
		return false
	credit -= price
	spent += price
	return true


## A ticket was opened; its prize (maybe 0) goes straight to cash.
func open_ticket(prize: int) -> void:
	opened += 1
	if prize > 0:
		wins += 1
		won += prize
		cash += prize


## A prize that is not printed on a ticket (the last sale of a box): straight to cash.
func bonus(prize: int) -> void:
	won += prize
	cash += prize


## Income that is not a prize: wages.
func earn(amount: int) -> void:
	earned += amount
	cash += amount


## Cash spent on anything but tickets. False, changing nothing, if the cash is short.
func pay(amount: int) -> bool:
	if amount < 0 or cash < amount:
		return false
	cash -= amount
	paid += amount
	return true


func cash_out() -> int:
	var amount := credit
	cash += credit
	credit = 0
	return amount


## LOAN $200 is always offered, as long as it stays within the limit.
## (The web build only offered it when the player was stuck; G changed this.)
func loan_available() -> bool:
	return loans + LOAN <= LOAN_LIMIT


## How much more the house will lend.
func loan_left() -> int:
	return LOAN_LIMIT - loans


func take_loan() -> bool:
	if not loan_available():
		return false
	add_loan(LOAN)
	return true


## Borrowed money: cash now, never part of NET. Who lends how much is the caller's rule.
func add_loan(amount: int) -> void:
	cash += amount
	loans += amount


func to_dict() -> Dictionary:
	return {"cash": cash, "credit": credit, "loans": loans, "spent": spent, "won": won,
		"opened": opened, "wins": wins, "start_cash": start_cash, "earned": earned, "paid": paid}


func from_dict(d: Dictionary) -> void:
	for k in ["cash", "credit", "loans", "spent", "won", "opened", "wins", "start_cash", "earned", "paid"]:
		set(k, int(d.get(k, get(k))))
	bill = 0
	bill_t = 0.0
