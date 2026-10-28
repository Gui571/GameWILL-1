extends Node2D
## Presentation and campaign flow. Combat rules are isolated in combat_model.gd.
const Combat = preload("res://scripts/combat_model.gd")
const Story = preload("res://scripts/story.gd")
const Art = preload("res://scripts/world_art.gd")
const Sound = preload("res://scripts/soundscape.gd")
const INK = Color("101c28")
const PAPER = Color("f2e8d4")
const MUTED = Color("8fa4af")
const GOLD = Color("edc681")
const CYAN = Color("7bd6d1")
const RED = Color("e78079")
const SAVE_PATH = "user://campaign.json"
const SETTINGS_PATH = "user://settings.json"
var regular: Font = preload("res://assets/interface.ttf")
var display_font: Font = preload("res://assets/title.ttf")
var art: Node2D
var sound: Node
var combat = Combat.new()
var page = "title"
var encounter = 0
var upgrades: Array = []
var selected = 0
var buttons: Array = []
var mouse = Vector2.ZERO
var elapsed = 0.0
var dialogue: Array = []
var dialogue_index = 0
var revealed = 0.0
var dialogue_next = "map"
var busy = false
var action_time = 0.0
var action_duration = 0.9
var action_name = "idle"
var action_phase = ""
var last_result: Dictionary = {}
var staged_enemies: Array = []
var effects_released = true
var floaters: Array = []
var feedback = ""
var feedback_time = 0.0
var flash = 0.0
var overlay = ""
var muted = false
var reduced_motion = false
var save_data: Dictionary = {}
var current_log: Array[String] = []
var tutorial_seen = false
var demo_capture = ""
var auto_demo = false

func _ready() -> void:
	art = Art.new()
	art.z_index = -1
	add_child(art)
	sound = Sound.new()
	add_child(sound)
	load_settings()
	read_save()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			demo_capture = arg.trim_prefix("--capture=")
		if arg == "--battle-demo":
			encounter = 1
			upgrades = ["power"]
			start_battle()
			overlay = ""
		if arg == "--autoplay":
			auto_demo = true
	if not demo_capture.is_empty():
		capture_later()
	queue_redraw()

func capture_later() -> void:
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	image.save_png(demo_capture)
	get_tree().quit()

func _process(delta: float) -> void:
	elapsed += delta
	mouse = get_global_mouse_position()
	art.scene_mode = "battle" if page == "battle" or page == "defeat" else ("title" if page == "title" or page == "ending" else ("dialogue" if page == "dialogue" else "map"))
	art.encounter = encounter
	art.selected_enemy = selected
	art.enemies_data = (combat.enemies if effects_released else staged_enemies) if page == "battle" or page == "defeat" else []
	art.weather = not reduced_motion
	art.target_index = selected
	art.hero_action = action_name
	art.hero_action_progress = clampf(action_time / maxf(action_duration, 0.01), 0, 1)
	art.camera_impact = flash * 5.0 if not reduced_motion else 0.0
	flash = maxf(0, flash - delta * 2)
	feedback_time = maxf(0, feedback_time - delta)
	if page == "dialogue" and overlay.is_empty():
		revealed += delta * 38.0
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i].life -= delta
		if floaters[i].life <= 0:
			floaters.remove_at(i)
	if busy and overlay.is_empty():
		action_time += delta
		if not effects_released and action_time >= action_duration * 0.45:
			release_effects()
		if action_time >= action_duration:
			finish_phase()
	if auto_demo and page == "battle" and not busy and overlay.is_empty():
		if combat.player.energy >= 100:
			choose_action("ultimate")
		elif combat.player.hp < combat.player.max_hp * 0.55 and combat.player.heal_charges > 0:
			choose_action("heal")
		elif combat.player.sp >= 2:
			choose_action("skill")
		else:
			choose_action("basic")
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(buttons.size()-1, -1, -1):
			var b = buttons[i]
			if b.rect.has_point(get_global_mouse_position()):
				if b.enabled:
					sound.play_sfx("click")
					activate(b.id)
				return
		if page == "dialogue" and overlay.is_empty():
			next_dialogue()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_ESCAPE:
			overlay = "pause" if overlay.is_empty() else ""
		elif not overlay.is_empty():
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				overlay = ""
		elif page == "dialogue" and event.keycode in [KEY_ENTER, KEY_SPACE]:
			next_dialogue()
		elif page == "battle" and not busy:
			match event.keycode:
				KEY_1: choose_action("basic")
				KEY_2: choose_action("skill")
				KEY_3: choose_action("ultimate")
				KEY_4: choose_action("guard")
				KEY_5: choose_action("heal")
				KEY_TAB, KEY_RIGHT: cycle_target(1)
				KEY_LEFT: cycle_target(-1)

