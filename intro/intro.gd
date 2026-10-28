extends Node2D
## A self-contained introduction. The original campaign stays available in main.tscn.
const Terrain = preload("res://intro/terrain.gd")
const Model = preload("res://intro/intro_model.gd")
const Sprites = preload("res://intro/creatures/sprite_library.gd")
const Audio = preload("res://scripts/soundscape.gd")
const WHITE = Color("f4eedb")
const GOLD = Color("eec984")
const CYAN = Color("99dfda")
const MUTE = Color("a6bdb9")
const DARK = Color("102b30")
var font: Font = preload("res://assets/interface.ttf")
var serif: Font = preload("res://assets/title.ttf")
var terrain: Node2D
var audio: Node
var model = Model.new()
var sprites = Sprites.new()
var page = "title"
var overlay = ""
var seed_value = 72641
var hero = Vector2(450,950)
var guardian_pos = Vector2(1250,750)
var facing = Vector2(1,0)
var camera = Vector2(510,320)
var moving = false
var time = 0.0
var buttons: Array = []
var mouse = Vector2.ZERO
var route: Array[Vector2] = []
var destination = Vector2.INF
var joystick = Vector2.ZERO
var stick_finger = -1
var touch_enabled = true
var reduced_motion = false
var muted = false
var action = "idle"
var action_until = 0.0
var particles: Array = []
var floaters: Array = []
var rings: Array = []
var toast = ""
var toast_until = 0.0
var entries: Array[String] = []
var dialogue: Array = []
var line_index = 0
var revealed = 0.0
var after_dialogue = "explore"
var fade = 1.0
var last_stage = -1
var skills_used: Dictionary = {}
var fauna: Array = []
var story_shown = false
var capture_path = ""
var demo_mode = false
var capture_delay = 3.0
var opening = [
	["VESPER · ALGUMAS HORAS APÓS A PARTIDA", "O último trem cruzou o horizonte e desapareceu. Do outro lado, William encontrou uma floresta que respirava luz."],
	["WILLIAM", "Aurora… então este lugar existe mesmo. Tomás, o que você veio procurar aqui?"],
	["LYRA · TRANSMISSÃO", "Estou ouvindo você. Esses cristais alimentam ruínas mais antigas que a estação. Toque no farol; ele deve reconhecer o bilhete."],
	["WILLIAM", "Árvores sobre máquinas, animais feitos de estrelas… Certo. Um passo de cada vez."]
]

func _ready() -> void:
	terrain = Terrain.new()
	terrain.z_index = -2
	add_child(terrain)
	audio = Audio.new()
	add_child(audio)
	regenerate(seed_value)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--intro-capture="): capture_path = arg.trim_prefix("--intro-capture=")
		if arg == "--intro-demo":
			demo_mode = true
			page = "explore"
			hero = Vector2(1120,790)
			model.interact("beacon")
			camera = hero-Vector2(600,370)
		if arg == "--intro-title": page = "title"
		if arg.begins_with("--intro-seed="): regenerate(int(arg.trim_prefix("--intro-seed=")))
	if not capture_path.is_empty(): capture_later()
	queue_redraw()

func regenerate(value: int) -> void:
	seed_value = value
	terrain.generate(value)
	model.setup(value)
	hero = terrain.spawn_point()
	guardian_pos = Vector2(1250,750)
	for point in terrain.landmarks:
		if point.id == "guardian": guardian_pos = point.pos
	fauna.clear()
	var index = 0
	for pos in terrain.fauna_spawns:
		fauna.append({"home":pos,"pos":pos,"kind":["fox","moth","plant"][index%3],"phase":float(index)*1.73})
		index += 1
	entries.clear()
	skills_used.clear()
	route.clear()
	destination = Vector2.INF
	last_stage = -1
	story_shown = false
	action = "idle"
	terrain.gate_open = false

func begin() -> void:
	regenerate(seed_value)
	camera = hero - Vector2(640,360)
	fade = 1.0
	show_story(opening,"explore")

