class_name CombatModel
extends RefCounted
## Deterministic combat rules. Presentation belongs to the scene, never this model.

const MAX_SP := 5
const MAX_ENERGY := 100
const SKILL_COST := 2

var player: Dictionary = {}
var enemies: Array[Dictionary] = []
var round_no: int = 1
var won: bool = false
var lost: bool = false
var awaiting_enemy: bool = false
var encounter_index: int = 0
var damage_bonus: int = 0
var _events: Array[Dictionary] = []

func setup(index: int, upgrades: Array = []) -> void:
	encounter_index = clampi(index, 0, 3)
	round_no = 1
	won = false
	lost = false
	awaiting_enemy = false
	damage_bonus = 0
	_events.clear()
	var health_bonus := 0
	var energy_bonus := 0
	var point_bonus := 0
	for upgrade in upgrades:
		match str(upgrade):
			"power", "damage", "forca": damage_bonus += 7
			"vitality", "health", "vida": health_bonus += 38
			"flow", "energy", "energia":
				energy_bonus += 20
				point_bonus += 1
	player = {"name": "William", "hp": 220 + health_bonus, "max_hp": 220 + health_bonus,
		"energy": mini(MAX_ENERGY, 25 + energy_bonus), "sp": mini(MAX_SP, 3 + point_bonus),
		"shield": 0, "heal_charges": 2, "guarding": false}
	enemies.clear()
	match encounter_index:
		0:
			enemies.append(_enemy("Vigia de fuligem", "drone", 86, 48, "Aço", 11))
			enemies.append(_enemy("Olho da estação", "drone", 76, 42, "Éter", 10))
		1:
			enemies.append(_enemy("Sentinela do desvio", "sentinel", 140, 72, "Aço", 17))
			enemies.append(_enemy("Eco sem nome", "wraith", 96, 48, "Éter", 13))
		2:
			enemies.append(_enemy("Guarda do embarque", "sentinel", 138, 64, "Aço", 17))
			enemies.append(_enemy("Vigia do relógio", "drone", 84, 42, "Aço", 11))
			enemies.append(_enemy("Memória vazia", "wraith", 108, 54, "Éter", 13))
		3:
			enemies.append(_enemy("Regente Vazio", "boss", 390, 100, "Éter", 24))
			enemies.append(_enemy("Testemunha mecânica", "drone", 90, 48, "Aço", 12))
	_update_intents()

func _enemy(enemy_name: String, kind: String, hp: int, toughness: int, weakness: String, attack: int) -> Dictionary:
	return {"name": enemy_name, "kind": kind, "hp": hp, "max_hp": hp,
		"toughness": toughness, "max_toughness": toughness, "weakness": weakness,
		"attack": attack, "broken": false, "intent": "strike", "phase": 1}

func act(action: String, target: int = 0) -> Dictionary:
	_events = []
	if player.is_empty(): return _result(false, "Combate ainda não iniciado.")
	if won or lost: return _result(false, "Este combate já terminou.")
	if awaiting_enemy: return _result(false, "Aguarde a ação inimiga.")
	if action not in ["basic", "skill", "ultimate", "guard", "heal"]:
		return _result(false, "Ação desconhecida.")
	if action in ["basic", "skill"] and (target < 0 or target >= enemies.size() or enemies[target].hp <= 0):
		return _result(false, "Escolha um inimigo vivo.")
	if action == "skill" and player.sp < SKILL_COST:
		return _result(false, "São necessários 2 pontos de habilidade. O ataque básico recupera 1.")
	if action == "ultimate" and player.energy < MAX_ENERGY:
		return _result(false, "O Supremo precisa de 100 de energia.")
	if action == "heal" and player.heal_charges <= 0:
		return _result(false, "Você já usou as duas cargas de Pulso de Lyra deste combate.")
	if action == "heal" and player.hp == player.max_hp:
		return _result(false, "A vida já está cheia.")
	player.guarding = false
	match action:
		"basic":
			player.sp = mini(MAX_SP, player.sp + 1)
			_gain_energy(18)
			_damage_enemy(target, 30 + damage_bonus, 30 if enemies[target].weakness == "Aço" else 16)
		"skill":
			player.sp -= SKILL_COST
			_gain_energy(28)
			_damage_enemy(target, 55 + damage_bonus * 2, 54 if enemies[target].weakness == "Éter" else 32)
			for i in range(enemies.size()):
				if i != target and enemies[i].hp > 0 and absi(i - target) <= 1:
					_damage_enemy(i, 18 + damage_bonus, 14)
		"ultimate":
			player.energy = 0
			_event("ultimate", -1, 0, "ÚLTIMO ALVORECER — nenhum eco ficará para trás.")
			for i in range(enemies.size()):
				if enemies[i].hp > 0:
					_damage_enemy(i, 98 + damage_bonus * 3, 100)
		"guard":
			player.guarding = true
			player.shield = 36
			_gain_energy(20)
			player.sp = mini(MAX_SP, player.sp + 1)
			_event("defend", -1, 36, "Postura de ferro: escudo 36, dano recebido −35%, +1 PH e +20 energia.")
		"heal":
			player.heal_charges -= 1
			_heal_player(85, "Pulso de Lyra")
			_gain_energy(12)
	awaiting_enemy = true
	_check_end()
	return _result(true, {"basic": "Corte errante", "skill": "Fenda de âmbar", "ultimate": "Último alvorecer", "guard": "Postura de ferro", "heal": "Pulso de Lyra"}[action])