func activate(id: String) -> void:
	if id.begins_with("target:"):
		selected = int(id.get_slice(":",1))
	elif id.begins_with("action:"):
		choose_action(id.get_slice(":",1))
	elif id.begins_with("upgrade:"):
		upgrades.append(id.get_slice(":",1))
		encounter += 1
		open_map()
	else:
		match id:
			"new":
				if not save_data.is_empty(): overlay = "confirm"
				else: new_game()
			"confirm_new": new_game()
			"continue":
				encounter = int(save_data.get("encounter",0))
				upgrades = save_data.get("upgrades",[]).duplicate()
				if save_data.get("completed", false): page = "ending"
				else: open_map()
			"start": show_dialogue(Story.before_battle(encounter), "battle")
			"next": next_dialogue()
			"skip": finish_dialogue()
			"retry": start_battle()
			"menu":
				page = "title"
				overlay = ""
				busy = false
				action_name = "idle"
				sound.set_battle(false)
			"pause": overlay = "pause"
			"help": overlay = "help"
			"credits": overlay = "credits"
			"close": overlay = ""
			"mute":
				muted = not muted
				sound.set_muted(muted)
				save_settings()
			"motion":
				reduced_motion = not reduced_motion
				save_settings()
			"fullscreen": toggle_fullscreen()
			"quit": get_tree().quit()

func new_game() -> void:
	overlay = ""
	encounter = 0
	upgrades = []
	tutorial_seen = false
	save_checkpoint()
	show_dialogue(Story.opening(), "map")

func open_map() -> void:
	page = "map"
	busy = false
	action_name = "idle"
	sound.set_battle(false)
	save_checkpoint()

func show_dialogue(lines: Array, next_page: String) -> void:
	page = "dialogue"
	dialogue = lines
	dialogue_index = 0
	revealed = 0.0
	dialogue_next = next_page
	sound.set_battle(false)
	if dialogue.is_empty(): finish_dialogue()

func next_dialogue() -> void:
	if dialogue.is_empty(): return
	var line: String = dialogue[dialogue_index].text
	if revealed < line.length():
		revealed = line.length()
	else:
		dialogue_index += 1
		revealed = 0.0
		if dialogue_index >= dialogue.size(): finish_dialogue()

func finish_dialogue() -> void:
	match dialogue_next:
		"map": open_map()
		"battle": start_battle()
		"reward": page = "reward"
		"ending":
			page = "ending"
			save_checkpoint(true)

func start_battle() -> void:
	combat.setup(encounter, upgrades)
	page = "battle"
	busy = false
	selected = 0
	effects_released = true
	action_name = "idle"
	floaters.clear()
	current_log.clear()
	current_log.append("Observe as intenções. Quebre a resistência antes do ataque pesado.")
	sound.set_battle(true)
	if not tutorial_seen:
		overlay = "help"
		tutorial_seen = true

func cycle_target(direction: int) -> void:
	for step in range(combat.enemies.size()):
		selected = posmod(selected + direction, combat.enemies.size())
		if combat.enemies[selected].hp > 0: return

func choose_action(action: String) -> void:
	if busy or page != "battle" or not overlay.is_empty(): return
	if combat.enemies[selected].hp <= 0: cycle_target(1)
	staged_enemies = combat.enemies.duplicate(true)
	var result: Dictionary = combat.act(action, selected)
	if not result.get("ok",false):
		feedback = result.get("message", "Ação indisponível")
		feedback_time = 3.0
		return
	last_result = result
	busy = true
	action_phase = "player"
	action_name = action
	action_time = 0
	action_duration = 1.5 if action == "ultimate" else 0.85
	if reduced_motion: action_duration = 0.5
	sound.play_sfx("hit" if action == "basic" else action)
	effects_released = false

