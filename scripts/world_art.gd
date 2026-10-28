extends Node2D
## Original, resolution-independent pixel scenery and articulated characters.
## Coordinates are authored for the game's 1280 x 720 canvas.

var scene_mode: String = "title"
var time: float = 0.0
var encounter: int = 0
var hero_action: String = "idle"
var hero_action_progress: float = 0.0
var target_index: int = 0
var enemies_data: Array = []
var camera_impact: float = 0.0
var selected_enemy: int = 0
var weather: bool = true

const INK := Color("09141d")
const GOLD := Color("e3bc71")
const CYAN := Color("7ad9dc")
const CREAM := Color("f4dfac")

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func hero_position() -> Vector2:
	if scene_mode == "title":
		return Vector2(960, 490)
	return Vector2(310, 438)

func enemy_position(index: int) -> Vector2:
	if encounter >= 3:
		return Vector2(910 if index == 0 else 1130, 438)
	return Vector2(755 + index * 195, 438)

func _draw() -> void:
	var shake := Vector2(sin(time * 91.0), cos(time * 73.0)) * camera_impact
	draw_set_transform(shake)
	_sky()
	_mountains()
	_station()
	_ground()
	_ambience(false)
	if scene_mode == "title":
		_hero(hero_position(), 2.9)
	elif scene_mode == "battle":
		for i in range(enemies_data.size()):
			var data: Dictionary = enemies_data[i]
			if int(data.get("hp", 0)) > 0:
				_enemy(enemy_position(i), data, i)
		_hero(hero_position(), 2.35)
	else:
		_hero(Vector2(330, 438), 2.35)
		if scene_mode == "dialogue" or scene_mode == "story":
			_lyra(Vector2(540, 432))
	_ambience(true)
	draw_set_transform(Vector2.ZERO)
	# Vignette: keep the painted world legible beneath interface panels.
	for i in range(10):
		var alpha := float(10 - i) * 0.004
		draw_rect(Rect2(0, i * 7, 1280, 7), Color(0.015, 0.035, 0.055, alpha * 5))
		draw_rect(Rect2(0, 650 + i * 7, 1280, 7), Color(0.015, 0.035, 0.055, alpha * 8))

func _sky() -> void:
	var top := Color("08141f")
	var bottom := Color("294c57") if encounter < 3 else Color("443641")
	for i in range(95):
		draw_rect(Rect2(0, i * 6, 1280, 7), top.lerp(bottom, float(i) / 95.0))
	# The shattered moon is the campaign's central landmark.
	var moon := Vector2(917, 171)
	draw_circle(moon, 87, Color(0.38, 0.76, 0.77, 0.025))
	draw_circle(moon, 71, Color(0.43, 0.82, 0.81, 0.04))
	draw_circle(moon, 57, Color("b2c8b2"))
	draw_circle(moon + Vector2(-18, -18), 48, Color("172d3b"))
	_poly([Vector2(917, 113), Vector2(926, 147), Vector2(909, 171), Vector2(925, 186), Vector2(920, 228), Vector2(935, 187), Vector2(922, 171), Vector2(935, 148)], Color("152b36"))
	for i in range(95):
		var x := fmod(i * 137.71 + 21.0, 1280.0)
		var y := fmod(i * 57.93 + 13.0, 330.0)
		var a := 0.16 + (sin(time * 0.7 + i * 2.3) + 1.0) * 0.18
		draw_rect(Rect2(x, y, 2 if i % 7 else 3, 2 if i % 7 else 3), Color(0.75, 0.87, 0.91, a))
	# Soft celestial ribbons.
	for row in range(5):
		var points := PackedVector2Array()
		for n in range(33):
			var x := n * 42.0
			points.append(Vector2(x, 127 + sin(x * 0.003 + row * 0.13 + time * 0.03) * 40 + row * 6))
		draw_polyline(points, Color(0.23, 0.63, 0.65, 0.035), 9)

