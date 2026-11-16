extends Node2D

## The wizard's death (2026-11-16, user: "let the wizard die spectacularly
## in multiple lightning strikes and an explosion. Then nothing for 5s.
## Only after the pause is the wedding declared.")
##
## Wizard.die() drops this at his feet and calls play(wizard). The sky
## answers the man who stole its lightning: STRIKES bolts come down on him,
## faster and faster, each one lighting him white; the last three land
## together. Then he bursts: a violet fireball, a white screen flash, a
## shockwave ring, his robes and gold torn into shards, the camera shaking.
## A scorch stays on the ground. The wizard is freed at the burst.
##
## GameManager.on_wizard_slain waits DURATION, then 5 silent seconds,
## before the wedding is declared. Pure spectacle: it damages nothing.
## No class_name on purpose (editor rescan caveat): Wizard.gd preloads it.

## The strike gaps, accelerating; after the last gap, three bolts at once.
const STRIKE_GAPS: Array[float] = [0.0, 0.42, 0.36, 0.3, 0.24, 0.18, 0.13, 0.1]
const TRIPLE_GAP := 0.16
const BOOM_DELAY := 0.35          # held breath between the triple and the burst
const BOOM_TIME := 1.1            # fireball + ring + shards play out
## Start of play() to the end of the burst (GameManager adds the 5 s).
const DURATION := 3.6

const BOLT_WHITE := Color(0.88, 0.95, 1.0)
const BOLT_GLOW := Color(0.55, 0.72, 1.0, 0.4)
const VIOLET := Color(0.62, 0.32, 0.95)
const ROBE := Color(0.46, 0.26, 0.56)
const GOLD := Color(1.0, 0.82, 0.38)

var _victim: Node2D

func play(victim: Node2D) -> void:
	_victim = victim
	z_index = 60
	for gap: float in STRIKE_GAPS:
		if gap > 0.0:
			await get_tree().create_timer(gap).timeout
		_strike()
	await get_tree().create_timer(TRIPLE_GAP).timeout
	for i in 3:
		_strike()
	_charge_glow()
	await get_tree().create_timer(BOOM_DELAY).timeout
	_explode()
	await get_tree().create_timer(BOOM_TIME + 20.0).timeout   # the scorch lingers
	queue_free()

# --- the strikes ------------------------------------------------------------------

func _target() -> Vector2:
	if _victim != null and is_instance_valid(_victim):
		return _victim.global_position + Vector2(0.0, -14.0)
	return global_position + Vector2(0.0, -14.0)

func _strike() -> void:
	var hit := _target()
	var from := hit + Vector2(randf_range(-110.0, 110.0), -520.0)
	var pts := PackedVector2Array()
	var n := 12
	var normal := (hit - from).normalized().orthogonal()
	for i in n + 1:
		var t := float(i) / float(n)
		var p := from.lerp(hit, t)
		if i > 0 and i < n:
			p += normal * randf_range(-16.0, 16.0)
		pts.append(to_local(p))
	var bolt := Node2D.new()
	add_child(bolt)
	for spec: Array in [[16.0, BOLT_GLOW], [4.0, BOLT_WHITE]]:
		var line := Line2D.new()
		line.points = pts
		line.width = spec[0]
		line.default_color = spec[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		bolt.add_child(line)
	# a forked branch off the main bolt
	var k := randi_range(4, 8)
	var branch := Line2D.new()
	branch.width = 2.0
	branch.default_color = BOLT_WHITE
	var b0 := pts[k]
	branch.points = PackedVector2Array([b0, b0 + Vector2(randf_range(-40, 40), randf_range(20, 50)),
		b0 + Vector2(randf_range(-70, 70), randf_range(50, 90))])
	bolt.add_child(branch)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.22).set_delay(0.06)
	tw.tween_callback(bolt.queue_free)
	# where it lands: a white burst on the ground
	_ring(to_local(hit + Vector2(0.0, 14.0)), 6.0, 46.0, 0.3, BOLT_WHITE, 3.0)
	_flash_disc(to_local(hit), 18.0, Color(0.8, 0.9, 1.0, 0.8), 0.18)
	# the wizard lights up and jolts
	if _victim != null and is_instance_valid(_victim):
		_victim.modulate = Color(2.6, 2.8, 3.4)
		var vt := _victim.create_tween()
		vt.tween_property(_victim, "modulate", Color(0.7, 0.6, 0.95), 0.14)
		_victim.position += Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 1.0))
	_shake(3.0, 0.12)