func release_effects() -> void:
	effects_released = true
	present_events(last_result)
	flash = 0.65 if action_name == "ultimate" else 0.15

func present_events(result: Dictionary) -> void:
	var message: String = result.get("message", "")
	if not message.is_empty():
		current_log.append(message)
		if current_log.size() > 3: current_log.pop_front()
	for event in result.get("events", []):
		var target: int = int(event.get("target",-1))
		var pos: Vector2 = art.hero_position() if target < 0 else art.enemy_position(target)
		var kind: String = str(event.get("type",""))
		var amount = event.get("amount",0)
		var label: String = str(event.get("text",""))
		var color = PAPER
		if kind == "damage":
			label = "−" + str(amount)
			color = RED if target < 0 else PAPER
		elif kind == "heal" or kind == "support":
			label = "+" + str(amount) if int(amount) > 0 else label
			color = CYAN
		elif kind == "break":
			label = "RUPTURA"
			color = GOLD
			sound.play_sfx("break")
		elif kind == "defend":
			label = "ESCUDO +36"
			color = CYAN
		elif kind == "ultimate":
			continue
		elif kind == "death": continue
		if label.length() > 24:
			current_log.append(label)
			if current_log.size() > 3: current_log.pop_front()
			if "FASE II" in label: label = "FASE II"
			elif "Ruptura" in label: label = "AÇÃO IMPEDIDA"
			elif "energia" in label: label = "−9 ENERGIA"
			elif "Lyra" in label: label = "RESSONÂNCIA"
			else: label = "PREPARANDO"
		if not label.is_empty():
			floaters.append({"pos":pos + Vector2(randf_range(-25,25),-160 - floaters.size()*12),"label":label,"color":color,"life":1.7})

func finish_phase() -> void:
	if not effects_released: release_effects()
	action_time = 0
	action_name = "idle"
	if combat.won:
		busy = false
		sound.play_sfx("win")
		if encounter < 3: show_dialogue(Story.after_battle(encounter), "reward")
		else: show_dialogue(Story.after_battle(encounter) + Story.ending(), "ending")
		return
	if combat.lost:
		busy = false
		page = "defeat"
		sound.set_battle(false)
		sound.play_sfx("lose")
		return
	if action_phase == "player":
		staged_enemies = combat.enemies.duplicate(true)
		last_result = combat.enemies_turn()
		effects_released = false
		action_phase = "enemy"
		action_duration = 0.95 if not reduced_motion else 0.5
		action_name = "hurt"
		sound.play_sfx("hit")
		flash = 0.2
	else:
		busy = false
		if combat.enemies[selected].hp <= 0: cycle_target(1)

func read_save() -> void:
	save_data = {}
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null: return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return
	var parsed = parser.data
	if parsed is Dictionary and parsed.get("version",0) == 1:
		if parsed.get("encounter") is float or parsed.get("encounter") is int:
			if int(parsed.encounter) >= 0 and int(parsed.encounter) <= 3 and parsed.get("upgrades") is Array:
				var safe = true
				for upgrade in parsed.upgrades:
					if upgrade not in ["power","vitality","flow"]: safe = false
				if safe and parsed.upgrades.size() <= 3: save_data = parsed

func save_checkpoint(completed: bool = false) -> void:
	save_data = {"version":1,"encounter":encounter,"upgrades":upgrades.duplicate(),"completed":completed}
	var file = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		feedback = "Não foi possível salvar. Confira a permissão da pasta de dados."
		feedback_time = 5
		return
	file.store_string(JSON.stringify(save_data))
	file.close()
	var err = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		feedback = "O salvamento falhou; mantenha o jogo aberto."
		feedback_time = 5

func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH,FileAccess.READ)
		if file:
			var parser = JSON.new()
			var data = parser.data if parser.parse(file.get_as_text()) == OK else null
			if data is Dictionary:
				muted = bool(data.get("muted",false))
				reduced_motion = bool(data.get("reduced_motion",false))
	sound.set_muted(muted)