func _mountains() -> void:
	_poly([Vector2(0, 350), Vector2(0, 270), Vector2(75, 245), Vector2(130, 263), Vector2(206, 199), Vector2(276, 260), Vector2(345, 230), Vector2(415, 278), Vector2(490, 227), Vector2(580, 262), Vector2(670, 218), Vector2(750, 284), Vector2(829, 250), Vector2(900, 276), Vector2(1022, 215), Vector2(1125, 267), Vector2(1180, 244), Vector2(1280, 272), Vector2(1280, 400)], Color("1b3542"))
	_poly([Vector2(0, 413), Vector2(0, 337), Vector2(125, 315), Vector2(201, 339), Vector2(285, 289), Vector2(347, 342), Vector2(405, 306), Vector2(461, 326), Vector2(515, 302), Vector2(599, 348), Vector2(685, 288), Vector2(760, 340), Vector2(850, 315), Vector2(952, 335), Vector2(1031, 294), Vector2(1125, 325), Vector2(1200, 305), Vector2(1280, 327), Vector2(1280, 440)], Color("142b36"))
	# Sleeping city, with a handful of warm windows surviving the fracture.
	for i in range(37):
		var x := i * 37.0 - 10
		var h := 25.0 + fmod(i * 31.7, 87.0)
		draw_rect(Rect2(x, 363 - h, 25 + i % 3 * 3, h), Color("17303a"))
		if i % 3 == 0:
			draw_rect(Rect2(x + 7, 375 - h, 3, 5), Color(0.86, 0.67, 0.32, 0.4))
	for row in range(8):
		var y := 343 + row * 9.0
		var sway := sin(time * 0.11 + row) * 20
		draw_rect(Rect2(-50 + sway, y, 1380, 3), Color(0.4, 0.69, 0.73, 0.025))

func _station() -> void:
	# Distant broken rail viaduct.
	draw_rect(Rect2(0, 350, 1280, 9), Color("0d2530"))
	draw_line(Vector2(0, 348), Vector2(1280, 348), Color("46616a"), 2)
	for i in range(12):
		draw_rect(Rect2(i * 118 + 30, 357, 17, 92), Color("102630"))
		draw_line(Vector2(i * 118 + 47, 363), Vector2(i * 118 + 100, 412), Color("102630"), 10)
	# Left abandoned station canopy.
	draw_rect(Rect2(55, 190, 10, 222), Color("10212a"))
	draw_rect(Rect2(202, 190, 8, 223), Color("142630"))
	_poly([Vector2(-20, 183), Vector2(180, 149), Vector2(306, 174), Vector2(270, 190), Vector2(0, 203)], Color("122731"))
	draw_line(Vector2(0, 182), Vector2(181, 151), Color("3f5053"), 3)
	draw_line(Vector2(180, 151), Vector2(306, 174), Color("495555"), 2)
	for i in range(6):
		draw_line(Vector2(i * 49, 181 - i * 3), Vector2(33 + i * 41, 198 - i * 2), Color("263a40"), 2)
	# Hanging signal clock.
	draw_line(Vector2(232, 182), Vector2(232, 225), Color("223b43"), 2)
	draw_circle(Vector2(232, 232), 18, Color("506568"))
	draw_circle(Vector2(232, 232), 15, Color("162e36"))
	draw_line(Vector2(232, 232), Vector2(231, 221), GOLD.darkened(0.25), 2)
	draw_line(Vector2(232, 232), Vector2(242, 236), GOLD.darkened(0.25), 2)
	# Rail signal, providing a warm pool beside the hero.
	var lamp_x := 424.0
	draw_rect(Rect2(lamp_x, 256, 6, 155), Color("16252b"))
	draw_rect(Rect2(lamp_x - 8, 247, 22, 36), Color("344345"))
	draw_rect(Rect2(lamp_x - 4, 252, 14, 25), Color("c59b56"))
	draw_rect(Rect2(lamp_x - 1, 255, 8, 19), Color("f2d79a"))
	for i in range(7):
		draw_circle(Vector2(lamp_x + 3, 266), 19 + i * 6, Color(1.0, 0.75, 0.36, 0.014))
	# A massive fractured gateway on the right of the arena.
	var tint := Color("7cc8c9") if encounter < 3 else Color("f58c6b")
	for i in range(5):
		draw_arc(Vector2(1090, 333), 140 + i * 5, PI * 1.03, PI * 1.97, 45, Color(tint, 0.015 * (5 - i)), 4)
	_poly([Vector2(968, 399), Vector2(961, 293), Vector2(980, 239), Vector2(1011, 211), Vector2(1025, 224), Vector2(999, 254), Vector2(985, 298), Vector2(992, 403)], Color("243d45"))
	_poly([Vector2(1177, 396), Vector2(1186, 303), Vector2(1168, 249), Vector2(1141, 216), Vector2(1160, 209), Vector2(1194, 243), Vector2(1213, 303), Vector2(1205, 399)], Color("263c43"))
	draw_line(Vector2(980, 294), Vector2(993, 256), Color(tint, 0.6), 3)
	draw_line(Vector2(1193, 298), Vector2(1178, 255), Color(tint, 0.6), 3)
	var shard := Vector2(1090 + sin(time * 0.3) * 4, 211 + sin(time * 0.8) * 8)
	_poly([shard + Vector2(-14, -19), shard + Vector2(24, -9), shard + Vector2(8, 16), shard + Vector2(-23, 7)], Color("31515a"))
	draw_line(shard + Vector2(-17, 4), shard + Vector2(14, -5), Color(tint, 0.8), 2)
	if encounter >= 3:
		for i in range(12):
			var y := 238 + i * 13
			draw_rect(Rect2(1016, y, 150, 2), Color(0.85, 0.33, 0.23, 0.04 + sin(time + i) * 0.025))