func _process(delta: float) -> void:
	time += delta
	mouse = get_global_mouse_position()
	fade = maxf(0,fade-delta*0.7)
	moving = false
	if page == "dialogue" and overlay.is_empty(): revealed += delta*35.0
	if page == "explore" and overlay.is_empty():
		move_hero(delta)
		var events: Array = model.update(delta,hero.distance_to(guardian_pos))
		show_events(events)
		if int(model.stage) != last_stage:
			last_stage = model.stage
			stage_changed()
		if model.player.hp <= 0: overlay = "down"
		for creature in fauna:
			if hero.distance_to(creature.pos) < 185 and not entries.has(creature.kind):
				entries.append(creature.kind)
				notify("Códice atualizado · " + creature_name(creature.kind))
	if page == "title":
		camera = camera.lerp(Vector2(680 + sin(time*0.08)*55,350+cos(time*0.11)*30),delta)
	elif page != "end":
		camera = camera.lerp(hero-Vector2(640,370),minf(1,delta*4))
	camera.x = clampf(camera.x,0,1120)
	camera.y = clampf(camera.y,0,880)
	terrain.position = -camera
	terrain.hero_pos = hero
	terrain.active_landmark = int(model.stage)
	terrain.gate_open = int(model.stage) >= 2
	terrain.low_motion = reduced_motion
	if time > action_until: action = "walk" if moving else "idle"
	build_actors(delta)
	for i in range(particles.size()-1,-1,-1):
		particles[i].life -= delta
		particles[i].pos += particles[i].vel*delta
		particles[i].vel *= pow(0.3,delta)
		if particles[i].life <= 0: particles.remove_at(i)
	for i in range(floaters.size()-1,-1,-1):
		floaters[i].life -= delta
		if floaters[i].life <= 0: floaters.remove_at(i)
	for i in range(rings.size()-1,-1,-1):
		rings[i].life -= delta
		if rings[i].life <= 0: rings.remove_at(i)
	queue_redraw()

func build_actors(_delta: float) -> void:
	var actors: Array = []
	var displayed_hero = Vector2(1510,920) if page == "title" else hero
	var hero_actor = sprites.get_actor("william",displayed_hero,moving,facing,time,action)
	if page == "title": hero_actor.scale *= 1.6
	actors.append(hero_actor)
	if not model.guardian.get("defeated",false):
		var guardian = sprites.get_actor("guardian",guardian_pos,false,(hero-guardian_pos).normalized(),time,"action" if model.guardian.get("windup",0)>0 else "idle")
		actors.append(guardian)
	for creature in fauna:
		var phase: float = time*0.22+creature.phase
		var next: Vector2 = creature.home+Vector2(sin(phase)*34,cos(phase*0.7)*19)
		var dir: Vector2 = (next-creature.pos).normalized()
		if terrain.is_walkable(next) or creature.kind == "moth": creature.pos = next
		actors.append(sprites.get_actor(creature.kind,creature.pos,creature.kind != "plant",dir,time+creature.phase,"idle"))
	terrain.actors = actors