func enemies_turn() -> Dictionary:
	_events = []
	if player.is_empty(): return _result(false, "Combate ainda não iniciado.")
	if won or lost: return _result(false, "Este combate já terminou.")
	if not awaiting_enemy: return _result(false, "É a vez de William.")
	for i in range(enemies.size()):
		var enemy := enemies[i]
		if enemy.hp <= 0: continue
		if enemy.broken:
			_event("support", i, 0, "%s perde a ação por Ruptura." % enemy.name)
			enemy.broken = false
			enemy.toughness = enemy.max_toughness
			continue
		var attack: int = enemy.attack
		if enemy.kind == "boss" and enemy.phase == 2: attack += 5
		match enemy.intent:
			"charge":
				_event("support", i, 0, "%s prepara um golpe pesado. Defenda ou provoque Ruptura!" % enemy.name)
			"heavy":
				_hit_player(ceili(attack * 1.9), "%s usa Colapso" % enemy.name)
			"drain":
				_hit_player(attack, "%s usa Sussurro vazio" % enemy.name)
				if not player.guarding:
					player.energy = maxi(0, player.energy - 9)
					_event("support", -1, -9, "Sussurro vazio drena 9 de energia. Defender impede o dreno.")
			_:
				_hit_player(attack, "%s ataca" % enemy.name)
		if player.hp <= 0:
			lost = true
			_event("death", -1, 0, "William caiu. A estação ainda espera por você.")
			break
	if not lost and round_no % 2 == 0:
		if player.hp < player.max_hp * 0.65:
			_heal_player(26, "Lyra · frequência de cura")
		else:
			for i in range(enemies.size()):
				if enemies[i].hp > 0:
					_event("support", i, 0, "Lyra · disparo de ressonância")
					_damage_enemy(i, 14, 8)
					break
	player.shield = 0
	player.guarding = false
	awaiting_enemy = false
	round_no += 1
	_check_end()
	_update_intents()
	return _result(true, "Sua vez. Leia as intenções inimigas.")

func get_enemy_intent(index: int) -> String:
	if index < 0 or index >= enemies.size(): return ""
	var enemy := enemies[index]
	if enemy.hp <= 0: return "DERROTADO"
	if enemy.broken: return "RUPTURA · perde a próxima ação"
	var attack: int = enemy.attack + (5 if enemy.kind == "boss" and enemy.phase == 2 else 0)
	match enemy.intent:
		"charge": return "PREPARANDO · golpe pesado a seguir"
		"heavy": return "COLAPSO · %d dano" % ceili(attack * 1.9)
		"drain": return "DRENO · %d dano / −9 energia" % attack
	return "ATAQUE · %d dano" % attack

func _update_intents() -> void:
	for i in range(enemies.size()):
		var enemy := enemies[i]
		if enemy.kind == "boss":
			enemy.intent = ["strike", "charge", "heavy", "drain"][(round_no - 1) % 4]
		elif enemy.kind == "sentinel":
			enemy.intent = ["strike", "charge", "heavy"][(round_no - 1) % 3]
		elif enemy.kind == "wraith":
			enemy.intent = "drain" if round_no % 2 == 1 else "strike"
		else:
			enemy.intent = "charge" if (round_no + i) % 4 == 0 else ("heavy" if (round_no + i) % 4 == 1 and round_no > 1 else "strike")

func _damage_enemy(index: int, damage: int, break_damage: int) -> void:
	var enemy := enemies[index]
	if enemy.hp <= 0: return
	var final_damage := ceili(damage * 1.35) if enemy.broken else damage
	enemy.hp = maxi(0, enemy.hp - final_damage)
	_event("damage", index, final_damage, "%s sofre %d de dano." % [enemy.name, final_damage])
	if enemy.hp <= 0:
		_event("death", index, 0, "%s derrotado." % enemy.name)
		return
	if not enemy.broken:
		enemy.toughness = maxi(0, enemy.toughness - break_damage)
		if enemy.toughness == 0:
			enemy.broken = true
			_gain_energy(12)
			_event("break", index, 0, "RUPTURA! %s perde uma ação e recebe +35%% de dano até se recuperar." % enemy.name)
	if enemy.kind == "boss" and enemy.phase == 1 and enemy.hp <= enemy.max_hp / 2:
		enemy.phase = 2
		_event("support", index, 0, "FASE II · O Regente abre o núcleo. Seus golpes ficam mais fortes!")

func _hit_player(damage: int, source: String) -> void:
	var reduced := ceili(damage * 0.65) if player.guarding else damage
	var absorbed: int = mini(player.shield, reduced)
	player.shield -= absorbed
	reduced -= absorbed
	player.hp = maxi(0, player.hp - reduced)
	_gain_energy(6)
	_event("damage", -1, reduced, "%s: %d de dano%s." % [source, reduced, " (escudo absorveu %d)" % absorbed if absorbed else ""])

func _heal_player(amount: int, source: String) -> void:
	var healed: int = mini(amount, player.max_hp - player.hp)
	player.hp += healed
	_event("heal", -1, healed, "%s recupera %d PV." % [source, healed])

func _gain_energy(amount: int) -> void:
	player.energy = clampi(player.energy + amount, 0, MAX_ENERGY)

func _check_end() -> void:
	lost = player.hp <= 0
	won = not lost and enemies.all(func(enemy: Dictionary) -> bool: return enemy.hp <= 0)
	if won or lost: awaiting_enemy = false

func _event(type: String, target: int, amount: int, description: String) -> void:
	_events.append({"type": type, "target": target, "amount": amount, "text": description})

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "events": _events.duplicate(true), "victory": won, "defeat": lost}