func _ground() -> void:
	_poly([Vector2(0, 420), Vector2(1280, 408), Vector2(1280, 720), Vector2(0, 720)], Color("162a32"))
	draw_rect(Rect2(0, 420, 1280, 6), Color("627272"))
	draw_rect(Rect2(0, 426, 1280, 3), Color("2c4145"))
	for i in range(35):
		var x := i * 39.0
		draw_line(Vector2(x, 430), Vector2(x - 37, 531), Color("263c43"), 2)
	for i in range(5):
		draw_line(Vector2(0, 438 + i * 25), Vector2(1280, 438 + i * 25), Color("1b3038"), 2)
	# Reflections across the rain-polished platform.
	for i in range(30):
		var x := fmod(i * 113.39, 1280.0)
		var y := 444 + fmod(i * 21.7, 85.0)
		draw_line(Vector2(x, y), Vector2(x + 25 + i % 5 * 10, y), Color(0.5, 0.7, 0.71, 0.045), 2)
	for i in range(9):
		draw_line(Vector2(404 - i * 2, 441 + i * 7), Vector2(441 + i * 2, 441 + i * 7), Color(0.9, 0.66, 0.3, 0.075 - i * 0.006), 2)
	# Foreground rail bed and individual golden ties.
	draw_rect(Rect2(0, 536, 1280, 64), Color("0d1d26"))
	for i in range(22):
		var x := i * 67.0 - 80
		_poly([Vector2(x, 539), Vector2(x + 15, 539), Vector2(x - 28, 592), Vector2(x - 46, 592)], Color("26383b"))
	draw_line(Vector2(0, 545), Vector2(1280, 545), Color("71817d"), 3)
	draw_line(Vector2(0, 548), Vector2(1280, 548), Color("31464a"), 5)
	draw_line(Vector2(0, 584), Vector2(1280, 584), Color("53676b"), 3)
	draw_line(Vector2(0, 588), Vector2(1280, 588), Color("172a32"), 5)
	draw_rect(Rect2(0, 599, 1280, 121), Color("10212a"))
	# Windblown grass at the platform edge.
	for i in range(11):
		var x := fmod(i * 187.3 + 7, 1280.0)
		for blade in range(4):
			var sway := sin(time * 1.3 + i + blade * 0.3) * 3
			draw_line(Vector2(x + blade * 3, 422), Vector2(x + blade * 3 - 5 + sway, 408 - blade % 2 * 7), Color("537067"), 2)

