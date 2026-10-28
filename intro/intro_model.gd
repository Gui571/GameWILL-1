class_name WilliamIntroModel
extends RefCounted
## Small deterministic introduction encounter. Rendering, movement and interaction
## proximity belong to intro.gd; damage ranges and resource rules live here.

const BASIC_RANGE := 180.0
const ENEMY_RANGE := 220.0
const BASIC_PERIOD := 1.2
const CHARGE_DELAY := 1.8
const WINDUP_TIME := 1.0
const SKILL_COSTS := {"basic": 0, "flame": 20, "frost": 15, "aegis": 70}
const SKILL_RANGES := {"basic": 180.0, "flame": 260.0, "frost": 240.0, "aegis": 260.0}
const SKILL_COOLDOWNS := {"basic": 1.2, "flame": 4.5, "frost": 7.0, "aegis": 12.0}

var seed_value: int = 0
var stage: int = 0
var player: Dictionary = {}
var guardian: Dictionary = {}
var cooldowns: Dictionary = {"basic": 0.0, "flame": 0.0, "frost": 0.0, "aegis": 0.0}
var auto_combat: bool = true
var elapsed: float = 0.0
var _charge_timer: float = CHARGE_DELAY
var _shield_time: float = 0.0
var _events: Array[Dictionary] = []

func setup(seed: int) -> void:
	seed_value = seed
	stage = 0
	elapsed = 0.0
	auto_combat = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var health := 260 + rng.randi_range(0, 2) * 8
	guardian = {"name": "Guardião do Limiar", "hp": health, "max_hp": health,
		"active": false, "defeated": false, "windup": 0.0, "frozen": 0.0}
	_reset_player()
	_events.clear()

func _reset_player() -> void:
	player = {"hp": 160, "max_hp": 160, "energy": 35, "shield": 0}
	cooldowns = {"basic": 0.0, "flame": 0.0, "frost": 0.0, "aegis": 0.0}
	_charge_timer = CHARGE_DELAY
	_shield_time = 0.0

func update(delta: float, distance_to_guardian: float) -> Array:
	_events = []
	if player.is_empty() or not is_finite(delta) or delta <= 0.0:
		return _events
	if not _valid_distance(distance_to_guardian):
		return _events
	# Substeps preserve cooldowns, telegraphs and fair damage on a slow frame.
	# The display pauses calls while menus/dialogues are open.
	var remaining := minf(delta, 30.0)
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 60.0)
		_tick(step, distance_to_guardian)
		remaining -= step
	return _events.duplicate(true)

func _tick(delta: float, distance: float) -> void:
	elapsed += delta
	for skill in cooldowns:
		cooldowns[skill] = maxf(0.0, float(cooldowns[skill]) - delta)
	if _shield_time > 0.0:
		_shield_time = maxf(0.0, _shield_time - delta)
		if _shield_time == 0.0:
			player.shield = 0
	if stage != 1 or player.hp <= 0 or guardian.defeated:
		return
	if not guardian.active:
		if distance < 230.0:
			_start_guardian()
		else:
			return
	if auto_combat and distance <= BASIC_RANGE and float(cooldowns.basic) <= 0.00001:
		_use_basic()
		if guardian.defeated:
			return
	if float(guardian.frozen) > 0.0:
		guardian.frozen = maxf(0.0, float(guardian.frozen) - delta)
		return
	if float(guardian.windup) > 0.0:
		guardian.windup = maxf(0.0, float(guardian.windup) - delta)
		if float(guardian.windup) <= 0.00001:
			guardian.windup = 0.0
			if distance <= ENEMY_RANGE:
				_enemy_hit()
			else:
				_emit("stage", 0, "O golpe atingiu o chão. Você escapou do círculo.")
			_charge_timer = CHARGE_DELAY
		return
	# Moving away is useful: the guardian holds its ground rather than hitting
	# the player remotely or accumulating attacks while off-screen.
	if distance > 300.0:
		_charge_timer = CHARGE_DELAY
		return
	_charge_timer -= delta
	if _charge_timer <= 0.00001:
		guardian.windup = WINDUP_TIME
		_emit("charge", 18, "O guardião prepara um golpe. Saia do círculo ou use Geada.")