func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_PATH,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"muted":muted,"reduced_motion":reduced_motion}))

func toggle_fullscreen() -> void:
	var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

# UI drawing uses viewport coordinates, scaled by Godot with the window.
func _draw() -> void:
	buttons.clear()
	match page:
		"title": draw_title()
		"map": draw_map()
		"dialogue": draw_dialogue()
		"battle": draw_battle()
		"reward": draw_reward()
		"defeat": draw_defeat()
		"ending": draw_ending()
	if page != "title" and page != "battle":
		button(Rect2(1160,28,80,34), "pause", "MENU", true, false, 12)
	if flash > 0 and not reduced_motion and page == "battle":
		draw_rect(Rect2(0,0,1280,720), Color(0.7,0.9,1,flash*0.1))
	for item in floaters:
		var pos: Vector2 = item.pos + Vector2(0,-(1.7-item.life)*38)
		var c: Color = item.color
		c.a = minf(1,item.life*2)
		text(item.label,pos,25,c,true)
	if feedback_time > 0:
		panel(Rect2(280,505,720,50), Color("172d36"), GOLD)
		center(feedback,Vector2(640,536),15,GOLD)
	if not overlay.is_empty(): draw_overlay()

func text(value: String, pos: Vector2, size: int = 18, color: Color = PAPER, serif: bool = false) -> void:
	draw_string(display_font if serif else regular,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(value: String,pos: Vector2,size: int=18,color: Color=PAPER,serif: bool=false) -> void:
	var font = display_font if serif else regular
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(value,pos-Vector2(width*0.5,0),size,color,serif)

func wrapped(value: String, pos: Vector2, width: float, size: int=18, color: Color=PAPER, line_height: float=29) -> float:
	var y = pos.y
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" "):
			var candidate = word if line.is_empty() else line + " " + word
			if regular.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > width and not line.is_empty():
				text(line,Vector2(pos.x,y),size,color)
				y += line_height
				line = word
			else: line = candidate
		text(line,Vector2(pos.x,y),size,color)
		y += line_height
	return y

func panel(rect: Rect2, fill: Color=Color("101c28"), border: Color=Color("314451")) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,border,false,1)
	for p in [rect.position,rect.end-Vector2(8,0)]:
		draw_line(p,p+Vector2(8,0),GOLD,2)

func button(rect: Rect2,id: String,label: String,enabled: bool=true,primary: bool=false,size: int=16) -> void:
	var hover = rect.has_point(mouse) and enabled
	var fill = Color("203641") if hover else Color("10212c")
	var border = GOLD if hover or primary else Color("3c505a")
	if primary: fill = Color("bda16d") if hover else GOLD
	if not enabled:
		fill = Color("131e27")
		border = Color("29363d")
	panel(rect,fill,border)
	center(label,rect.get_center()+Vector2(0,size*0.35),size,INK if primary else (PAPER if enabled else MUTED))
	buttons.append({"rect":rect,"id":id,"enabled":enabled})

func badge(value: String, pos: Vector2, color: Color=GOLD) -> void:
	text(value,pos,12,color)

func bar(rect: Rect2, value: float, max_value: float, color: Color) -> void:
	draw_rect(rect,Color("26343d"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maxf(max_value,1),0,1),rect.size.y)),color)

func draw_title() -> void:
	for i in range(80):
		draw_rect(Rect2(i*12,0,12,720),Color(0.025,0.045,0.068,0.98-float(i)*0.011))
	badge("UM RPG DE ECOS, ESCOLHAS E ESTRELAS",Vector2(66,88),CYAN)
	draw_line(Vector2(66,111),Vector2(141,111),GOLD,2)
	text("WILLIAM",Vector2(59,244),91,PAPER,true)
	text("ECOS DO ÚLTIMO TREM",Vector2(67,288),23,GOLD)
	wrapped("Há destinos que não aparecem nos mapas.\nHá promessas que atravessam o vazio.",Vector2(68,346),580,18,MUTED,30)
	badge("PRÓLOGO  /  A ESTAÇÃO SEM AMANHECER",Vector2(68,435))
	var y = 463.0
	if not save_data.is_empty():
		button(Rect2(68,y,300,52),"continue","Continuar jornada   →",true,true)
		y += 65
	button(Rect2(68,y,300,52),"new","Começar uma jornada   →",true,save_data.is_empty())
	button(Rect2(384,y,154,52),"help","Como jogar")
	button(Rect2(68,y+65,145,38),"credits","Créditos",true,false,13)
	button(Rect2(225,y+65,143,38),"pause","Opções",true,false,13)
	badge("CAMPANHA SOLO     •     COMBATE POR TURNOS     •     v0.1",Vector2(68,688),MUTED)
	badge("VESPER / LINHA 07",Vector2(1030,660),CYAN)

