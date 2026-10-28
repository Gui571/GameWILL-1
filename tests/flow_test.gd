extends SceneTree
## Run with XDG_DATA_HOME=/tmp/william-flow-data to isolate all progress.
var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func instance_game() -> Node:
	var instance = load("res://main.tscn").instantiate()
	instance.visible = false
	root.add_child(instance)
	instance.set_process(false)
	return instance

func exhaust_dialogue() -> void:
	var limit := 0
	while game.page == "dialogue" and limit < 100:
		game.revealed = INF
		game.next_dialogue()
		limit += 1
	check(limit < 100, "Dialogue must terminate")

func run() -> void:
	if not OS.get_user_data_dir().begins_with("/tmp/william-flow-"):
		push_error("Refusing to touch real progress: set XDG_DATA_HOME=/tmp/william-flow-data")
		quit(2)
		return
	for path in ["user://campaign.json", "user://campaign.json.tmp", "user://settings.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	game = instance_game()
	await process_frame
	check(game.page == "title", "Game opens on title")
	game.activate("new")
	check(game.page == "dialogue", "New game opens prologue")
	game.next_dialogue()
	check(game.dialogue_index == 0 and game.revealed > 0, "First click reveals current line")
	game.next_dialogue()
	check(game.dialogue_index == 1, "Second click advances dialogue")
	exhaust_dialogue()
	check(game.page == "map" and game.encounter == 0, "Prologue reaches first map")
	game.activate("mute")
	game.activate("motion")
	var reloaded = instance_game()
	check(reloaded.muted and reloaded.reduced_motion, "Settings survive fresh scene")
	check(reloaded.save_data.get("encounter", -1) == 0, "Checkpoint survives fresh scene")
	reloaded.queue_free()
	await process_frame
	var total_actions := 0
	for chapter in range(4):
		check(game.encounter == chapter and game.page == "map", "Expected chapter map %d" % chapter)
		game.activate("start")
		exhaust_dialogue()
		check(game.page == "battle", "Chapter %d starts battle" % chapter)
		if chapter == 0:
			check(game.overlay == "help", "First encounter explains controls")
		game.activate("close")
		var turn_count := 0
		while game.page == "battle" and turn_count < 80:
			var player: Dictionary = game.combat.player
			var action := "basic"
			if player.energy >= 100:
				action = "ultimate"
			elif player.hp < player.max_hp * 0.50 and player.heal_charges > 0:
				action = "heal"
			elif player.sp >= 2:
				action = "skill"
			# Prioritize low-health targets to reduce incoming damage.
			var best_hp := 99999
			for i in range(game.combat.enemies.size()):
				var enemy: Dictionary = game.combat.enemies[i]
				if enemy.hp > 0 and enemy.hp < best_hp:
					best_hp = enemy.hp
					game.selected = i
			game.choose_action(action)
			check(game.busy, "Valid action starts animation")
			var phases := 0
			while game.busy and phases < 4:
				game.finish_phase()
				phases += 1
			check(phases < 4, "Animation phases finish")
			turn_count += 1
			total_actions += 1
		check(game.combat.won and not game.combat.lost, "Chapter %d can be won" % chapter)
		check(game.page == "dialogue", "Victory has narrative payoff")
		exhaust_dialogue()
		if chapter < 3:
			check(game.page == "reward", "Victory offers improvement")
			game.activate("upgrade:" + ["power", "vitality", "flow"][chapter])
			game.read_save()
			check(game.save_data.encounter == chapter + 1, "Next chapter saved")
			check(game.save_data.upgrades.size() == chapter + 1, "Upgrade persisted")
	check(game.page == "ending", "Full campaign reaches ending")
	game.read_save()
	check(game.save_data.get("completed", false), "Completion saved")
	game.activate("menu")
	game.activate("continue")
	check(game.page == "ending", "Completed save resumes ending")
	game.start_battle()
	game.overlay = ""
	game.combat.player.hp = 1
	game.choose_action("basic")
	game.finish_phase()
	game.finish_phase()
	check(game.page == "defeat", "Lethal enemy turn opens defeat screen")
	game.activate("retry")
	check(game.page == "battle" and game.combat.player.hp == game.combat.player.max_hp, "Retry restores encounter")
	game.activate("menu")
	check(game.page == "title" and not game.busy, "Return to menu cancels animation")
	for invalid in ["broken json", "[]", '{"version":9}', '{"version":1,"encounter":99,"upgrades":[]}', '{"version":1,"encounter":0,"upgrades":["hacked"]}']:
		var file := FileAccess.open("user://campaign.json", FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		game.read_save()
		check(game.save_data.is_empty(), "Invalid checkpoint rejected")
	game.queue_free()
	await process_frame
	await process_frame
	print("FLOW: %d checks, %d failures; 4 encounters, %d actions; save, settings, ending, defeat/retry validated." % [checks, failures, total_actions])
	quit(1 if failures else 0)