func move_hero(delta: float) -> void:
	var direction = joystick
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if direction.length() > 0.12:
		direction = direction.normalized()
		route.clear()
		destination = Vector2.INF
	elif not route.is_empty():
		destination = route[0]
		if hero.distance_to(destination) < 12:
			route.pop_front()
			if route.is_empty(): destination = Vector2.INF
			else: destination = route[0]
	if direction.length() < 0.12 and destination != Vector2.INF:
		var to_goal = destination-hero
		if to_goal.length() > 8: direction = to_goal.normalized()
		else: destination = Vector2.INF
	if direction.length() < 0.12: return
	var speed = 195.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 145.0
	var step = direction*speed*delta
	var previous = hero
	if terrain.is_walkable(hero+step): hero += step
	else:
		if terrain.is_walkable(hero+Vector2(step.x,0)): hero.x += step.x
		if terrain.is_walkable(hero+Vector2(0,step.y)): hero.y += step.y
	moving = hero.distance_to(previous) > 0.01
	if moving: facing = direction
	else:
		destination = Vector2.INF
		route.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_enabled and page == "explore" and overlay.is_empty() and event.position.distance_to(Vector2(112,588)) < 90:
				stick_finger = event.index
				joystick = ((event.position-Vector2(112,588))/55.0).limit_length()
			else: tap(event.position)
		elif event.index == stick_finger:
			stick_finger = -1
			joystick = Vector2.ZERO
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == stick_finger:
		joystick = ((event.position-Vector2(112,588))/55.0).limit_length()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tap(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: overlay = "pause" if overlay.is_empty() else ""
			KEY_F11: toggle_fullscreen()
			KEY_ENTER, KEY_SPACE:
				if page == "dialogue": advance_story()
				elif overlay == "help": overlay = ""
			KEY_1, KEY_Q: cast("flame")
			KEY_2, KEY_E: cast("frost")
			KEY_3, KEY_R: cast("aegis")
			KEY_F: interact_nearby()
			KEY_C: overlay = "codex" if overlay.is_empty() else ""
			KEY_T: toggle_auto()

func tap(point: Vector2) -> void:
	for i in range(buttons.size()-1,-1,-1):
		if buttons[i].rect.has_point(point):
			if buttons[i].enabled:
				audio.play_sfx("click")
				activate(buttons[i].id)
			return
	if not overlay.is_empty(): return
	if page == "dialogue": advance_story()
	elif page == "explore":
		var goal = point+camera
		if terrain.is_walkable(goal):
			destination = goal
			route.clear()
			rings.append({"pos":goal,"life":0.7,"duration":0.7,"color":CYAN,"radius":22.0})

func activate(id: String) -> void:
	match id:
		"begin": begin()
		"reroll": regenerate(posmod(seed_value*1664525+1013904223,999983))
		"pause": overlay = "pause"
		"help": overlay = "help"
		"credits": overlay = "credits"
		"close": overlay = ""
		"next": advance_story()
		"skip": finish_story()
		"interact": interact_nearby()
		"guide": follow_trail()
		"auto": toggle_auto()
		"flame","frost","aegis": cast(id)
		"attack": manual_attack()
		"codex": overlay = "codex"
		"touch": touch_enabled = not touch_enabled
		"motion": reduced_motion = not reduced_motion
		"mute":
			muted = not muted
			audio.set_muted(muted)
		"fullscreen": toggle_fullscreen()
		"menu":
			overlay = ""
			page = "title"
			audio.set_battle(false)
			joystick = Vector2.ZERO
			stick_finger = -1
		"retry":
			model.reset_encounter()
			hero = guardian_pos+Vector2(-160,80)
			overlay = ""
			page = "explore"
		"quit": get_tree().quit()

func cast(skill: String) -> void:
	if page != "explore" or not overlay.is_empty(): return
	var result: Dictionary = model.activate_skill(skill,hero.distance_to(guardian_pos))
	if result.get("ok",false):
		skills_used[skill] = true
		show_events(result.get("events",[]))
	else: notify(result.get("message","Habilidade indisponível."))

func manual_attack() -> void:
	if page != "explore" or not overlay.is_empty(): return
	var result: Dictionary = model.activate_skill("basic",hero.distance_to(guardian_pos))
	if result.get("ok",false): show_events(result.get("events",[]))
	else: notify(result.get("message","Aproxime-se do guardião."))

func toggle_auto() -> void:
	model.auto_combat = not model.auto_combat
	notify("William ataca ao se aproximar." if model.auto_combat else "Ataque automático desligado. Use o botão da espada.")

func interact_nearby() -> void:
	if page != "explore" or not overlay.is_empty(): return
	var goal = current_goal()
	if hero.distance_to(goal.pos) > 130:
		notify("Aproxime-se de " + str(goal.name).to_lower() + ".")
		return
	var result: Dictionary = model.interact(goal.id)
	if result.get("ok",false):
		show_events(result.get("events",[]))
		if goal.id == "beacon":
			show_story([["LYRA", "O farol reconheceu você. Ele despertou o guardião da passagem — um juramento antigo vestido de aço."],["WILLIAM", "Então vou mostrar que sei carregar essa luz."],["LYRA", "Sua lâmina ataca sozinha quando você se aproxima. Você decide quando usar a chama, o gelo e a égide. Observe o círculo no chão antes do golpe dele."]],"explore")
		elif goal.id == "gate":
			show_story([["LYRA", "Há uma cidade do outro lado. Torres flutuantes, sete brasões… e um sinal igual ao do bilhete de Tomás."],["WILLIAM", "Guarde uma luz na janela, irmão. Estou chegando."],["O LIMIAR DE AURORA", "William deu o primeiro passo. E, em algum lugar além dos portões, sete sinos responderam."]],"end")
	else: notify(result.get("message","O farol ainda está em silêncio."))

func current_goal() -> Dictionary:
	var id = "beacon" if model.stage == 0 else ("guardian" if model.stage == 1 else "gate")
	for landmark in terrain.landmarks:
		if landmark.id == id: return landmark
	return {"id":id,"name":"o limiar","pos":guardian_pos}

func follow_trail() -> void:
	var path: Array[Vector2] = [Vector2(450,950),Vector2(780,850),Vector2(1250,750),Vector2(1880,550)]
	var goal = current_goal()
	var nearest = 0
	for i in range(path.size()):
		if hero.distance_to(path[i]) < hero.distance_to(path[nearest]): nearest = i
	var goal_index = 1 if model.stage == 0 else (2 if model.stage == 1 else 3)
	route.clear()
	if hero.distance_to(path[nearest]) > 45: route.append(path[nearest])
	if nearest <= goal_index:
		for i in range(nearest+1,goal_index+1): route.append(path[i])
	else:
		for i in range(nearest-1,goal_index-1,-1): route.append(path[i])
	if route.is_empty(): route.append(goal.pos)
	if model.stage == 1: route[-1] = guardian_pos+Vector2(-135,35)
	notify("Seguindo a trilha · mova-se para retomar o controle.")

func stage_changed() -> void:
	if model.stage == 1:
		notify("O farol despertou · encontre o guardião da passagem.")
	elif model.stage == 2:
		audio.set_battle(false)
		show_story([["O GUARDIÃO", "Chama para ousar. Gelo para compreender. Luz para proteger. Sua vontade pode atravessar o limiar."],["LYRA", "Ele não estava tentando impedir você. Estava perguntando quem você seria do outro lado."],["WILLIAM", "Ainda estou descobrindo. Vamos."]],"explore")
		terrain.gate_open = true

func show_story(lines: Array,next_page: String) -> void:
	page = "dialogue"
	dialogue = lines
	line_index = 0
	revealed = 0
	after_dialogue = next_page
	route.clear()
	destination = Vector2.INF
	joystick = Vector2.ZERO
	stick_finger = -1

func advance_story() -> void:
	if page != "dialogue" or not overlay.is_empty(): return
	if revealed < str(dialogue[line_index][1]).length(): revealed = str(dialogue[line_index][1]).length()
	else:
		line_index += 1
		revealed = 0
		if line_index >= dialogue.size(): finish_story()

func finish_story() -> void:
	page = after_dialogue
	if page == "explore" and not story_shown:
		story_shown = true
		notify("WASD ou toque para caminhar · F para interagir.")
	if page == "end":
		audio.play_sfx("win")
		audio.set_battle(false)

func show_events(events: Array) -> void:
	for event in events:
		var kind: String = event.get("type","")
		var amount: int = int(event.get("amount",0))
		match kind:
			"basic":
				action = "action"
				action_until = time+0.6
				burst(guardian_pos+Vector2(0,-40),GOLD,12)
				floater(guardian_pos,str(amount),WHITE)
				audio.play_sfx("hit")
				facing = (guardian_pos-hero).normalized()
			"flame":
				action = "action"
				action_until = time+0.8
				burst(guardian_pos+Vector2(0,-45),Color("ffb56c"),42)
				rings.append({"pos":guardian_pos,"life":0.8,"duration":0.8,"color":Color("ffad69"),"radius":105.0})
				floater(guardian_pos,str(amount),GOLD)
				audio.play_sfx("skill")
			"frost","break":
				burst(guardian_pos,Color("a1eaff"),30)
				rings.append({"pos":guardian_pos,"life":1.2,"duration":1.2,"color":CYAN,"radius":115.0})
				floater(guardian_pos,"GELO" if kind == "frost" else "RUPTURA",CYAN)
				audio.play_sfx("break")
			"aegis":
				burst(hero,GOLD,45)
				rings.append({"pos":hero,"life":1.2,"duration":1.2,"color":GOLD,"radius":100.0})
				floater(hero,"ÉGIDE",GOLD)
				audio.play_sfx("ultimate")
			"enemy_hit":
				action = "hit"
				action_until = time+0.45
				floater(hero,"−"+str(amount),Color("ffb1a2"))
				burst(hero+Vector2(0,-35),Color("e99980"),10)
				audio.play_sfx("hit")
			"charge":
				notify("O guardião prepara um golpe. Afaste-se ou use Geada!",2)
				audio.set_battle(true)
			"win":
				burst(guardian_pos,GOLD,55)
				audio.play_sfx("win")
			"down": audio.play_sfx("lose")

func notify(message: String,duration: float=3.5) -> void:
	toast = message
	toast_until = time+duration

func burst(pos: Vector2,color: Color,count: int) -> void:
	for i in range(count if not reduced_motion else mini(count,8)):
		var angle = float(i)*TAU/count+randf()*0.35
		particles.append({"pos":pos,"vel":Vector2.from_angle(angle)*randf_range(25,150),"color":color,"life":randf_range(0.5,1.1)})

func floater(pos: Vector2,value: String,color: Color) -> void:
	floaters.append({"pos":pos+Vector2(randf_range(-12,12),-100),"text":value,"color":color,"life":1.1})

func creature_name(kind: String) -> String:
	return {"fox":"Raposa de bruma","moth":"Asa de aurora","plant":"Vigia do bosque"}.get(kind,kind)

func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func capture_later() -> void:
	await get_tree().create_timer(capture_delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(capture_path)
	get_tree().quit()

func _draw() -> void:
	buttons.clear()
	draw_world_effects()
	match page:
		"title": draw_title()
		"dialogue": draw_dialogue()
		"explore": draw_hud()
		"end": draw_end()
	if time < toast_until and page == "explore":
		panel(Rect2(310,156,660,44),Color(0.03,0.10,0.12,0.93),Color("739a91"))
		center(toast,Vector2(640,184),13,WHITE)
	if not overlay.is_empty(): draw_overlay()
	if fade > 0: draw_rect(Rect2(0,0,1280,720),Color(0.025,0.055,0.075,fade))

func draw_world_effects() -> void:
	if page == "explore" and model.guardian.get("active",false) and not model.guardian.get("defeated",false):
		var gp = guardian_pos-camera
		var windup: float = float(model.guardian.get("windup",0))
		draw_arc(gp,150,0,TAU,64,Color(0.9,0.55,0.32,0.18),1)
		if windup > 0:
			draw_circle(gp,Model.ENEMY_RANGE,Color(1,0.35,0.2,0.08+sin(time*12)*0.025))
			draw_arc(gp,Model.ENEMY_RANGE,0,TAU,60,Color("f4a17b"),2)
		if model.player.shield > 0:
			draw_arc(hero-camera-Vector2(0,35),53,0,TAU,40,GOLD,2)
	if page == "explore":
		var goal = current_goal()
		var p: Vector2 = goal.pos-camera
		draw_arc(p,39+sin(time*2)*3,0,TAU,48,Color(GOLD,0.5),2)
		if p.x < 45 or p.x > 1235 or p.y < 120 or p.y > 570:
			var marker = Vector2(clampf(p.x,45,1235),clampf(p.y,165,540))
			draw_circle(marker,15,Color(0.05,0.14,0.16,0.9))
			center("✦",marker+Vector2(0,6),20,GOLD)
	for ring in rings:
		var progress: float = 1-ring.life/ring.duration
		draw_arc(ring.pos-camera,ring.radius*progress,0,TAU,42,Color(ring.color,1-progress),2)
	for p in particles:
		draw_rect(Rect2(p.pos-camera,Vector2(3,3)),Color(p.color,minf(1,p.life*2)))
	for f in floaters:
		center(f.text,f.pos-camera+Vector2(0,-(1.1-f.life)*38),22,Color(f.color,minf(1,f.life*3)))

func label(value: String,pos: Vector2,size: int=16,color: Color=WHITE,display: bool=false) -> void:
	draw_string(serif if display else font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(value: String,pos: Vector2,size: int=16,color: Color=WHITE,display: bool=false) -> void:
	var f = serif if display else font
	label(value,pos-Vector2(f.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,0),size,color,display)

func wrap_text(value: String,pos: Vector2,width: float,size: int=17,color: Color=WHITE,spacing: float=28) -> void:
	var y = pos.y
	for paragraph in value.split("\n"):
		var line = ""
		for word in paragraph.split(" "):
			var candidate = word if line.is_empty() else line+" "+word
			if font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and not line.is_empty():
				label(line,Vector2(pos.x,y),size,color)
				y += spacing
				line = word
			else: line = candidate
		label(line,Vector2(pos.x,y),size,color)
		y += spacing

func panel(rect: Rect2,color: Color=Color(0.035,0.105,0.125,0.94),edge: Color=Color("416264")) -> void:
	draw_style_box(style(color,edge),rect)

func style(color: Color,edge: Color) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box

func button(rect: Rect2,id: String,value: String,primary: bool=false,enabled: bool=true,size: int=14) -> void:
	var hover = rect.has_point(mouse) and enabled
	panel(rect,(GOLD if primary else (Color("254b50") if hover else Color(0.04,0.13,0.15,0.93))),GOLD if primary or hover else Color("587b77"))
	center(value,rect.get_center()+Vector2(0,size*0.35),size,DARK if primary else (WHITE if enabled else MUTE))
	buttons.append({"rect":rect,"id":id,"enabled":enabled})

func meter(rect: Rect2,value: float,maximum: float,color: Color) -> void:
	draw_rect(rect,Color("254449"))
	draw_rect(Rect2(rect.position,Vector2(rect.size.x*clampf(value/maxf(1,maximum),0,1),rect.size.y)),color)

func draw_title() -> void:
	for i in range(90):
		draw_rect(Rect2(i*11,0,11,720),Color(0.018,0.055,0.075,maxf(0,0.96-i*0.0105)))
	label("UM NOVO MUNDO ALÉM DOS TRILHOS",Vector2(64,105),12,CYAN)
	draw_line(Vector2(64,130),Vector2(139,130),GOLD,2)
	label("WILLIAM",Vector2(58,257),84,WHITE,true)
	label("L I M I A R   D E   A U R O R A",Vector2(64,306),20,GOLD)
	wrap_text("Onde a natureza guarda antigas máquinas,\ne cada criatura carrega uma centelha.",Vector2(66,368),570,18,MUTE,30)
	label("INTRODUÇÃO INTERATIVA",Vector2(66,459),12,CYAN)
	button(Rect2(65,481,340,57),"begin","Atravessar o limiar     →",true,true,17)
	button(Rect2(65,554,165,43),"help","Como jogar")
	button(Rect2(244,554,161,43),"reroll","Outro vale")
	button(Rect2(65,612,165,35),"credits","Referências e créditos",false,true,11)
	button(Rect2(244,612,161,35),"pause","Opções",false,true,12)
	label("FANTASIA PROCEDURAL  /  UMA PEQUENA PRIMEIRA VIAGEM",Vector2(65,687),10,MUTE)
	label("AURORA · VALE DOS PRIMEIROS ECOS",Vector2(949,671),10,WHITE)

func draw_hud() -> void:
	panel(Rect2(26,24,400,82))
	label("O LIMIAR DE AURORA",Vector2(45,48),11,GOLD)
	var objectives = ["Desperte o farol adormecido","Encontre o guardião da passagem","Atravesse o portal de Aurora","Introdução concluída"]
	label(objectives[mini(int(model.stage),3)],Vector2(45,76),17,WHITE)
	button(Rect2(442,24,126,38),"guide","Seguir trilha",false,true,12)
	button(Rect2(1066,24,80,38),"codex","CÓDICE",false,true,11)
	button(Rect2(1160,24,94,38),"pause","MENU",false,true,11)
	if model.guardian.get("active",false) and not model.guardian.get("defeated",false):
		panel(Rect2(452,78,376,62))
		center("CAVALEIRO DO LIMIAR  ·  AÇO / LUZ",Vector2(640,101),11,GOLD)
		meter(Rect2(469,114,342,7),float(model.guardian.hp),float(model.guardian.max_hp),Color("d6af75"))
	var goal = current_goal()
	if hero.distance_to(goal.pos)<130 and model.stage != 1:
		button(Rect2(480,468,320,46),"interact",("Despertar farol" if model.stage == 0 else "Atravessar portal")+"   [F]",true)
	panel(Rect2(26,648,350,49))
	label("WILLIAM",Vector2(42,668),11,GOLD)
	label("%d / %d" % [model.player.hp,model.player.max_hp],Vector2(276,668),10,WHITE)
	label("ÉTER %d" % model.player.energy,Vector2(166,668),10,GOLD)
	meter(Rect2(42,677,315,5),float(model.player.hp),float(model.player.max_hp),CYAN)
	meter(Rect2(42,687,315,3),float(model.player.energy),100,GOLD)
	if touch_enabled:
		draw_circle(Vector2(112,588),57,Color(0.03,0.12,0.15,0.5))
		draw_arc(Vector2(112,588),57,0,TAU,48,Color(0.7,0.85,0.82,0.45),1)
		draw_circle(Vector2(112,588)+joystick*36,21,Color(0.55,0.75,0.72,0.35))
		center("MOVER",Vector2(112,592),9,WHITE)
	else: label("WASD / SETAS · CAMINHAR",Vector2(28,624),11,MUTE)
	button(Rect2(836,518,168,34),"auto","AUTO " + ("LIGADO" if model.auto_combat else "DESLIGADO")+"  [T]",false,true,10)
	button(Rect2(1016,518,238,34),"attack","ATAQUE BÁSICO",false,int(model.stage)==1,10)
	var skill_info = [["flame","CHAMA","1 / Q",Color("efbb82"),"20 éter · dano"],["frost","GEADA","2 / E",Color("a1dce5"),"15 éter · congela"],["aegis","ÉGIDE","3 / R",GOLD,"70 éter · égide"]]
	for i in range(3):
		var info = skill_info[i]
		var rect = Rect2(836+i*144,566,130,109)
		var cooldown: float = float(model.cooldowns.get(info[0],0))
		var available = cooldown<=0 and int(model.stage)==1 and model.player.energy >= [20,15,70][i]
		panel(rect,Color(0.04,0.12,0.15,0.95),info[3] if available else Color("456167"))
		var p = rect.position+Vector2(25,30)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-12),p+Vector2(10,0),p+Vector2(0,12),p+Vector2(-10,0)]),info[3])
		label(info[2],rect.position+Vector2(80,33),10,MUTE)
		label(info[1],rect.position+Vector2(14,65),14,info[3])
		label("%.1fs" % cooldown if cooldown>0 else info[4],rect.position+Vector2(14,89),11,MUTE)
		buttons.append({"rect":rect,"id":info[0],"enabled":true})
	label("%d / 3 ESPÉCIES NO CÓDICE" % entries.size(),Vector2(450,688),10,MUTE)