func header(kicker: String, title: String) -> void:
	draw_rect(Rect2(0,0,1280,108),Color(0.03,0.06,0.085,0.94))
	badge(kicker,Vector2(40,34),CYAN)
	text(title,Vector2(40,75),29,PAPER,true)
	draw_line(Vector2(40,101),Vector2(1240,101),Color("3b4d52"),1)

func draw_map() -> void:
	header("DIÁRIO DE VIAGEM  /  PRÓLOGO", "Uma promessa nos trilhos")
	panel(Rect2(40,137,515,410),Color(0.04,0.08,0.11,0.94))
	badge("SEU CAMINHO",Vector2(66,170))
	for i in range(4):
		var y = 211+i*83
		var color = GOLD if i == encounter else (CYAN if i < encounter else MUTED)
		if i < 3: draw_line(Vector2(86,y+10),Vector2(86,y+65),Color("3a525a"),2)
		draw_circle(Vector2(86,y),13,color,false,2)
		center("✓" if i < encounter else str(i+1),Vector2(86,y+5),13,color)
		text(Story.CHAPTERS[i].title,Vector2(118,y+2),19,color)
		text("CONCLUÍDO" if i < encounter else ("VOCÊ ESTÁ AQUI" if i == encounter else "AINDA NOS TRILHOS"),Vector2(119,y+25),11,MUTED)
	panel(Rect2(600,455,640,220),Color(0.04,0.08,0.11,0.96),Color("50635e"))
	badge("PRÓXIMA PARADA  /  %02d" % (encounter+1),Vector2(626,486))
	wrapped(Story.CHAPTERS[encounter].description,Vector2(626,520),570,17,PAPER,26)
	button(Rect2(626,598,405,50),"start","Seguir os trilhos   →",true,true)
	button(Rect2(1045,598,169,50),"help","Guia de combate",true,false,13)
	text("William",Vector2(43,595),23,PAPER,true)
	text("Nível %d  ·  %d memórias despertas" % [upgrades.size()+1,upgrades.size()],Vector2(43,625),15,GOLD)
	badge("PROGRESSO SALVO AUTOMATICAMENTE",Vector2(43,676),MUTED)

func draw_dialogue() -> void:
	header("PRÓLOGO  /  VESPER",Story.CHAPTERS[encounter].title)
	if dialogue.is_empty(): return
	var line: Dictionary = dialogue[mini(dialogue_index,dialogue.size()-1)]
	# Cinematic black bars frame the distant station.
	draw_rect(Rect2(0,108,1280,34),Color(0.01,0.025,0.04,0.8))
	panel(Rect2(56,457,1168,215),Color(0.035,0.068,0.095,0.97),Color("59706b"))
	draw_rect(Rect2(56,457,5,215),GOLD)
	text(str(line.speaker).to_upper(),Vector2(86,494),15,CYAN if str(line.speaker).to_upper() == "LYRA" else GOLD)
	wrapped(str(line.text).left(int(revealed)),Vector2(86,535),1090,20,PAPER,33)
	badge("%02d / %02d" % [dialogue_index+1,dialogue.size()],Vector2(88,647),MUTED)
	button(Rect2(946,620,248,33),"next","Continuar   [ ESPAÇO ]",true,false,13)
	button(Rect2(1045,120,179,32),"skip","Pular esta cena  »",true,false,12)