func _ambience(front: bool) -> void:
	if not weather:
		return
	for i in range(27 if front else 45):
		var speed := 6.0 + i % 6 * 2
		var x := fposmod(i * 87.13 + time * speed, 1320) - 20
		var y := fposmod(i * 57.9 + sin(time * 0.4 + i) * 10, 520)
		var a := 0.12 + (sin(time + i * 1.4) + 1.0) * 0.15
		var color := Color(0.95, 0.75, 0.38, a) if front else Color(0.55, 0.85, 0.87, a * 0.45)
		draw_rect(Rect2(x, y, 2 if front else 1, 2 if front else 1), color)
		if i % 8 == 0 and front:
			draw_circle(Vector2(x + 1, y + 1), 5, Color(color, 0.035))

func _hero(base: Vector2, character_scale: float) -> void:
	var p := clampf(hero_action_progress, 0, 1)
	var moving := hero_action in ["basic", "skill", "ultimate"] and p > 0 and p < 1
	var reach := sin(p * PI) if moving else 0.0
	var lunge := 0.0
	if moving and scene_mode == "battle":
		lunge = (enemy_position(target_index).x - base.x - 90) * sin(p * PI)
	var pos := base + Vector2(lunge, 0)
	draw_set_transform(pos, 0, Vector2(character_scale, character_scale))
	_ellipse(Vector2(0, 1), Vector2(23, 4), Color(0.01, 0.02, 0.025, 0.42))
	var breath := sin(time * 2.0) * 0.55
	var flutter := sin(time * 2.8) * 2.3
	var lean := reach * 8
	# Motion echoes and blade arcs use only a handful of crisp segments.
	if moving and p > 0.25 and p < 0.82:
		for i in range(4):
			draw_line(Vector2(-25 - i * 8, -37 + i * 5), Vector2(-8 - i * 8, -37 + i * 5), Color(0.91, 0.71, 0.35, 0.18 - i * 0.03), 1)
	# Cape: dark outline, warm folds, ragged hem.
	_poly([Vector2(-10 + lean, -51 + breath), Vector2(-19, -43), Vector2(-21 - flutter - reach * 12, -22), Vector2(-30 - flutter - reach * 15, -8), Vector2(-21, -10), Vector2(-23, -4), Vector2(-13, -8), Vector2(-12, -3), Vector2(-5, -10), Vector2(5 + lean, -42)], Color("201c19"))
	_poly([Vector2(-10 + lean, -48 + breath), Vector2(-17, -40), Vector2(-19 - flutter - reach * 12, -22), Vector2(-25 - flutter - reach * 15, -11), Vector2(-16, -15), Vector2(-18, -8), Vector2(-8, -13), Vector2(1 + lean, -42)], Color("6a472b"))
	_poly([Vector2(-13, -43), Vector2(-17, -23), Vector2(-23 - flutter, -14), Vector2(-15, -16), Vector2(-6, -42)], Color("8a5e36"))
	_poly([Vector2(-5, -39), Vector2(-14, -10), Vector2(-8, -14), Vector2(2, -40)], Color("463522"))
	# Legs and knee armour.
	var step := reach * 10
	_limb(Vector2(-5 + lean, -23), Vector2(-10 - step, -13), Vector2(-11 - step, -3), Color("232a29"), 7)
	_limb(Vector2(6 + lean, -22), Vector2(9 + step, -13), Vector2(12 + step, -3), Color("30342e"), 7)
	_rect(-15 - step, -6, 10, 5, "151c1c")
	_rect(8 + step, -6, 12, 5, "151c1c")
	_rect(-12 - step, -7, 6, 2, "7a6d4c")
	_rect(9 + step, -7, 7, 2, "7a6d4c")
	_rect(-13 - step, -15, 7, 3, "454b3d")
	_rect(6 + step, -15, 7, 3, "535747")
	draw_set_transform(pos + Vector2(lean, breath) * character_scale, 0, Vector2(character_scale, character_scale))
	# Tunic / brass buckles / crossed harness.
	_poly([Vector2(-10, -49), Vector2(8, -49), Vector2(13, -36), Vector2(10, -21), Vector2(-10, -22), Vector2(-13, -37)], Color("131c1e"))
	_poly([Vector2(-6, -46), Vector2(7, -46), Vector2(9, -26), Vector2(-7, -26)], Color("30322a"))
	_rect(-2, -46, 3, 24, "63513a")
	draw_line(Vector2(-9, -44), Vector2(8, -29), Color("907149"), 2)
	_rect(-11, -28, 23, 4, "151a18")
	_rect(-10, -27, 20, 2, "876941")
	_rect(0, -28, 4, 4, "d3ad63")
	_rect(1, -27, 2, 2, "3a352a")
	_rect(-9, -25, 4, 7, "5c4830")
	_rect(6, -25, 4, 6, "7a5c37")
	# Fur mantle, jagged collar and single steel shoulder plate.
	_poly([Vector2(-12, -49), Vector2(-8, -53), Vector2(-5, -50), Vector2(-2, -53), Vector2(2, -51), Vector2(6, -53), Vector2(12, -49), Vector2(10, -43), Vector2(6, -45), Vector2(4, -41), Vector2(0, -46), Vector2(-4, -43), Vector2(-6, -46), Vector2(-11, -44)], Color("b7a47b"))
	_poly([Vector2(-13, -48), Vector2(-9, -51), Vector2(-4, -48), Vector2(-5, -42), Vector2(-10, -40), Vector2(-15, -43)], Color("607a83"))
	draw_line(Vector2(-13, -47), Vector2(-7, -49), Color("b2c3be"), 2)
	_rect(-12, -43, 3, 2, "8ba2a3")
	# Neck, face and blonde pixel locks, facing right.
	_rect(-1, -56, 7, 7, "a77343")
	_poly([Vector2(-5, -66), Vector2(6, -67), Vector2(10, -62), Vector2(9, -58), Vector2(12, -57), Vector2(9, -55), Vector2(8, -51), Vector2(2, -50), Vector2(-4, -55)], Color("d0a36b"))
	_rect(3, -61, 5, 6, "edc389")
	_rect(7, -59, 3, 2, "3e382a")
	_rect(8, -59, 1, 1, "9ce0dc")
	_rect(5, -53, 3, 1, "7c5336")
	_poly([Vector2(-8, -63), Vector2(-10, -67), Vector2(-5, -67), Vector2(-7, -71), Vector2(-1, -69), Vector2(3, -74), Vector2(5, -70), Vector2(11, -71), Vector2(10, -67), Vector2(14, -66), Vector2(10, -64), Vector2(11, -61), Vector2(7, -63), Vector2(5, -59), Vector2(4, -64), Vector2(1, -62), Vector2(0, -57), Vector2(-3, -60), Vector2(-4, -54), Vector2(-7, -57)], Color("7f552e"))
	_poly([Vector2(-7, -65), Vector2(-4, -68), Vector2(0, -67), Vector2(3, -71), Vector2(5, -67), Vector2(10, -68), Vector2(8, -65), Vector2(11, -64), Vector2(7, -64), Vector2(5, -61), Vector2(4, -66), Vector2(0, -64), Vector2(-1, -60), Vector2(-4, -63), Vector2(-5, -58), Vector2(-7, -60)], Color("dfb461"))
	_rect(-3, -67, 3, 2, "f6d68a")
	_rect(3, -69, 2, 3, "ffdfa0")
	_rect(6, -66, 3, 1, "f8d787")
	_rect(-5, -63, 2, 4, "f4ca77")
	# Left arm and leather gauntlet.
	_limb(Vector2(-11, -43), Vector2(-15, -33), Vector2(-12, -26), Color("34362d"), 5)
	_rect(-16, -33, 5, 6, "806644")
	_rect(-15, -28, 4, 3, "d2a66b")
	# Sword arm anticipates, strikes, then returns to guard.
	var hand := Vector2(14, -30)
	var sword_angle := -0.45
	if moving:
		hand = Vector2(12 + reach * 15, -34 - sin(p * PI * 2) * 10)
		sword_angle = lerpf(-2.4, 0.9, p)
	elif hero_action == "guard":
		hand = Vector2(15, -41)
		sword_angle = -1.8
	elif hero_action == "hurt":
		hand = Vector2(9, -31)
	_limb(Vector2(9, -44), Vector2(16, -37), hand, Color("4d4734"), 5)
	draw_rect(Rect2(hand - Vector2(2, 2), Vector2(5, 4)), Color("d4ab70"))
	# Silver sword, bronze crossguard, four-layer blade taper.
	draw_set_transform(pos + (hand + Vector2(lean, breath)) * character_scale, sword_angle, Vector2(character_scale, character_scale))
	_rect(-4, -1, 11, 3, "3a2d22")
	_rect(2, -5, 3, 10, "c3a05d")
	_poly([Vector2(5, -2), Vector2(34, -2), Vector2(42, 0), Vector2(34, 2), Vector2(5, 2)], Color("8faaa9"))
	_poly([Vector2(5, -2), Vector2(34, -2), Vector2(42, 0), Vector2(5, 0)], Color("e3e3c9"))
	draw_set_transform(pos, 0, Vector2(character_scale, character_scale))
	if moving and p > 0.25 and p < 0.85:
		var arc_color := CREAM if hero_action == "basic" else CYAN
		for i in range(3):
			draw_arc(Vector2(20, -36), 33 + i * 4, -1.9 + p * 1.9, 0.2 + p * 1.9, 14, Color(arc_color, 0.8 - i * 0.23), 2.5 - i * 0.6)
		if hero_action == "ultimate":
			for i in range(8):
				var angle := i * TAU / 8 + p * 6
				draw_line(Vector2(20, -35) + Vector2.from_angle(angle) * 42, Vector2(20, -35) + Vector2.from_angle(angle) * 60, Color(GOLD, 0.7), 2)
	if hero_action == "guard":
		draw_arc(Vector2(9, -32), 34, -1.25, 1.25, 18, Color(CYAN, 0.65), 2)
	draw_set_transform(Vector2.ZERO)