func activate_skill(skill: String, distance: float) -> Dictionary:
	_events = []
	if player.is_empty(): return _result(false, "A jornada ainda não começou.")
	if not SKILL_COSTS.has(skill): return _result(false, "Essa técnica ainda não foi aprendida.")
	if stage != 1 or guardian.defeated: return _result(false, "As técnicas serão usadas no desafio do guardião.")
	if player.hp <= 0: return _result(false, "Retome o desafio para continuar.")
	if not _valid_distance(distance) or distance > float(SKILL_RANGES[skill]):
		return _result(false, "Aproxime-se do guardião para usar esta técnica.")
	if float(cooldowns[skill]) > 0.00001:
		return _result(false, "A técnica está recarregando: %.1f s." % cooldowns[skill])
	var cost: int = SKILL_COSTS[skill]
	if player.energy < cost:
		return _result(false, "Requer %d de energia. Cortes básicos recuperam 12." % cost)
	if not guardian.active: _start_guardian()
	if skill == "basic":
		_use_basic()
		return _result(true, "Corte de William")
	player.energy -= cost
	cooldowns[skill] = SKILL_COOLDOWNS[skill]
	match skill:
		"flame":
			_damage(46, "flame", "Chama de Âmbar")
		"frost":
			var interrupted: bool = float(guardian.windup) > 0.0
			guardian.windup = 0.0
			guardian.frozen = 2.2
			_charge_timer = CHARGE_DELAY
			_damage(22, "frost", "Geada do Limiar")
			if interrupted and not guardian.defeated:
				_emit("break", 0, "Ruptura! O golpe carregado foi interrompido.")
		"aegis":
			player.shield = 48
			_shield_time = 8.0
			_damage(70, "aegis", "Égide de Aurora: escudo 48 por 8 segundos.")
	return _result(true, {"flame": "Chama de Âmbar", "frost": "Geada do Limiar", "aegis": "Égide de Aurora"}[skill])

func interact(id: String) -> Dictionary:
	_events = []
	if player.is_empty(): return _result(false, "A jornada ainda não começou.")
	if player.hp <= 0: return _result(false, "Retome o desafio antes de continuar.")
	match id:
		"beacon":
			if stage != 0: return _result(false, "O farol já está aceso.")
			stage = 1
			_emit("stage", stage, "O farol despertou. Encontre o guardião na clareira.")
			return _result(true, "O farol responde à luz de William.")
		"guardian":
			if stage == 0: return _result(false, "O farol precisa ser despertado primeiro.")
			if stage != 1: return _result(false, "O guardião já reconheceu seu juramento.")
			if not guardian.active: _start_guardian()
			return _result(true, "O desafio do guardião começou.")
		"gate":
			if stage != 2: return _result(false, "O portal aguarda o reconhecimento do guardião.")
			stage = 3
			_emit("stage", stage, "Aurora espera além do limiar. Fim da introdução.")
			return _result(true, "O caminho para Aurora está aberto.")
	return _result(false, "Nada aqui responde à sua luz.")

func reset_encounter() -> void:
	# A retry cannot undo completed objectives or bypass the introductory beacon.
	if player.is_empty() or stage != 1: return
	_reset_player()
	guardian.hp = guardian.max_hp
	guardian.active = false
	guardian.defeated = false
	guardian.windup = 0.0
	guardian.frozen = 0.0
	_events.clear()

func _start_guardian() -> void:
	guardian.active = true
	_charge_timer = CHARGE_DELAY
	_emit("stage", 1, "O guardião ergue a lâmina. Demonstre o poder dos elementos.")

func _use_basic() -> void:
	cooldowns.basic = BASIC_PERIOD
	player.energy = mini(100, int(player.energy) + 12)
	_damage(14, "basic", "Corte de William")

func _damage(amount: int, kind: String, description: String) -> void:
	var actual := mini(amount, int(guardian.hp))
	guardian.hp = maxi(0, int(guardian.hp) - amount)
	_emit(kind, actual, description)
	if guardian.hp == 0:
		guardian.defeated = true
		guardian.active = false
		guardian.windup = 0.0
		guardian.frozen = 0.0
		stage = 2
		_emit("win", 0, "O guardião se ajoelha. O portal de Aurora está aberto.")
		_emit("stage", stage, "Atravesse o portal para concluir a introdução.")

func _enemy_hit() -> void:
	var absorbed := mini(18, int(player.shield))
	player.shield -= absorbed
	var damage := mini(18 - absorbed, int(player.hp))
	player.hp = maxi(0, int(player.hp) - damage)
	player.energy = mini(100, int(player.energy) + 5)
	_emit("enemy_hit", damage, "O escudo absorveu o golpe." if damage == 0 else "Golpe do guardião")
	if player.hp == 0:
		guardian.active = false
		guardian.windup = 0.0
		_emit("down", 0, "William caiu. O desafio pode ser recomeçado.")

func _valid_distance(value: float) -> bool:
	return is_finite(value) and value >= 0.0

func _emit(type: String, amount: int, text: String) -> void:
	_events.append({"type": type, "amount": amount, "text": text})

func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message, "events": _events.duplicate(true)}