func draw_dialogue() -> void:
	draw_rect(Rect2(0,0,1280,70),Color(0.01,0.035,0.055,0.86))
	label("WILLIAM / LIMIAR DE AURORA",Vector2(40,43),12,GOLD)
	button(Rect2(1080,22,160,32),"skip","Pular esta cena",false,true,11)
	panel(Rect2(60,498,1160,187),Color(0.025,0.085,0.11,0.97),Color("76958a"))
	if line_index >= dialogue.size(): return
	label(dialogue[line_index][0],Vector2(86,530),13,CYAN if "LYRA" in dialogue[line_index][0] else GOLD)
	wrap_text(str(dialogue[line_index][1]).left(int(revealed)),Vector2(86,567),1102,19,WHITE,31)
	label("%02d / %02d" % [line_index+1,dialogue.size()],Vector2(88,664),11,MUTE)
	button(Rect2(959,642,232,29),"next","Continuar   ·   Espaço",false,true,12)

func draw_end() -> void:
	for i in range(120): draw_rect(Rect2(i*11,0,11,720),Color(0.02,0.065,0.08,0.9))
	center("FIM DA INTRODUÇÃO",Vector2(640,151),12,CYAN)
	center("O mundo começou a responder.",Vector2(640,255),42,WHITE,true)
	center("Além dos portões, sete brasões esperam por William.",Vector2(640,316),19,MUTE)
	center("A primeira travessia termina aqui. A promessa continua.",Vector2(640,351),17,MUTE)
	center("%d ESPÉCIES ENCONTRADAS     /     %d PODERES EXPERIMENTADOS" % [entries.size(),skills_used.size()],Vector2(640,419),12,GOLD)
	button(Rect2(340,484,290,53),"begin","Revisitar este vale",true)
	button(Rect2(650,484,290,53),"menu","Voltar ao título")
	center("William · Limiar de Aurora",Vector2(640,643),15,WHITE,true)