func _enemy(pos: Vector2, data: Dictionary, index: int) -> void:
	var kind := str(data.get("kind", "shade"))
	var is_boss := kind in ["boss", "warden", "sentinel", "regent"] or (encounter >= 3 and index == 0)
	var broken := bool(data.get("broken", false))
	var glow := Color("f2a875") if is_boss else CYAN
	if broken:
		glow = Color("6b7c85")
	if index == selected_enemy:
		_ellipse(pos + Vector2(0, 4), Vector2(50 if is_boss else 31, 8), Color(GOLD, 0.12 + sin(time * 4) * 0.03))
		draw_arc(pos + Vector2(0, 2), 32 if not is_boss else 48, 0.1, PI - 0.1, 22, Color(GOLD, 0.65), 2)
	_ellipse(pos + Vector2(0, 3), Vector2(37 if is_boss else 25, 6), Color(0.005, 0.015, 0.02, 0.5))
	var bob := sin(time * 1.7 + index * 1.8) * 4
	draw_set_transform(pos + Vector2(0, bob), 0, Vector2(2.5, 2.5) if is_boss else Vector2(2.2, 2.2))
	if is_boss:
		_boss(glow, broken)
	else:
		_shade(glow, broken, index)
	draw_set_transform(Vector2.ZERO)

