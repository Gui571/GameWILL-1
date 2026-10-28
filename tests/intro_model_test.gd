extends SceneTree
const Model = preload("res://intro/intro_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func event_count(events: Array, kind: String) -> int:
	return events.filter(func(event): return event.type == kind).size()

func begin(seed: int = 77):
	var model = Model.new()
	model.setup(seed)
	model.interact("beacon")
	return model

func run() -> void:
	var model = Model.new()
	check(not model.activate_skill("basic", 0).ok, "Uninitialized skill rejected")
	check(not model.interact("beacon").ok, "Uninitialized interaction rejected")
	model.setup(77)
	check(model.stage == 0 and model.player.hp == 160, "Fresh introduction starts before beacon")
	check(not model.interact("gate").ok, "Cannot skip directly to ending")
	check(not model.interact("guardian").ok, "Guardian gated by beacon")
	model.update(5, 0)
	check(not model.guardian.active and model.guardian.hp == model.guardian.max_hp, "Proximity alone cannot skip beacon")
	check(not model.activate_skill("flame", 0).ok, "No skills before beacon")
	check(model.interact("beacon").ok and model.stage == 1, "Beacon unlocks challenge")
	check(not model.interact("beacon").ok, "Beacon cannot reset or duplicate objective")
	model.update(1, 500)
	check(not model.guardian.active, "Guardian stays dormant beyond activation range")
	model.auto_combat = false
	model.update(0.1, 200)
	check(model.guardian.active and model.guardian.hp == model.guardian.max_hp, "Approach starts encounter without forcing auto attack")
	var hp: int = model.guardian.hp
	var energy: int = model.player.energy
	check(not model.activate_skill("basic", 181).ok, "Basic enforces melee range")
	check(not model.activate_skill("flame", 261).ok, "Flame enforces range")
	check(not model.activate_skill("frost", 241).ok, "Frost enforces range")
	check(not model.activate_skill("aegis", 261).ok, "Aegis cannot damage distant guardian")
	check(not model.activate_skill("unknown", 10).ok, "Unknown skills rejected")
	check(not model.activate_skill("basic", -1).ok, "Negative distance rejected")
	check(not model.activate_skill("basic", INF).ok, "Infinite distance rejected")
	check(model.guardian.hp == hp and model.player.energy == energy, "Rejected actions do not consume resources or damage")
	check(model.activate_skill("basic", 180).ok, "Manual basic works with auto disabled")
	check(model.guardian.hp == hp - 14 and model.player.energy == energy + 12, "Basic deals damage and earns energy")
	check(not model.activate_skill("basic", 100).ok, "Basic cannot be spammed")
	model.auto_combat = true
	model.update(0.6, 100)
	check(model.guardian.hp == hp - 14, "Auto and manual share basic cooldown")
	model.update(0.7, 100)
	check(model.guardian.hp == hp - 28, "Auto resumes after shared cooldown")
	model = begin()
	model.auto_combat = false
	check(model.activate_skill("flame", 100).ok, "Flame available with starting energy")
	check(model.player.energy == 15 and model.cooldowns.flame == 4.5, "Flame exact cost and cooldown")
	check(not model.activate_skill("flame", 100).ok, "Flame respects cooldown")
	check(not model.activate_skill("aegis", 100).ok, "Aegis requires accumulated energy")
	check(model.activate_skill("frost", 100).ok and model.player.energy == 0, "Frost exact cost")
	check(model.guardian.frozen > 2.0, "Frost suspends enemy attacks")
	model.update(1.5, 100)
	check(model.player.hp == 160, "Frozen guardian cannot hit")
	model = begin()
	model.auto_combat = false
	var events: Array = model.update(1.9, 100)
	check(event_count(events, "charge") == 1 and model.guardian.windup > 0.8, "Enemy visibly telegraphs before impact")
	check(model.player.hp == 160, "No damage during telegraph")
	var result: Dictionary = model.activate_skill("frost", 100)
	check(event_count(result.events, "break") == 1 and model.guardian.windup == 0.0, "Frost interrupts charged attack")
	model.update(2, 100)
	check(model.player.hp == 160, "Interrupted attack does not hit later")
	model = begin()
	model.auto_combat = false
	model.update(1.9, 100)
	model.update(1.1, 260)
	check(model.player.hp == 160, "Player can dodge by leaving threat radius")
	model = begin()
	model.auto_combat = false
	model.player.energy = 100
	check(model.activate_skill("aegis", 100).ok, "Charged aegis works")
	check(model.player.shield == 48 and model.player.energy == 30, "Aegis gives shield and spends70 energy")
	check(model.guardian.hp == model.guardian.max_hp - 70, "Aegis damages guardian")
	model.update(3, 100)
	check(model.player.hp == 160 and model.player.shield == 30, "Shield absorbs enemy attack")
	model.update(5.1, 500)
	check(model.player.shield == 0, "Shield expires outside battle")
	model = begin()
	model.auto_combat = false
	model.update(28, 100)
	check(model.player.hp == 0 and model.stage == 1, "Inactive player can lose without skipping story")
	check(not model.activate_skill("basic", 100).ok, "No attacking while down")
	check(not model.interact("gate").ok, "Defeat cannot complete introduction")
	model.reset_encounter()
	check(model.player.hp == 160 and model.player.energy == 35 and model.guardian.hp == model.guardian.max_hp, "Retry fully restores fair encounter")
	check(not model.guardian.active and model.cooldowns.flame == 0, "Retry clears charge and cooldown state")
	var a = begin(152)
	var b = begin(152)
	check(a.guardian == b.guardian and a.player == b.player, "Same seed reproduces encounter")
	a.auto_combat = false
	b.auto_combat = false
	a.update(1, 100)
	for i in range(60): b.update(1.0/60.0, 100)
	check(a.player == b.player and is_equal_approx(a.guardian.windup, b.guardian.windup), "Large frame preserves fixed-step results")
	var before: float = a.elapsed
	a.update(-1, 100)
	a.update(NAN, 100)
	a.update(1, NAN)
	check(a.elapsed == before, "Invalid time and distance cannot mutate game")
	for seed in [1,77,152,9999]:
		play_intro(seed, false)
		play_intro(seed, true)
	print("INTRO MODEL: %d checks, %d failures; beacon, ranges, skills, telegraphs, auto/manual, win, retry and ending verified." % [checks, failures])
	quit(1 if failures else 0)

func play_intro(seed: int, use_skills: bool) -> void:
	var model = begin(seed)
	var total := 0.0
	var wins := 0
	while model.stage == 1 and model.player.hp > 0 and total < 40:
		if use_skills:
			if model.player.energy >= 70 and model.cooldowns.aegis <= 0:
				wins += event_count(model.activate_skill("aegis", 100).events, "win")
			elif model.guardian.windup > 0 and model.player.energy >= 15 and model.cooldowns.frost <= 0:
				wins += event_count(model.activate_skill("frost", 100).events, "win")
			elif model.player.energy >= 20 and model.cooldowns.flame <= 0:
				wins += event_count(model.activate_skill("flame", 100).events, "win")
		wins += event_count(model.update(0.1, 100), "win")
		total += 0.1
	check(model.stage == 2 and model.player.hp > 0, "Seed%d introduction winnable; skills=%s" % [seed,use_skills])
	check(model.guardian.defeated and model.guardian.hp == 0 and not model.guardian.active, "Guardian defeat state consistent")
	check(wins == 1, "Victory event fires once")
	check(model.player.energy >= 0 and model.player.energy <= 100, "Energy bounded throughout challenge")
	check(not model.activate_skill("flame", 100).ok, "Cannot attack defeated guardian")
	check(model.interact("gate").ok and model.stage == 3, "Final portal completes introduction")
	check(not model.interact("gate").ok, "Completion cannot trigger repeatedly")
	model.reset_encounter()
	check(model.stage == 3 and model.guardian.defeated, "Retry cannot reopen completed introduction")
	print("Seed %d skills=%s: %.1fs, hp%d" % [seed,use_skills,total,model.player.hp])