func draw_battle() -> void:
	draw_rect(Rect2(0,0,1280,108),Color(0.03,0.06,0.085,0.94))
	badge("CONFRONTO %02d / 04     ·     RODADA %02d" % [encounter+1,combat.round_no],Vector2(40,34),CYAN)
	text(Story.CHAPTERS[encounter].title,Vector2(40,75),23,PAPER,true)
	draw_line(Vector2(40,101),Vector2(1240,101),Color("3b4d52"),1)
	button(Rect2(1070,29,79,38),"help","GUIA",true,false,12)
	button(Rect2(1160,29,80,38),"pause","MENU",true,false,12)
	badge("ORDEM",Vector2(610,32),MUTED)
	text("WILLIAM › INIMIGOS · LYRA A CADA 2 RODADAS",Vector2(610,58),11,CYAN)
	text("Ação inimiga" if busy and action_phase == "enemy" else ("Resolvendo técnica" if busy else "Sua vez · escolha uma técnica"),Vector2(610,82),12,GOLD)
	for i in range(combat.enemies.size()):
		var enemy = combat.enemies[i]
		if enemy.hp <= 0: continue
		var pos = art.enemy_position(i)
		var rect = Rect2(pos.x-91,153,182,111)
		panel(rect,Color(0.04,0.08,0.11,0.94),GOLD if i == selected else Color("324c56"))
		text(enemy.name,rect.position+Vector2(10,22),12,PAPER)
		bar(Rect2(rect.position+Vector2(10,34),Vector2(162,5)),float(enemy.hp),float(enemy.max_hp),RED)
		text("%d / %d" % [enemy.hp,enemy.max_hp],rect.position+Vector2(10,55),11,MUTED)
		bar(Rect2(rect.position+Vector2(10,66),Vector2(162,4)),float(enemy.toughness),float(enemy.max_toughness),GOLD)
		text("RUPTURA" if enemy.broken else "%d RES. · FRACO A %s" % [enemy.toughness, str(enemy.weakness).to_upper()],rect.position+Vector2(10,90),10,GOLD)
		buttons.append({"rect":Rect2(pos.x-92,150,184,304),"id":"target:"+str(i),"enabled":not busy})
		if i == selected:
			draw_colored_polygon(PackedVector2Array([pos+Vector2(-8,10),pos+Vector2(8,10),pos+Vector2(0,19)]),GOLD)
		var intent = combat.get_enemy_intent(i)
		wrapped(intent,Vector2(pos.x-85,470),175,10,RED if not enemy.broken else CYAN,16)
	panel(Rect2(40,455,382,98),Color(0.04,0.08,0.11,0.94),Color("476159"))
	text("WILLIAM",Vector2(58,480),15,GOLD)
	text("NV. %d" % (upgrades.size()+1),Vector2(190,479),11,MUTED)
	text("%d / %d PV" % [combat.player.hp,combat.player.max_hp],Vector2(278,480),12,PAPER)
	bar(Rect2(58,491,345,8),float(combat.player.hp),float(combat.player.max_hp),CYAN)
	text("ENERGIA",Vector2(58,525),10,MUTED)
	bar(Rect2(127,517,153,6),float(combat.player.energy),100.0,GOLD)
	text("%d%%" % combat.player.energy,Vector2(292,525),11,GOLD)
	if combat.player.shield > 0: text("ESCUDO %d" % combat.player.shield,Vector2(58,544),10,CYAN)
	text("PONTOS DE HABILIDADE",Vector2(453,519),10,MUTED)
	for i in range(5):
		var p = Vector2(461+i*27,539)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(7,0),p+Vector2(0,7),p+Vector2(-7,0)]),GOLD if i < combat.player.sp else Color("304450"))
	if not current_log.is_empty():
		wrapped(current_log[-1],Vector2(640,520),590,12,MUTED,19)
	draw_rect(Rect2(0,570,1280,150),Color(0.025,0.05,0.075,0.98))
	draw_line(Vector2(40,570),Vector2(1240,570),Color("48615c"),1)
	var actions = [
		["basic","01","Corte errante","Aço · +1 ponto · +18 energia",true],
		["skill","02","Fenda de âmbar","Éter · 2 pontos · +28 energia",combat.player.sp >= 2],
		["ultimate","03","Último alvorecer","100 energia · atinge todos",combat.player.energy >= 100],
		["guard","04","Postura de ferro","Reduz dano · recupera ponto",true],
		["heal","05","Pulso de Lyra","%d cargas nesta luta" % combat.player.heal_charges,combat.player.heal_charges > 0]
	]
	for i in range(actions.size()):
		var a = actions[i]
		var r = Rect2(40+i*244,590,224,86)
		var available: bool = a[4] and not busy
		var hover = r.has_point(mouse) and available
		panel(r,Color("25404a") if hover else Color("11232e"),GOLD if hover or (i == 2 and a[4]) else Color("324752"))
		text(a[1],r.position+Vector2(12,22),11,GOLD if available else MUTED)
		text(a[2],r.position+Vector2(12,46),16,PAPER if available else MUTED)
		text(a[3],r.position+Vector2(12,69),10,CYAN if available else MUTED)
		buttons.append({"rect":r,"id":"action:"+a[0],"enabled":available})
	badge("1–5  TÉCNICAS     /     CLIQUE OU TAB  ALVO     /     ESC  PAUSA",Vector2(42,702),MUTED)
	badge("LYRA  ·  SUPORTE AUTOMÁTICO",Vector2(1003,702),CYAN)
	if busy and action_name == "ultimate":
		draw_rect(Rect2(0,290,1280,100),Color(0.025,0.06,0.09,0.88))
		center("Ú L T I M O   A L V O R E C E R",Vector2(640,347),30,GOLD,true)