func _shade(glow: Color, broken: bool, index: int) -> void:
	var sway := sin(time * 2 + index) * 3
	_poly([Vector2(-8, -51), Vector2(7, -51), Vector2(13, -38), Vector2(9, -15), Vector2(18 + sway, -2), Vector2(8, -7), Vector2(1, -1), Vector2(-4, -7), Vector2(-14 + sway, -3), Vector2(-9, -17), Vector2(-15, -36)], Color("0b1723"))
	_poly([Vector2(-5, -48), Vector2(8, -45), Vector2(10, -33), Vector2(5, -18), Vector2(10 + sway, -7), Vector2(2, -13), Vector2(-4, -7), Vector2(-6, -24), Vector2(-11, -36)], Color("263b4b"))
	_poly([Vector2(-9, -44), Vector2(-7, -52), Vector2(0, -58), Vector2(9, -52), Vector2(12, -43), Vector2(4, -40), Vector2(-4, -41)], Color("38505d"))
	_poly([Vector2(-7, -46), Vector2(-3, -52), Vector2(5, -51), Vector2(8, -44), Vector2(3, -42), Vector2(-3, -43)], Color("0a1926"))
	draw_line(Vector2(-5, -46), Vector2(-1, -45), glow, 1.5)
	draw_line(Vector2(2, -45), Vector2(5, -46), glow, 1.5)
	_poly([Vector2(-2, -36), Vector2(2, -32), Vector2(0, -25), Vector2(-4, -31)], glow.darkened(0.1))
	draw_circle(Vector2(-1, -31), 10, Color(glow, 0.055))
	_limb(Vector2(-10, -37), Vector2(-19, -28), Vector2(-23, -35), Color("37525e"), 5)
	_poly([Vector2(-25, -36), Vector2(-32, -54), Vector2(-24, -48), Vector2(-21, -37)], glow.darkened(0.28))
	_limb(Vector2(10, -38), Vector2(19, -30), Vector2(17, -19), Color("253b49"), 5)
	draw_line(Vector2(18, -23), Vector2(23, -14), glow.darkened(0.45), 2)
	for i in range(3):
		var y := -10 - fposmod(time * 8 + i * 17, 44)
		draw_rect(Rect2(-18 + i * 17, y, 2, 2), Color(glow, 0.3))
	if broken:
		draw_arc(Vector2(0, -62), 9, time, time + 4.3, 12, Color(GOLD, 0.7), 1)

