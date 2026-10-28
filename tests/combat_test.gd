extends SceneTree

const Model = preload("res://scripts/combat_model.gd")
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var model = Model.new()
	check(not model.act("basic").ok, "Uninitialized model rejects actions")
	model.setup(0)
	var snapshot: Dictionary = model.player.duplicate(true)
	check(not model.act("invalid").ok, "Unknown action rejected")
	check(not model.act("basic", -1).ok, "Negative target rejected")
	check(not model.act("basic", 100).ok, "Out-of-range target rejected")
	check(not model.act("ultimate").ok, "Ultimate needs full energy")
	check(not model.act("heal").ok, "Healing at full HP is not consumed")
	check(model.player == snapshot and not model.awaiting_enemy, "Invalid actions leave state unchanged")
	check(not model.enemies_turn().ok, "Enemies cannot move before William")
	check(model.act("basic", 0).ok, "Basic attack works")
	check(model.player.sp == 4 and model.enemies[0].hp == 56, "Basic restores skill point and damages target")
	check(not model.act("basic", 0).ok, "Cannot act twice in the same turn")
	check(model.enemies_turn().ok and model.round_no == 2, "Enemy turn returns control and advances round")
	model.player.sp = 0
	check(not model.act("skill", 0).ok, "Skill rejects insufficient points")
	model.player.sp = 2
	check(model.act("skill", 0).ok and model.player.sp == 0, "Skill costs exactly two points")
	check(model.enemies[0].broken, "Toughness depletion causes break")
	var before: int = model.player.hp
	model.enemies_turn()
	check(model.player.hp == before - 10, "Broken enemy skips its action; second enemy attacks")
	check(not model.enemies[0].broken and model.enemies[0].toughness == model.enemies[0].max_toughness, "Toughness recovers after skipped action")
	model.setup(3)
	model.player.energy = 100
	var ultimate: Dictionary = model.act("ultimate")
	check(ultimate.ok and model.enemies[0].hp == 292 and model.enemies[1].hp == 0, "Ultimate hits every living enemy")
	check(model.player.energy == 12, "Ultimate consumes energy and break grants twelve")
	check(model.enemies[0].broken, "Ultimate breaks boss")
	model.enemies_turn()
	check(model.player.hp == model.player.max_hp, "Broken boss cannot damage William")
	model.setup(0)
	model.act("basic", 0)
	check(model.enemies[0].toughness == 18, "Basic exploits steel weakness")
	model.setup(0)
	model.act("basic", 1)
	check(model.enemies[1].toughness == 26, "Basic is less effective against ether weakness")
	model.setup(0)
	model.act("skill", 1)
	check(model.enemies[1].broken, "Skill immediately breaks an ether-weak drone")
	check(model.enemies[0].hp == 68 and model.enemies[0].toughness == 34, "Skill splashes adjacent enemies")
	model.setup(0)
	model.act("skill", 0)
	check(not model.enemies[0].broken and model.enemies[0].toughness == 16, "Skill does not immediately break a steel-weak drone")
	model.setup(1)
	model.player.energy = 0
	model.act("guard")
	model.enemies_turn()
	check(model.player.energy == 32, "Guard protects energy against wraith drain")
	model.setup(1)
	model.player.energy = 0
	model.act("basic", 0)
	model.enemies_turn()
	check(model.player.energy == 21, "Unguarded wraith drain removes nine energy")
	model.setup(1)
	model.player.hp = 100
	model.act("heal")
	check(model.player.hp == 185 and model.player.heal_charges == 1, "Healing restores 85 and consumes charge")
	model.enemies_turn()
	model.player.heal_charges = 0
	check(not model.act("heal").ok, "No infinite healing charges")
	model.setup(1)
	model.act("guard")
	model.enemies_turn()
	check(model.player.hp == model.player.max_hp, "Guard absorbs first-round attacks")
	check(not model.player.guarding and model.player.shield == 0, "Guard expires after enemy phase")
	model.setup(0, ["power", "vitality", "flow"])
	check(model.player.max_hp == 258 and model.player.energy == 45 and model.player.sp == 4, "Campaign upgrades applied")
	model.act("basic", 0)
	check(model.enemies[0].hp == 49, "Power upgrade affects damage")
	model.setup(3)
	model.player.hp = 1
	model.act("basic", 0)
	model.enemies_turn()
	check(model.lost and not model.won and model.player.hp == 0, "Defeat resolves and HP never becomes negative")
	check(not model.act("heal").ok, "Cannot heal after defeat")
	for encounter in range(4):
		play_encounter(encounter)
	print("COMBAT TESTS: %d checks, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func play_encounter(encounter: int) -> void:
	var model = Model.new()
	var upgrades: Array = []
	for i in range(encounter): upgrades.append(["power", "vitality", "flow"][i])
	model.setup(encounter, upgrades)
	var turns := 0
	var saw_boss_phase := false
	while not model.won and not model.lost and turns < 35:
		var target := 0
		for i in range(model.enemies.size()):
			if model.enemies[i].hp > 0:
				target = i
				break
		var action := "basic"
		if model.player.hp < 90 and model.player.heal_charges > 0:
			action = "heal"
		elif model.player.energy == 100:
			action = "ultimate"
		elif model.player.sp >= 2:
			action = "skill"
		var result: Dictionary = model.act(action, target)
		check(result.ok, "Campaign encounter %d action succeeds" % encounter)
		if encounter == 3 and model.enemies[0].phase == 2: saw_boss_phase = true
		if not model.won: model.enemies_turn()
		check(model.player.sp >= 0 and model.player.sp <= 5, "Skill points stay in bounds")
		check(model.player.energy >= 0 and model.player.energy <= 100, "Energy stays in bounds")
		turns += 1
	check(model.won and not model.lost, "Encounter %d is winnable with documented mechanics" % encounter)
	check(turns > 1 and turns < 35, "Encounter has meaningful and finite duration")
	check(not model.act("basic", 0).ok, "Victory prevents further actions")
	if encounter == 3: check(saw_boss_phase, "Boss enters its second phase")
	print("Encounter %d: victory=%s turns=%d hp=%d" % [encounter + 1, model.won, turns, model.player.hp])