func draw_reward() -> void:
	header("CONFRONTO CONCLUÍDO", "Uma memória volta a brilhar")
	center("A viagem transforma William. Escolha um aprimoramento permanente.",Vector2(640,159),18,MUTED)
	var choices = [
		["power","I","Lâmina desperta","DANO","Seus golpes causam mais dano.\nPara encerrar o perigo antes que ele cresça."],
		["vitality","II","Promessa de ferro","VITALIDADE","Mais vida máxima em todos os combates.\nPara continuar de pé quando o mundo ceder."],
		["flow","III","Ressonância","ENERGIA","Comece as batalhas com mais energia e pontos de habilidade.\nPara abrir o caminho com suas melhores técnicas."]
	]
	for i in range(3):
		var r = Rect2(80+i*390,215,340,370)
		panel(r,Color(0.04,0.08,0.11,0.97),Color("53645b"))
		center(choices[i][1],r.position+Vector2(170,70),40,GOLD,true)
		center(choices[i][2],r.position+Vector2(170,125),23,PAPER,true)
		center(choices[i][3],r.position+Vector2(170,156),11,CYAN)
		wrapped(choices[i][4],r.position+Vector2(26,201),288,15,MUTED,24)
		button(Rect2(r.position+Vector2(26,299),Vector2(288,45)),"upgrade:"+choices[i][0],"Despertar memória",true,true,14)
	center("A vida e as cargas de cura são restauradas ao iniciar o próximo confronto.",Vector2(640,644),14,CYAN)

func draw_defeat() -> void:
	draw_rect(Rect2(0,0,1280,720),Color(0.02,0.035,0.05,0.78))
	center("O eco ainda não se apagou.",Vector2(640,264),43,PAPER,true)
	center("Lyra segura sua mão. Há outro caminho pela mesma noite.",Vector2(640,314),18,MUTED)
	center("Use a defesa contra golpes carregados e a habilidade para quebrar resistência.",Vector2(640,365),15,GOLD)
	button(Rect2(405,418,470,56),"retry","Tentar novamente   →",true,true)
	button(Rect2(495,492,290,46),"menu","Voltar ao menu")
	center("Suas memórias permanecem. Nenhum progresso da campanha foi perdido.",Vector2(640,592),13,MUTED)

func draw_ending() -> void:
	for i in range(90):
		draw_rect(Rect2(i*12,0,12,720),Color(0.025,0.05,0.075,0.98-i*0.01))
	badge("PRÓLOGO CONCLUÍDO",Vector2(70,110),CYAN)
	text("O primeiro amanhecer.",Vector2(65,226),46,PAPER,true)
	wrapped("William devolveu a voz à estação. Além do horizonte, outros trilhos ainda chamam pelo seu nome.",Vector2(70,291),605,20,PAPER,33)
	wrapped("Esta pequena campanha termina aqui. A jornada do Último Trem está só começando.",Vector2(70,404),550,17,MUTED,29)
	badge("04 CONFRONTOS    /    03 MEMÓRIAS    /    UMA PROMESSA",Vector2(70,511))
	button(Rect2(70,550,300,55),"new","Jogar novamente",true,true)
	button(Rect2(390,550,190,55),"credits","Créditos")
	text("Obrigado por viajar com William.",Vector2(70,663),15,MUTED)