func _charge_glow() -> void:
	# the last of the stolen lightning boils out of him
	_flash_disc(to_local(_target()), 34.0, Color(VIOLET, 0.75), BOOM_DELAY + 0.05, 1.6)

# --- the burst ------------------------------------------------------------------

func _explode() -> void:
	var c := to_local(_target())
	# scorch (stays a while, then fades)
	var scorch := _disc(to_local(_target() + Vector2(0.0, 14.0)), 52.0, Color(0.06, 0.04, 0.07, 0.75), Vector2(1.0, 0.45))
	scorch.z_index = -1
	scorch.create_tween().tween_property(scorch, "modulate:a", 0.0, 6.0).set_delay(14.0)
	# fireball: white core inside a violet bloom
	_flash_disc(c, 26.0, Color(1.0, 0.97, 1.0, 1.0), 0.45, 3.4)
	_flash_disc(c, 40.0, Color(VIOLET, 0.85), 0.9, 3.0)
	# two shockwave rings
	_ring(c, 12.0, 240.0, 0.8, Color(0.85, 0.75, 1.0), 7.0)
	_ring(c + Vector2(0.0, 14.0), 8.0, 170.0, 1.0, Color(VIOLET, 0.8), 4.0, Vector2(1.0, 0.5))
	# shards of robe and gold, sparks
	for i in 26:
		var col: Color = [ROBE, VIOLET, GOLD, BOLT_WHITE][i % 4]
		_shard(c, col)
	# the man is gone
	if _victim != null and is_instance_valid(_victim):
		_victim.queue_free()
	_screen_flash()
	_shake(10.0, 0.7)
	print("The wizard bursts in a storm of violet fire!")

func _shard(c: Vector2, col: Color) -> void:
	var p := Polygon2D.new()
	var s := randf_range(2.0, 5.5)
	p.polygon = PackedVector2Array([Vector2(-s, 0), Vector2(0, -s * 0.6), Vector2(s, 0.3), Vector2(0, s * 0.5)])
	p.color = col
	p.position = c
	p.rotation = randf() * TAU
	add_child(p)
	var dir := Vector2.from_angle(randf() * TAU)
	var dist := randf_range(60.0, 190.0)
	var t := randf_range(0.6, BOOM_TIME)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "position", c + dir * dist + Vector2(0.0, randf_range(10.0, 40.0)), t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "rotation", p.rotation + randf_range(-9.0, 9.0), t)
	tw.tween_property(p, "modulate:a", 0.0, t * 0.6).set_delay(t * 0.4)
	tw.chain().tween_callback(p.queue_free)

# --- pieces -----------------------------------------------------------------------

func _disc(c: Vector2, r: float, col: Color, squash := Vector2.ONE) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 28:
		pts.append(Vector2.from_angle(TAU * i / 28.0) * r * squash)
	p.polygon = pts
	p.color = col
	p.position = c
	add_child(p)
	return p

func _flash_disc(c: Vector2, r: float, col: Color, life: float, grow := 1.3) -> void:
	var d := _disc(c, r, col)
	var tw := d.create_tween().set_parallel(true)
	tw.tween_property(d, "scale", Vector2(grow, grow), life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "modulate:a", 0.0, life)
	tw.chain().tween_callback(d.queue_free)

func _ring(c: Vector2, r0: float, r1: float, life: float, col: Color, width: float, squash := Vector2.ONE) -> void:
	var line := Line2D.new()
	line.default_color = col
	line.position = c
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(line)
	# redrawn at its true radius each step: the width stays in pixels
	var draw := func(k: float) -> void:
		var e := 1.0 - pow(2.0, -10.0 * k)          # expo ease-out
		var r := lerpf(r0, r1, e)
		var pts := PackedVector2Array()
		for i in 49:
			pts.append(Vector2.from_angle(TAU * i / 48.0) * r * squash)
		line.points = pts
		line.width = lerpf(width, width * 0.25, k)
		line.modulate.a = 1.0 - k * k
	draw.call(0.0)
	var tw := line.create_tween()
	tw.tween_method(draw, 0.0, 1.0, life)
	tw.tween_callback(line.queue_free)

func _screen_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 3   # over the world and the grade, under menus
	var rect := ColorRect.new()
	rect.color = Color(0.95, 0.9, 1.0, 0.85)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)

func _shake(px: float, life: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := cam.create_tween()
	var steps := int(life / 0.04)
	for i in steps:
		var k := 1.0 - float(i) / float(steps)
		tw.tween_property(cam, "offset", Vector2(randf_range(-px, px), randf_range(-px, px)) * k, 0.04)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.04)