func _boss(glow: Color, broken: bool) -> void:
	# An original mechanical rail guardian: a cracked halo and gilded armour.
	for i in range(3):
		draw_arc(Vector2(0, -57), 24 + i * 2, 0.2 + i * 1.8 + time * 0.06, 1.45 + i * 1.8 + time * 0.06, 12, Color(glow, 0.44 - i * 0.08), 1)
	_poly([Vector2(-15, -58), Vector2(-21, -46), Vector2(-25, -8), Vector2(-13, -14), Vector2(-7, -4), Vector2(2, -11), Vector2(18, -4), Vector2(22, -17), Vector2(18, -52)], Color("292536"))
	_limb(Vector2(-10, -27), Vector2(-14, -13), Vector2(-15, -2), Color("293b45"), 11)
	_limb(Vector2(10, -27), Vector2(14, -13), Vector2(17, -2), Color("38494f"), 11)
	_rect(-22, -5, 14, 5, "18252d")
	_rect(10, -5, 16, 5, "18252d")
	_rect(-20, -15, 11, 5, "9c8056")
	_rect(10, -15, 11, 5, "ad8c5e")
	_poly([Vector2(-16, -54), Vector2(14, -54), Vector2(20, -43), Vector2(11, -25), Vector2(-10, -25), Vector2(-20, -42)], Color("46555a"))
	_poly([Vector2(-11, -52), Vector2(0, -49), Vector2(11, -52), Vector2(14, -42), Vector2(6, -32), Vector2(-6, -32), Vector2(-14, -42)], Color("718077"))
	_poly([Vector2(0, -47), Vector2(6, -40), Vector2(0, -31), Vector2(-6, -40)], Color("202c34"))
	_poly([Vector2(0, -45), Vector2(3, -40), Vector2(0, -35), Vector2(-3, -40)], glow)
	draw_circle(Vector2(0, -40), 13, Color(glow, 0.07))
	_poly([Vector2(-14, -28), Vector2(14, -28), Vector2(17, -18), Vector2(3, -21), Vector2(0, -16), Vector2(-3, -21), Vector2(-17, -18)], Color("8b714e"))
	_poly([Vector2(-10, -64), Vector2(0, -72), Vector2(10, -64), Vector2(9, -54), Vector2(0, -48), Vector2(-9, -54)], Color("687770"))
	_poly([Vector2(-8, -63), Vector2(0, -66), Vector2(8, -63), Vector2(5, -57), Vector2(0, -54), Vector2(-5, -57)], Color("152730"))
	draw_line(Vector2(-7, -60), Vector2(7, -60), glow, 2)
	_rect(-1, -71, 2, 16, "c7a374")
	# Monumental pauldrons with broken wing-like edges.
	_poly([Vector2(-13, -55), Vector2(-25, -59), Vector2(-33, -50), Vector2(-28, -40), Vector2(-16, -43)], Color("44545a"))
	_poly([Vector2(13, -55), Vector2(25, -59), Vector2(33, -50), Vector2(28, -40), Vector2(16, -43)], Color("56665f"))
	draw_line(Vector2(-30, -50), Vector2(-23, -55), Color("bf9d65"), 2)
	draw_line(Vector2(23, -55), Vector2(30, -50), Color("bf9d65"), 2)
	_limb(Vector2(-25, -43), Vector2(-29, -32), Vector2(-29, -20), Color("3c4c51"), 9)
	_limb(Vector2(25, -43), Vector2(29, -31), Vector2(32, -20), Color("4a5b5c"), 9)
	draw_line(Vector2(-31, -26), Vector2(-39, -2), Color("9daea5"), 6)
	draw_line(Vector2(-30, -26), Vector2(-38, -2), Color("d6d9b8"), 2)
	draw_line(Vector2(-35, -28), Vector2(-24, -24), Color("b48e58"), 3)
	_poly([Vector2(27, -29), Vector2(40, -31), Vector2(43, -16), Vector2(33, -9), Vector2(26, -16)], Color("30424a"))
	draw_line(Vector2(33, -26), Vector2(36, -16), glow.darkened(0.1), 2)
	if broken:
		draw_arc(Vector2(0, -79), 10, time, time + 4, 12, Color(GOLD, 0.8), 1)