func draw_overlay() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,720),Color(0.015,0.03,0.045,0.88))
	panel(Rect2(240,70,800,580),Color("10232e"),GOLD)
	if overlay == "help":
		text("O ritmo do combate",Vector2(278,124),31,PAPER,true)
		badge("LEIA A INTENÇÃO. ABRA UMA BRECHA. ATAQUE.",Vector2(280,156),CYAN)
		var tips = [
			["01  CORTE ERRANTE","Recupera 1 ponto. Zerar resistência causa ruptura: impede uma ação e amplia dano."],
			["02  FENDA DE ÂMBAR","Gasta 2 pontos. Éter quebra melhor alvos fracos a Éter; corte básico, os fracos a Aço."],
			["03  ÚLTIMO ALVORECER","Com 100 de energia, desfira um golpe em todos os inimigos. Use contra grupos."],
			["04  POSTURA DE FERRO","Protege William no próximo turno. Observe a intenção vermelha de cada inimigo."],
			["05  PULSO DE LYRA","Recupera vida com cargas limitadas por luta. Lyra também oferece suporte automático."]
		]
		var y = 204.0
		for tip in tips:
			text(tip[0],Vector2(280,y),13,GOLD)
			wrapped(tip[1],Vector2(280,y+24),716,13,MUTED,20)
			y += 69
		button(Rect2(280,573,720,45),"close","Entendi  ·  voltar ao jogo",true,true,15)
	elif overlay == "pause":
		text("Uma pausa nos trilhos",Vector2(280,131),32,PAPER,true)
		button(Rect2(280,178,720,48),"close","Retomar",true,true)
		button(Rect2(280,242,350,46),"mute","Som: " + ("desligado" if muted else "ligado"))
		button(Rect2(650,242,350,46),"motion","Movimento: " + ("reduzido" if reduced_motion else "completo"))
		button(Rect2(280,306,350,46),"fullscreen","Tela cheia / janela  [F11]")
		button(Rect2(650,306,350,46),"help","Guia de combate")
		wrapped("O progresso é salvo entre confrontos. Ao voltar ao menu durante uma luta, ela será reiniciada.",Vector2(280,407),700,15,MUTED,25)
		button(Rect2(280,484,350,48),"menu","Menu principal")
		button(Rect2(650,484,350,48),"quit","Sair do jogo")
		badge("WILLIAM  /  ECOS DO ÚLTIMO TREM  /  v0.1",Vector2(280,596),MUTED)
	elif overlay == "confirm":
		text("Uma nova jornada?",Vector2(280,162),34,PAPER,true)
		wrapped("Começar novamente substitui o progresso salvo desta campanha. As opções de áudio e movimento serão mantidas.",Vector2(280,240),680,20,MUTED,32)
		button(Rect2(280,456,350,52),"close","Continuar minha jornada",true,true)
		button(Rect2(650,456,350,52),"confirm_new","Começar do início")
	elif overlay == "credits":
		text("William",Vector2(280,145),48,PAPER,true)
		text("ECOS DO ÚLTIMO TREM",Vector2(282,184),19,GOLD)
		wrapped("Personagem e direção criativa: Gui571\nProjeto, programação, arte procedural e música: desenvolvido com Codex.\nVisual de William inspirado na ficha fornecida pelo criador.\nMotor: Godot 4.6 · Fontes: DejaVu (licenças no projeto).",Vector2(282,245),700,17,MUTED,32)
		wrapped("Uma obra original inspirada em RPGs de combate por turnos. Sem vínculo com Honkai: Star Rail ou seus criadores.",Vector2(282,448),700,14,MUTED,25)
		button(Rect2(280,565,720,48),"close","Voltar",true,true)
