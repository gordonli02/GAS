class_name TicketFlow
extends Node
## One ticket at a time: deal from the tray, flip, tear, reveal, toss to the pile.
## Owns the ticket's pose and turns pointer actions into flap pulls.
## Timings and poses follow the web build (MIGRATION.md "Ticket timing").

signal dealt(ticket: Dictionary, form: FormDef)
signal revealed(ticket: Dictionary, form: FormDef)
signal tossed

enum State { IDLE, DEAL, FRONT, FLIP, BACK, REVEALED, TOSS }

const DEAL_TIME := 0.42
const FLIP_TIME := 0.24
const TOSS_TIME := 0.34
const PAPER := Color("#f4f0e5")
const CONFETTI := [Color("#ffe14d"), Color("#ff4a3d"), Color("#62d2ff")]

var camera: CameraRig
var view: TicketView
var flecks: Flecks
var tray: Node3D             ## where tickets are dealt from
var pile: DiscardPile
## Returns the next ticket as {form: FormDef, ticket: Dictionary}, or {} when the tray is empty.
var next_ticket: Callable
## Asked after a toss lands: deal the next ticket straight away?
var deal_after_toss: Callable = func() -> bool: return true

var state := State.IDLE
var form: FormDef
var ticket: Dictionary
var pulse := 0.0
var _anim := 0.0
var _from := Transform3D.IDENTITY
var _to_pile := Vector3.ZERO
var _to_pile_basis := Basis.IDENTITY
var _drag := []              ## [{flap, dx, y, start, mode}] while the pointer holds flaps
var _band_start = null       ## card point where a band drag started, or null
var _band_mode := ""         ## "slide" / "split" once the band drag's direction is read
var _time := 0.0
var _busy := false


func has_ticket() -> bool:
	return state != State.IDLE


## A ticket has been taken from the tray and is being prepared to deal (state still IDLE).
func dealing() -> bool:
	return _busy


## The ticket in hand, for TableNav.
func hand() -> TableNav.Hand:
	match state:
		State.IDLE:
			return TableNav.Hand.NONE
		State.FRONT:
			return TableNav.Hand.FRONT
		State.BACK:
			return TableNav.Hand.OPENED if view.all_settled() else TableNav.Hand.BACK
		State.REVEALED:
			return TableNav.Hand.OPENED
	return TableNav.Hand.MOVING


func has_band() -> bool:
	return form != null and form.layout.band != null


## Puts the ticket in hand away untouched (it goes back to the tray).
func cancel() -> void:
	release()
	view.visible = false
	state = State.IDLE


## Space / Enter.
func primary() -> void:
	match state:
		State.IDLE:
			deal()
		State.FRONT:
			if view.band_on:
				view.break_band(BandRules.random_mode(view.band_breaks(), randf()), 1.0)
				_on_band_break()
			else:
				flip()
		State.BACK:
			if not _drag.is_empty():
				return
			for i in view.sims.size():
				var s := view.sims[i]
				if not s.open and not s.auto:
					if s.start_auto(randf() < 0.5):
						_on_break(i)
					return
		State.REVEALED:
			collect()


## Pointer pressed. Returns true if it grabbed paper.
func press(screen: Vector2) -> bool:
	match state:
		State.BACK:
			var from := camera.project_ray_origin(screen)
			var dir := camera.project_ray_normal(screen)
			var hit := view.flap_at(from, dir)
			if hit.is_empty() or view.sims[hit.flap].auto:
				return false
			var set := [hit.flap] if hit.mate < 0 else [hit.flap, hit.mate]
			_drag.clear()
			for i in set:
				var s := view.sims[i]
				var p: Vector2 = view.flap_point(i, from, dir)
				_drag.append({"flap": i, "dx": (2.0 * s.f - s.w) - p.x, "y": p.y, "start": p,
					"mode": FlapSim.drag_mode(Vector2.ZERO, _side_pull(i))})
				if hit.mate >= 0:
					s.grab(view.shared_edge_y(i, set[1] if i == set[0] else set[0]))
				else:
					s.grab(p.y)
			return true
		State.FRONT:
			if view.band_on:
				var from := camera.project_ray_origin(screen)
				var dir := camera.project_ray_normal(screen)
				if view.on_card(from, dir):
					_band_start = view.card_point(from, dir)
					_band_mode = ""
					return true
				return false
			flip()
		State.REVEALED:
			collect()
		State.IDLE:
			deal()
	return false