func _lyra(pos: Vector2) -> void:
	_ellipse(pos + Vector2(0, 4), Vector2(22, 4), Color(0.01, 0.02, 0.03, 0.5))
	draw_set_transform(pos, 0, Vector2(2.0, 2.0))
	var bob := sin(time * 1.8) * 0.5
	_poly([Vector2(-7, -43), Vector2(7, -43), Vector2(12, -11), Vector2(5, -7), Vector2(-5, -7), Vector2(-12, -11)], Color("3f777c"))
	_poly([Vector2(-5, -40), Vector2(4, -40), Vector2(6, -13), Vector2(-6, -13)], Color("699c98"))
	_rect(-7, -10, 5, 9, "152a35")
	_rect(3, -10, 5, 9, "152a35")
	_rect(-7, -52 + bob, 15, 12, "b9967d")
	_poly([Vector2(-9, -48 + bob), Vector2(-7, -57 + bob), Vector2(4, -59 + bob), Vector2(10, -53 + bob), Vector2(10, -40), Vector2(5, -44), Vector2(3, -52), Vector2(-4, -49), Vector2(-5, -39), Vector2(-10, -40)], Color("c7d5d0"))
	_rect(-3, -47 + bob, 2, 2, "23434c")
	_rect(4, -47 + bob, 2, 2, "23434c")
	_limb(Vector2(-8, -39), Vector2(-12, -31), Vector2(-16, -33), Color("467c7f"), 4)
	draw_line(Vector2(-17, -46), Vector2(-17, -2), Color("a58e64"), 2)
	_poly([Vector2(-17, -51), Vector2(-13, -46), Vector2(-17, -41), Vector2(-21, -46)], CYAN)
	draw_circle(Vector2(-17, -46), 9, Color(CYAN, 0.07))
	draw_set_transform(Vector2.ZERO)

func _rect(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _limb(a: Vector2, b: Vector2, c: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color.darkened(0.35), width + 2)
	draw_line(b, c, color.darkened(0.35), width + 2)
	draw_line(a, b, color, width)
	draw_line(b, c, color, width)

func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := i * TAU / 24
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