func draw_overlay() -> void:
	buttons.clear()
	draw_rect(Rect2(0,0,1280,720),Color(0.015,0.04,0.055,0.87))
	panel(Rect2(240,85,800,550),Color("112e34"),Color("a5b79b"))
	match overlay:
		"help":
			label("Seu primeiro passo em Aurora",Vector2(280,143),29,WHITE,true)
			var tips = [
				["EXPLORE","WASD / setas, clique no chão ou use o controle de toque. F interage com farol e portal."],
				["UMA LÂMINA, SUA DECISÃO","O ataque básico é automático perto do guardião. T liga/desliga; o botão da espada ataca manualmente."],
				["1 / Q · CHAMA     2 / E · GEADA","Chama causa dano. Geada interrompe o golpe anunciado pelo círculo vermelho. Afaste-se para evitá-lo."],
				["3 / R · ÉGIDE","Proteção e poder de luz. Ataques geram energia; acompanhe os custos e intervalos de cada habilidade."],
				["O VALE VIVO","Aproxime-se das criaturas para conhecê-las no códice (C). “Seguir trilha” ajuda a encontrar o objetivo."]
			]
			for i in range(tips.size()):
				label(tips[i][0],Vector2(280,193+i*72),12,GOLD)
				wrap_text(tips[i][1],Vector2(280,217+i*72),715,14,MUTE,22)
			button(Rect2(280,573,720,40),"close","Entendi",true)
		"pause":
			label("Um instante entre mundos",Vector2(280,153),30,WHITE,true)
			button(Rect2(280,195,720,46),"close","Retomar",true)
			button(Rect2(280,262,350,44),"mute","Som: "+("desligado" if muted else "ligado"))
			button(Rect2(650,262,350,44),"touch","Controle de toque: "+("sim" if touch_enabled else "não"))
			button(Rect2(280,322,350,44),"motion","Movimento: "+("reduzido" if reduced_motion else "completo"))
			button(Rect2(650,322,350,44),"fullscreen","Tela cheia / janela  [F11]")
			button(Rect2(280,382,350,44),"help","Como jogar")
			button(Rect2(650,382,350,44),"credits","Referências e créditos")
			label("Voltar ao título reinicia esta pequena introdução ao começar outra vez.",Vector2(280,481),13,MUTE)
			button(Rect2(280,527,350,48),"menu","Título")
			button(Rect2(650,527,350,48),"quit","Sair")
		"down":
			label("Ainda há luz na sua lâmina.",Vector2(280,180),34,WHITE,true)
			wrap_text("O guardião aguarda uma nova tentativa. Experimente interromper o golpe carregado com Geada ou sair do círculo antes do impacto.",Vector2(280,270),700,19,MUTE,31)
			button(Rect2(280,458,720,54),"retry","Tentar novamente",true)
		"credits":
			label("Um mundo feito de possibilidades",Vector2(280,147),29,WHITE,true)
			wrap_text("William: personagem e direção criativa de Gui571.\nHistória, integração e apresentação desenvolvidas com Codex.\n\nCriaturas: Procedural Pixel Creatures, de idlerunner00 (MIT).\nReferência de terreno: Cartoon Terrain Studio, de idlerunner00 (MIT).\nMotor Godot 4.6.3 · Fontes DejaVu · Música procedural original.\n\nFantasia original inspirada no espírito de RPGs modernos. Sem vínculo com Seven Knights ou seus criadores.",Vector2(280,204),715,16,MUTE,29)
			button(Rect2(280,564,720,46),"close","Voltar",true)
		"codex":
			label("Códice do limiar",Vector2(280,148),32,WHITE,true)
			label("A vida encontra caminhos onde as máquinas dormem.",Vector2(280,182),15,MUTE)
			var kinds = ["fox","moth","plant"]
			var desc = ["Uma criatura veloz que fareja o rastro dos cristais. Aproxima-se dos viajantes sem fazer ruído.","Suas asas refletem a luz que restou entre as árvores. Dizem que acompanha os sonhos.","Um pequeno sentinela da floresta. Guarda raízes tão antigas quanto as torres de Aurora."]
			for i in range(3):
				var known = entries.has(kinds[i])
				label(creature_name(kinds[i]) if known else "Espécie desconhecida",Vector2(280,240+i*102),20,GOLD if known else MUTE,true)
				wrap_text(desc[i] if known else "Explore as bordas da trilha e aproxime-se de uma criatura para descobri-la.",Vector2(280,269+i*102),705,14,MUTE,22)
			button(Rect2(280,568,720,44),"close","Voltar ao vale",true)