func move(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if _band_start != null:
		var p = view.card_point(from, dir)
		if p == null:
			return
		var delta: Vector2 = p - _band_start
		if _band_mode == "":
			_band_mode = BandRules.mode(delta, view.band_breaks())
		if view.drag_band(delta, _band_mode):
			_band_start = null
			_on_band_break()
		return
	if _drag.is_empty():
		return
	for it in _drag:
		var p = view.flap_point(it.flap, from, dir)
		if p == null:
			continue
		var s := view.sims[it.flap]
		if it.mode == "":
			it.mode = FlapSim.drag_mode(p - it.start, _side_pull(it.flap))
		if it.mode == "":
			continue
		var popped := s.side_pull_to((p - it.start).y) if it.mode == "side" else s.pull_to((p.x + it.dx + s.w) / 2.0, p.y - it.y)
		if popped:
			_on_break(it.flap)
			camera.shake = 0.18
			_fleck_burst(it.flap, 10)


func release() -> void:
	if _band_start != null:
		_band_start = null
		_band_mode = ""
		view.release_band()
	for it in _drag:
		view.sims[it.flap].release()
	_drag.clear()


## True when the pointer is over paper that can be grabbed.
func can_grab(screen: Vector2) -> bool:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if state == State.FRONT and view.band_on:
		return view.on_card(from, dir)
	if state != State.BACK:
		return false
	return not view.flap_at(from, dir).is_empty()


func deal() -> void:
	if _busy or state != State.IDLE:
		return
	var next: Dictionary = next_ticket.call()
	if next.is_empty():
		return
	_busy = true
	form = next.form
	ticket = next.ticket
	await view.use_form(form)
	await view.show_ticket(ticket)
	_busy = false
	_from = Transform3D(_flat_basis(), tray.global_position + Vector3(0, 0.4, 0))
	view.global_transform = _from
	view.visible = true
	_anim = 0.0
	state = State.DEAL
	Sfx.play("deal")
	dealt.emit(ticket, form)


## The card cannot turn over while its band is on.
func flip() -> void:
	if state != State.FRONT or view.band_on:
		return
	_anim = 0.0
	state = State.FLIP
	Sfx.play("flip")


func collect() -> void:
	if state != State.REVEALED:
		return
	_from = view.global_transform
	_to_pile = pile.next_spot()
	_to_pile_basis = pile.next_basis()
	_anim = 0.0
	state = State.TOSS
	Sfx.play("flip")


func _process(dt: float) -> void:
	_time += dt
	pulse *= exp(-dt * 5.5)
	if state == State.BACK:
		_step_paper(dt)
	if state == State.IDLE:
		return
	var open := view.max_open()
	var hold := camera.hold_pose(view.size)
	var up := hold.basis.y
	var right := hold.basis.x
	var slide: Array = form.layout.reveal_slide
	var target: Vector3 = hold.origin + up * sin(_time * 1.6) * 0.012 \
		+ right * float(slide[0]) * open * view.size.x + up * float(slide[1]) * open * view.size.y
	var held := not _drag.is_empty() or _band_start != null
	var m := camera.mouse
	var tilt := Basis.from_euler(Vector3(-0.07 + (0.0 if held else m.y * 0.05), 0.0 if held else m.x * 0.09, 0.03 * (1.0 - open)), EULER_ORDER_XYZ)
	var facing := hold.basis * tilt
	var turned := facing * Basis(Vector3.UP, PI)
	var sc := Vector3.ONE * (1.0 + pulse * 0.06)
	match state:
		State.DEAL:
			_anim = minf(1.0, _anim + dt / DEAL_TIME)
			var t := _ease(_anim)
			var pos := _from.origin.lerp(target, t) + Vector3(0, sin(t * PI) * 0.5, 0)
			var q := _from.basis.get_rotation_quaternion().slerp(turned.get_rotation_quaternion(), t)
			view.global_transform = Transform3D(Basis(q).scaled(sc), pos)
			if _anim >= 1.0:
				state = State.FRONT
		State.FRONT:
			view.global_transform = Transform3D(turned.scaled(sc), target)
		State.FLIP:
			_anim = minf(1.0, _anim + dt / FLIP_TIME)
			var t := _ease(_anim)
			view.global_transform = Transform3D((facing * Basis(Vector3.UP, PI * (1.0 - t))).scaled(sc), target)
			if _anim >= 1.0:
				state = State.BACK
		State.BACK, State.REVEALED:
			view.global_transform = Transform3D(facing.scaled(sc), target)
		State.TOSS:
			_anim = minf(1.0, _anim + dt / TOSS_TIME)
			var t := _ease(_anim)
			var pos := _from.origin.lerp(_to_pile, t) + Vector3(0, sin(t * PI) * 0.8, 0)
			var q := _from.basis.get_rotation_quaternion().slerp(_to_pile_basis.get_rotation_quaternion(), t)
			view.global_transform = Transform3D(Basis(q), pos)
			if _anim >= 1.0:
				view.visible = false
				pile.land(form, _to_pile)
				Sfx.play("toss")
				state = State.IDLE
				tossed.emit()
				if deal_after_toss.call():
					deal()


func _step_paper(dt: float) -> void:
	var held := []
	for it in _drag:
		held.append(it.flap)
	for ev in view.step(dt, held):
		if ev.type == "slice":
			var s := view.sims[ev.flap]
			var clips := _clips()
			if s.tear_clip < 0 and not clips.is_empty():
				s.tear_clip = randi() % clips.size()
			if s.tear_clip >= 0:
				Sfx.play_tear_slice(clips[s.tear_clip], ev.from, ev.to, FlapSim.STEPS)
			_fleck_burst(ev.flap, 2)
			camera.shake = maxf(camera.shake, 0.05)
	if view.all_settled():
		_reveal()


func _reveal() -> void:
	state = State.REVEALED
	_drag.clear()
	if ticket.prize > 0:
		pulse = 1.0
		camera.shake = 1.0 if ticket.prize >= 100 else 0.35
		Sfx.play_win(ticket.prize)
		var n := mini(100, 18 + ticket.prize * 2)
		for c in CONFETTI:
			flecks.emit(view.global_position, c, 3.4, roundi(n / 3.0))
	revealed.emit(ticket, form)


## The band snaps: a short rip (its first crackles), a jolt and coloured flecks.
func _on_band_break() -> void:
	camera.shake = 0.2
	var clips := _clips()
	if clips.is_empty():
		Sfx.play("pop")
	else:
		var c: Dictionary = clips[randi() % clips.size()]
		Sfx.play_tear_span(c, 0.0, c.marks[mini(2, c.marks.size() - 1)])
	var color := PAPER
	for cmd in TicketArt.band(form).cmds:
		if cmd.k == "poly":
			color = cmd.color
			break
	flecks.emit(view.global_position, color, 1.8, 10)


## The first break: with recorded rips the crackles carry the sound, so the
## break itself is silent (as in the web build); otherwise play the synth pop.
func _on_break(_flap: int) -> void:
	Sfx.play_break(not _clips().is_empty())


## Whether the layout lets this flap open with a sideways swipe.
func _side_pull(flap: int) -> bool:
	return bool(form.layout.flaps[flap].get("side_pull", false))


func _clips() -> Array:
	return form.tear_clips if not form.tear_clips.is_empty() else Packs.tear_clips_for(form)


func _fleck_burst(flap: int, n: int) -> void:
	flecks.emit(view.flap_edge_world(flap, 1.0 if randf() > 0.5 else -1.0), PAPER, 1.7, n)


## Lying face up on the table.
static func _flat_basis() -> Basis:
	return Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI / 2.0)


static func _ease(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
