extends SceneTree
var checks = 0
var failures = 0
var game: Node
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func skip_scene() -> void:
	if game.page == "dialogue": game.activate("skip")
func tick(seconds: float) -> void:
	for i in range(int(seconds/0.05)):
		game._process(0.05)
func run() -> void:
	game = load("res://intro/intro.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	check(game.page == "title","Initial scene opens title")
	var initial = game.terrain._outline.duplicate()
	game.activate("reroll")
	check(initial != game.terrain._outline,"Another valley actually regenerates world")
	game.activate("begin")
	check(game.page == "dialogue","Beginning opens narrative introduction")
	game.advance_story()
	check(game.line_index == 0 and game.revealed > 0,"First advance reveals line")
	game.advance_story()
	check(game.line_index == 1,"Second advance changes line")
	skip_scene()
	check(game.page == "explore" and game.model.stage == 0,"Opening enters exploration")
	check(game.current_goal().id == "beacon","First goal is interactive beacon")
	for kind in ["william","guardian","fox","moth","plant"]:
		var actor = game.sprites.get_actor(kind,Vector2.ZERO,false,Vector2.RIGHT,0)
		check(actor.has("texture") and actor.texture != null,"Loaded sprite texture for "+kind)
		check(actor.region.size.x > 0 and actor.region.size.y > 0,"Valid atlas frame "+kind)
		var clip = game.sprites.get_actor(kind,Vector2.ZERO,true,Vector2.UP,0.3,"walk")
		check(clip.texture != null,"Walk animation direction available "+kind)
	var start: Vector2 = game.hero
	var touch = InputEventScreenTouch.new()
	touch.index = 2
	touch.position = Vector2(145,588)
	touch.pressed = true
	game._unhandled_input(touch)
	tick(0.5)
	check(game.hero.x > start.x,"Touch joystick moves hero")
	touch.pressed = false
	game._unhandled_input(touch)
	check(game.joystick == Vector2.ZERO and game.stick_finger == -1,"Touch release stops movement")
	game.interact_nearby()
	check(game.model.stage == 0,"Distant interaction does not activate beacon")
	game.follow_trail()
	tick(6)
	check(game.hero.distance_to(game.current_goal().pos) < 30,"Guided trail reaches beacon without getting stuck")
	game.interact_nearby()
	check(game.model.stage == 1 and game.page == "dialogue","Beacon starts combat introduction")
	skip_scene()
	game.follow_trail()
	tick(5)
	check(game.model.guardian.active,"Approaching guardian starts encounter")
	var starting_health = game.model.guardian.hp
	game.activate("auto")
	check(not game.model.auto_combat,"Automatic attack can be disabled")
	game.manual_attack()
	tick(1.3)
	game.manual_attack()
	check(game.model.guardian.hp < starting_health,"Manual basic attack works")
	game.activate("auto")
	var used: Array = []
	for i in range(500):
		if game.page != "explore" or game.model.stage >= 2: break
		for skill in ["flame","frost","aegis"]:
			if not used.has(skill) and game.model.player.energy >= game.model.SKILL_COSTS[skill] and game.model.cooldowns[skill] <= 0:
				game.cast(skill)
				if game.skills_used.has(skill): used.append(skill)
		game._process(0.05)
	check(game.model.stage == 2,"Playable encounter resolves in victory")
	check(game.page == "dialogue","Victory opens narrative response")
	check(not game.skills_used.is_empty(),"Active powers used through presentation")
	skip_scene()
	game.follow_trail()
	tick(8)
	check(game.hero.distance_to(game.current_goal().pos) < 30,"Guided trail reaches final gate")
	game.interact_nearby()
	check(game.model.stage == 3 and game.page == "dialogue","Gate starts final scene")
	skip_scene()
	check(game.page == "end","Intro ends explicitly, without starting another campaign")
	game.activate("begin")
	skip_scene()
	game.hero = Vector2(780,850)
	game.interact_nearby()
	skip_scene()
	game.hero = game.guardian_pos+Vector2(-90,0)
	game.model.player.hp = 0
	game._process(0.05)
	check(game.overlay == "down","Defeat presents retry")
	game.activate("retry")
	check(game.overlay.is_empty() and game.model.player.hp == game.model.player.max_hp,"Retry restores playable encounter")
	game.activate("pause")
	var hero_before: Vector2 = game.hero
	var hp_before: int = game.model.player.hp
	game.joystick = Vector2.RIGHT
	tick(2)
	check(game.hero == hero_before and game.model.player.hp == hp_before,"Pause stops movement and combat")
	game.activate("menu")
	check(game.page == "title","Return to title works")
	game.queue_free()
	await process_frame
	print("INTRO FLOW: %d checks, %d failures; opening, sprites, touch, navigation, combat, ending, retry and pause verified." % [checks,failures])
	quit(1 if failures else 0)
