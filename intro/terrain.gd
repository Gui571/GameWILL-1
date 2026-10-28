extends Node2D
## An original seeded diorama inspired by Cartoon Terrain Studio's terraced,
## ink-outlined landscapes. No external renderer or editor is required at runtime.
## Coordinates are world-space. Actors may supply a source-pixel `pivot`.

var actors: Array = []
var t: float = 0.0
var active_landmark: int = 0
var gate_open: bool = false
var hero_pos := Vector2(450, 950)
var low_motion: bool = false
var landmarks: Array = [
	{"id":"beacon", "name":"Farol adormecido", "pos":Vector2(780,850)},
	{"id":"guardian", "name":"Santuário das três correntes", "pos":Vector2(1250,750)},
	{"id":"gate", "name":"O limiar de Aurora", "pos":Vector2(1880,550)}
]
var fauna_spawns: Array = []
var seed_value: int = 71421
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _outline := PackedVector2Array()
var _terraces: Array = []
var _trees: Array = []
var _rocks: Array = []
var _grass: Array = []
var _flowers: Array = []
var _river := PackedVector2Array()
var _river_bank := PackedVector2Array()
var _ponds: Array = []
var _route := PackedVector2Array([Vector2(380,1040), Vector2(450,950), Vector2(640,910), Vector2(780,850), Vector2(970,825), Vector2(1110,790), Vector2(1250,750), Vector2(1450,750), Vector2(1650,650), Vector2(1880,550), Vector2(2050,510)])
var _view := Rect2()
const INK := Color("102a32")
const GOLD := Color("e2be73")
const CYAN := Color("80e3df")
const WORLD_RECT := Rect2(0,0,2400,1600)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _outline.is_empty(): generate(seed_value)

func _process(delta: float) -> void:
	if not low_motion: t += delta
	queue_redraw()

func spawn_point() -> Vector2:
	return Vector2(450,950)

func generate(value: int) -> void:
	seed_value = value
	_rng.seed = value
	_noise.seed = value
	_noise.frequency = 0.0028
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_terraces.clear()
	_trees.clear()
	_rocks.clear()
	_grass.clear()
	_flowers.clear()
	_ponds.clear()
	fauna_spawns.clear()
	_outline = PackedVector2Array()
	for i in range(96):
		var a := TAU * float(i) / 96.0
		var n := 1.0 + _noise.get_noise_2d(cos(a)*750+240,sin(a)*750-130)*0.105
		_outline.append(Vector2(1200+cos(a)*1120*n, 865+sin(a)*575*n))
	# Terraces grow outside the guaranteed story corridor.
	for center_point in [Vector2(440,540),Vector2(825,420),Vector2(1510,325),Vector2(2010,805),Vector2(1570,1180),Vector2(420,1270)]:
		var p: Vector2 = center_point + Vector2(_rng.randf_range(-65,65),_rng.randf_range(-45,45))
		var radius := Vector2(_rng.randf_range(140,240), _rng.randf_range(85,130))
		var poly := _blob(p,radius,_rng.randf()*9,24)
		_terraces.append({"poly":poly,"p":p,"radius":radius,"depth":_rng.randf_range(46,86),"shade":_rng.randf_range(0,0.11)})
	_ponds.append({"p":Vector2(690,1180),"radius":Vector2(205,100),"poly":_blob(Vector2(690,1180),Vector2(205,100),2.4,40)})
	_ponds.append({"p":Vector2(1625,430),"radius":Vector2(165,85),"poly":_blob(Vector2(1625,430),Vector2(165,85),4.3,36)})
	_river = _river_shape(35.0)
	_river_bank = _river_shape(49.0)
	for i in range(2500):
		var p := Vector2(_rng.randf_range(120,2270), _rng.randf_range(290,1420))
		if not _on_land(p) or _on_water(p) or _path_distance(p) < 50: continue
		_grass.append({"p":p,"color":Color("8d9a69").lerp(Color("3f6854"),_rng.randf()),"size":_rng.randf_range(2,5),"lean":_rng.randf_range(-2,2)})
	for i in range(235):
		var p := Vector2(_rng.randf_range(130,2290),_rng.randf_range(320,1380))
		if not _on_land(p) or _on_water(p) or _path_distance(p) < 110: continue
		if p.distance_to(Vector2(1880,550)) < 180: continue
		var radius := _rng.randf_range(28,55)
		var h := _rng.randf_range(65,118)
		var variant := _rng.randi_range(0,4)
		_trees.append({"p":p,"r":radius,"h":h,"variant":variant,"phase":_rng.randf()*TAU,"blob":_blob(Vector2.ZERO,Vector2(radius,radius*0.75),_rng.randf()*10,15)})
	for i in range(74):
		var p := Vector2(_rng.randf_range(160,2240),_rng.randf_range(400,1370))
		if not _on_land(p) or _on_water(p) or _path_distance(p)<90: continue
		_rocks.append({"p":p,"size":_rng.randf_range(9,25),"phase":_rng.randf()*6})
	for i in range(200):
		var p := Vector2(_rng.randf_range(180,2240),_rng.randf_range(400,1370))
		if not _on_land(p) or _on_water(p) or _path_distance(p)<64: continue
		_flowers.append({"p":p,"color":Color("bc97cd") if i%3 else Color("c8d79b"),"phase":_rng.randf()*6})
	for p in [Vector2(590,1030),Vector2(860,1030),Vector2(1290,920),Vector2(1450,600),Vector2(1770,770),Vector2(2000,640)]:
		fauna_spawns.append(p + Vector2(_rng.randf_range(-15,15),_rng.randf_range(-15,15)))
	queue_redraw()

func _blob(center: Vector2, radius: Vector2, phase: float, count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(count):
		var a := TAU * float(i)/count
		var r := 1.0 + sin(a*3+phase)*0.065 + sin(a*7+phase*2)*0.035
		out.append(center + Vector2(cos(a)*radius.x*r,sin(a)*radius.y*r))
	return out

func _river_x(y: float) -> float:
	return 1080.0 + sin((y-350)*0.006)*32.0 + (y-700)*0.065

func _river_shape(width: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(51):
		var y := 280+i*23.0
		points.append(Vector2(_river_x(y)-width-sin(y*0.018)*5,y))
	for i in range(50,-1,-1):
		var y := 280+i*23.0
		points.append(Vector2(_river_x(y)+width+sin(y*0.014)*6,y))
	return points

func _path_distance(p: Vector2) -> float:
	var distance := 100000.0
	for i in range(_route.size()-1):
		distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,_route[i],_route[i+1])))
	return distance

func _on_land(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p,_outline)

func _on_water(p: Vector2) -> bool:
	if absf(p.x-_river_x(p.y))<44 and p.y>280 and p.y<1430: return true
	for pond in _ponds:
		if Geometry2D.is_point_in_polygon(p,pond.poly): return true
	return false

func is_walkable(p: Vector2) -> bool:
	if not WORLD_RECT.has_point(p) or not _on_land(p): return false
	if _path_distance(p)<74: return true
	if _on_water(p): return false
	for terrace in _terraces:
		if Geometry2D.is_point_in_polygon(p,terrace.poly): return false
	for tree in _trees:
		if p.distance_squared_to(tree.p)<15*15: return false
	for rock in _rocks:
		if p.distance_squared_to(rock.p)<rock.size*rock.size*0.6: return false
	return true

func _draw() -> void:
	if _outline.is_empty(): return
	var inv := get_global_transform_with_canvas().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * get_viewport_rect().size
	_view = Rect2(a,b-a).abs().grow(180)
	_draw_void()
	_draw_island()
	_draw_water()
	_draw_path()
	_draw_terraces()
	_draw_grass()
	_draw_bridge()
	_draw_landmark_floors()
	var ordered: Array = []
	for tree in _trees:
		if _view.has_point(tree.p): ordered.append({"y":tree.p.y,"type":"tree","data":tree})
	for rock in _rocks:
		if _view.has_point(rock.p): ordered.append({"y":rock.p.y,"type":"rock","data":rock})
	for actor in actors:
		if _view.has_point(actor.get("pos",Vector2.ZERO)):
			ordered.append({"y":actor.get("pos",Vector2.ZERO).y,"type":"actor","data":actor})
	ordered.append({"y":850.0,"type":"rune","data":{}})
	ordered.append({"y":550.0,"type":"gate","data":{}})
	ordered.append({"y":975.0,"type":"camp","data":{}})
	for p in [Vector2(560,890),Vector2(960,760),Vector2(1190,825),Vector2(1540,632),Vector2(1775,530),Vector2(1995,520)]:
		ordered.append({"y":p.y,"type":"lamp","data":{"p":p}})
	ordered.sort_custom(func(x,y): return x.y < y.y)
	for item in ordered:
		match item.type:
			"tree": _draw_tree(item.data)
			"rock": _draw_rock(item.data)
			"actor": _draw_actor(item.data)
			"rune": _draw_rune()
			"gate": _draw_gate()
			"camp": _draw_camp()
			"lamp": _draw_lamp(item.data.p)
	_draw_atmosphere()

func _draw_void() -> void:
	draw_rect(Rect2(-1000,-800,4400,3300),Color("102630"))
	for i in range(26):
		var y := -120+i*80.0
		draw_line(Vector2(-500,y),Vector2(2900,y+95),Color(0.15,0.29,0.33,0.08),40)
	for i in range(35):
		var p := Vector2(fposmod(i*271.7+seed_value,2500),fposmod(i*137.8,1700))
		if not _on_land(p):
			draw_circle(p,2,Color(0.65,0.85,0.82,0.2+sin(t+i)*0.1))

func _shifted(poly: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly: out.append(p+offset)
	return out

func _ink(poly: PackedVector2Array, color: Color, width: float=2.0) -> void:
	if poly.size()<3: return
	draw_colored_polygon(poly,color)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline,INK,width,true)

func _draw_island() -> void:
	_ink(_shifted(_outline,Vector2(0,123)),Color("152e38"),4)
	for i in range(8,-1,-1):
		var offset := Vector2(0,18+i*11)
		var shade := Color("354c48").lerp(Color("203b40"),float(i)/9)
		_ink(_shifted(_outline,offset),shade,2)
	_ink(_outline,Color("456b56"),4)
	# Thin moss-covered lip gives the upper platform depth.
	draw_polyline(_outline,Color("83946c"),4,true)
	for i in range(0,_outline.size(),3):
		var p: Vector2 = _outline[i]
		if p.y>800:
			draw_line(p+Vector2(2,18),p+Vector2(8+sin(i)*9,80),Color("24413d"),3)
			draw_line(p+Vector2(-7,28),p+Vector2(-1,68),Color("668066"),1)
	# Soft, low-frequency meadow patches follow the island's shape.
	for i in range(35):
		var p := Vector2(300+fposmod(i*323.7,1800),450+fposmod(i*197.3,780))
		if not _on_land(p): continue
		var patch := _blob(p,Vector2(100+i%4*19,50+i%3*15),i*1.7,12)
		draw_colored_polygon(patch,Color(0.39,0.47,0.32,0.07))

func _draw_water() -> void:
	_ink(_river_bank,Color("7a8e70"),3)
	_ink(_river,Color("2c7277"),2)
	for pond in _ponds:
		_ink(_shifted(pond.poly,Vector2(0,5)),Color("9caa7d"),3)
		_ink(pond.poly,Color("337b7c"),2)
		for j in range(8):
			var y: float = pond.p.y-50+j*15
			var w: float = sin((float(j)+1)/9*PI)*pond.radius.x*0.8
			draw_line(Vector2(pond.p.x-w,y),Vector2(pond.p.x+w,y),Color(0.47,0.83,0.78,0.12),2)
		for j in range(6):
			var p: Vector2 = pond.p+Vector2(sin(j*7.4)*pond.radius.x*.6,cos(j*4.1)*pond.radius.y*.65)
			_ellipse(p,Vector2(9,4),Color("699878"))
			draw_line(p+Vector2(-5,0),p,Color("244b43"),1)
	for i in range(52):
		var y := 300 + fposmod(i*31.1+t*14,1070)
		var x := _river_x(y)+sin(i*12.8)*24
		if _view.has_point(Vector2(x,y)):
			draw_line(Vector2(x-7,y),Vector2(x+8,y),Color(0.66,0.92,0.85,0.25),1.5)
	# Waterfall at the southern rim; strips remain visible from the bank.
	var waterfall := Vector2(_river_x(1380),1380)
	for i in range(12):
		var x := waterfall.x-32+i*5.8
		draw_line(Vector2(x,waterfall.y),Vector2(x+7,waterfall.y+130),Color(0.34,0.72,0.74,0.55),6)
		var y := waterfall.y+fposmod(i*29+t*95,130)
		draw_line(Vector2(x,y),Vector2(x+1,y+22),Color(0.77,0.94,0.87,0.6),2)
	for i in range(4):
		_ellipse(waterfall+Vector2(8,135+i*5),Vector2(50+i*8,12+i*3),Color(0.61,0.88,0.85,0.06))

func _draw_path() -> void:
	draw_polyline(_route,Color("203e3b"),148,true)
	for p in _route: draw_circle(p,74,Color("203e3b"))
	draw_polyline(_route,Color("637859"),138,true)
	for p in _route: draw_circle(p,69,Color("637859"))
	draw_polyline(_route,Color("95916b"),113,true)
	for p in _route: draw_circle(p,56.5,Color("95916b"))
	draw_polyline(_route,Color("a49b73"),89,true)
	for p in _route: draw_circle(p,44.5,Color("a49b73"))
	for i in range(85):
		var p := _route_point(float(i)/84)+Vector2(sin(i*23.7)*42,cos(i*13.1)*23)
		var poly := _blob(p,Vector2(3+i%3,2),i,5)
		draw_colored_polygon(poly,Color("7c8261"))
		if i%3==0:
			draw_line(p+Vector2(-3,-1),p+Vector2(2,-1),Color("b5ab7d"),1)

func _route_point(weight: float) -> Vector2:
	var scaled := clampf(weight,0,0.99999)*(_route.size()-1)
	var idx := int(scaled)
	return _route[idx].lerp(_route[idx+1],scaled-idx)

func _draw_terraces() -> void:
	for terrace in _terraces:
		var poly: PackedVector2Array = terrace.poly
		var depth: float = terrace.depth
		_ink(_shifted(poly,Vector2(0,depth)),Color("243e3e"),3)
		for j in range(5,-1,-1):
			_ink(_shifted(poly,Vector2(0,float(j)*depth/6)),Color("52675a").darkened(float(j)*0.055),2)
		_ink(poly,Color("6d8562").darkened(terrace.shade),2)
		draw_polyline(poly,Color("a5ac7a"),2,true)
		for j in range(6):
			var p: Vector2 = terrace.p+Vector2((j-3)*35,terrace.radius.y*0.8)
			draw_line(p+Vector2(0,13),p+Vector2(5,depth*0.8),Color("2b4841"),2)
		# Sparse geometric rocks on the terrace, with tiny cypress silhouettes.
		for j in range(3):
			var p: Vector2 = terrace.p+Vector2((j-1)*48,-15+sin(j+terrace.p.x)*15)
			_draw_rock({"p":p,"size":18.0,"phase":float(j)})

func _draw_grass() -> void:
	for grass in _grass:
		var p: Vector2 = grass.p
		if not _view.has_point(p): continue
		var s: float = grass.size
		draw_line(p,p+Vector2(-1+grass.lean,-s),grass.color,1)
		if s>3.5: draw_line(p+Vector2(2,0),p+Vector2(4+grass.lean,-s*.8),grass.color.darkened(.1),1)
	for flower in _flowers:
		var p: Vector2 = flower.p
		if not _view.has_point(p): continue
		var sway := sin(t*1.6+flower.phase)*1.3
		draw_line(p,p+Vector2(sway,-7),Color("28483f"),1)
		draw_circle(p+Vector2(sway,-8),2.6,flower.color)
		draw_circle(p+Vector2(sway+3,-6),2,flower.color.darkened(.15))
		draw_circle(p+Vector2(sway,-8),.8,Color("f0dbaf"))

func _draw_bridge() -> void:
	var center := Vector2(1090,795)
	var angle := -0.20
	draw_set_transform(center,angle)
	_ink(PackedVector2Array([Vector2(-104,-70),Vector2(104,-70),Vector2(104,72),Vector2(-104,72)]),Color("233c3b"),3)
	for i in range(16):
		var x := -101+i*13
		draw_rect(Rect2(x,-65,11,132),Color("9e8e65") if i%3 else Color("b0a079"))
		draw_line(Vector2(x+4,-53),Vector2(x+4,52),Color("7c7459"),1)
		draw_circle(Vector2(x+5,-56),1.5,INK)
		draw_circle(Vector2(x+5,59),1.5,INK)
	for side in [-1,1]:
		draw_line(Vector2(-110,side*69-20),Vector2(110,side*69-20),Color("394744"),5)
		draw_line(Vector2(-110,side*69-22),Vector2(110,side*69-22),Color("c5ac79"),2)
		for i in range(5):
			var x := -103+i*51.5
			draw_rect(Rect2(x-3,side*69-33,6,36),Color("344a45"))
			draw_rect(Rect2(x-5,side*69-36,10,5),GOLD.darkened(.2))
	draw_set_transform(Vector2.ZERO)

func _draw_landmark_floors() -> void:
	for i in range(landmarks.size()):
		var p: Vector2 = landmarks[i].pos
		var radius := 100.0 if i==1 else 70.0
		_ellipse(p,Vector2(radius+9,radius*.55+6),Color("344e49"))
		_ellipse(p,Vector2(radius,radius*.55),Color("838e77"))
		_ellipse_line(p,Vector2(radius-9,radius*.55-5),Color("c2b88c"),2)
		_ellipse_line(p,Vector2(radius-25,radius*.55-15),Color("405e55"),2)
		for j in range(8):
			var a := j*TAU/8
			var v := Vector2(cos(a),sin(a)*.55)
			draw_line(p+v*(radius-23),p+v*(radius-4),Color("364b47"),2)
		if i<=active_landmark:
			_ellipse_line(p,Vector2(radius-13,radius*.55-8),Color(CYAN,.6),2)
			for j in range(8):
				var a := j*TAU/8 + t*.15
				var q := p+Vector2(cos(a)*(radius-18),sin(a)*(radius*.55-10))
				draw_circle(q,2,CYAN)
	# Guardian's altar: brass pylons and suspended fragments.
	for offset in [Vector2(-118,-55),Vector2(118,-55),Vector2(-118,55),Vector2(118,55)]:
		var p: Vector2 = Vector2(1250,750)+offset
		_ink(PackedVector2Array([p+Vector2(-9,0),p+Vector2(-8,-31),p+Vector2(8,-31),p+Vector2(9,0)]),Color("4a6661"))
		draw_line(p+Vector2(-6,-28),p+Vector2(6,-28),GOLD,3)
		draw_line(p+Vector2(0,-25),p+Vector2(0,-7),CYAN,2)

func _draw_tree(tree: Dictionary) -> void:
	var p: Vector2 = tree.p
	var r: float = tree.r
	var h: float = tree.h
	var phase: float = tree.phase
	var sway := sin(t*.75+phase)*1.4
	_ellipse(p+Vector2(14,4),Vector2(r*.95,r*.31),Color(.025,.09,.09,.24))
	var trunk := PackedVector2Array([p+Vector2(-9,1),p+Vector2(-5,-h*.60),p+Vector2(2,-h*.8),p+Vector2(8,-h*.55),p+Vector2(7,0)])
	_ink(trunk,Color("586354"),2)
	draw_line(p+Vector2(1,-5),p+Vector2(-1,-h*.6),Color("8b8b69"),3)
	draw_line(p+Vector2(-2,-h*.4),p+Vector2(-20,-h*.65),Color("414f46"),6)
	draw_line(p+Vector2(3,-h*.5),p+Vector2(22,-h*.7),Color("414f46"),5)
	var crown := p+Vector2(sway,-h)
	var dark := Color("254d48")
	var mid := Color("47775d")
	var light := Color("729269")
	if tree.variant==1:
		dark=Color("38505b");mid=Color("58747a");light=Color("849b93")
	elif tree.variant==3:
		dark=Color("3c4b59");mid=Color("786b88");light=Color("aa91b3")
	_ink(_shifted(tree.blob,crown+Vector2(0,13)),dark,3)
	_ink(_shifted(tree.blob,crown),mid,2)
	for j in range(3):
		var center := crown+Vector2((j-1)*r*.5,-r*.15+sin(j+phase)*5)
		var poly := _blob(center,Vector2(r*.62,r*.45),phase+j,10)
		_ink(poly,light.darkened(j*.055),1)
	for j in range(9):
		var q := crown+Vector2(sin(j*2.4+phase)*r*.76,cos(j*1.7+phase)*r*.48)
		draw_line(q,q+Vector2(5,-2),light.lightened(.15),2)
		if j%2==0: draw_line(q+Vector2(2,8),q+Vector2(8,6),dark,1.5)
	# A few luminous fruits tie organic shapes to the magical-modern setting.
	if tree.variant==1 or tree.variant==3:
		for j in range(3):
			var q := crown+Vector2(sin(j*2+phase)*r*.65,12+j*5)
			draw_circle(q,3,Color("b9e8cc"))
			draw_circle(q,8,Color(.5,.9,.8,.045))

func _draw_rock(rock: Dictionary) -> void:
	var p: Vector2 = rock.p
	var s: float = rock.size
	var poly := PackedVector2Array([p+Vector2(-s,-s*.2),p+Vector2(-s*.6,-s),p+Vector2(s*.2,-s*1.15),p+Vector2(s*.9,-s*.65),p+Vector2(s,0),p+Vector2(s*.2,s*.17),p+Vector2(-s*.6,s*.1)])
	_ellipse(p+Vector2(3,2),Vector2(s*1.1,s*.35),Color(.02,.06,.06,.2))
	_ink(poly,Color("5d756b"),2)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-s*.6,-s),p+Vector2(s*.2,-s*1.15),p+Vector2(s*.9,-s*.65),p+Vector2(s*.1,-s*.42)]),Color("8a9880"))
	draw_line(p+Vector2(s*.1,-s*.4),p+Vector2(s*.25,s*.1),Color("3c5950"),1.5)

func _draw_actor(actor: Dictionary) -> void:
	var texture: Texture2D = actor.get("texture",null)
	if texture == null: return
	var p: Vector2 = actor.get("pos",Vector2.ZERO)
	var region: Rect2 = actor.get("region",Rect2(Vector2.ZERO,texture.get_size()))
	var actor_scale: float = actor.get("scale",1.0)
	var pivot: Vector2 = actor.get("pivot",Vector2(region.size.x*.5,region.size.y))
	if actor.get("shadow",true):
		_ellipse(p+Vector2(0,2),Vector2(minf(region.size.x*actor_scale*.27,28),7),Color(.01,.04,.05,.35))
	var flip: bool = actor.get("flip",false)
	var size := region.size*actor_scale
	var pos := p-pivot*actor_scale
	if flip:
		pos.x = p.x-(region.size.x-pivot.x)*actor_scale
		size.x = -size.x
	var color: Color = actor.get("tint",Color.WHITE)
	draw_texture_rect_region(texture,Rect2(pos,size),region,color,false,true)

func _draw_lamp(p: Vector2) -> void:
	_ellipse(p+Vector2(5,1),Vector2(15,5),Color(.02,.06,.07,.2))
	_ink(PackedVector2Array([p+Vector2(-5,0),p+Vector2(-4,-65),p+Vector2(4,-65),p+Vector2(5,0)]),Color("355456"))
	draw_line(p+Vector2(-12,-66),p+Vector2(15,-66),GOLD,3)
	draw_line(p+Vector2(10,-65),p+Vector2(10,-47),Color("425e5c"),1)
	var swing := sin(t*1.4+p.x)*3
	var q := p+Vector2(10+swing,-40)
	_ink(PackedVector2Array([q+Vector2(0,-10),q+Vector2(7,0),q+Vector2(0,10),q+Vector2(-7,0)]),GOLD,1)
	draw_line(q+Vector2(0,-5),q+Vector2(0,5),Color("fff0b0"),3)
	for i in range(4): draw_circle(q,13+i*8,Color(1,.8,.45,.015))

func _draw_rune() -> void:
	var p := Vector2(780,850)
	_ellipse(p+Vector2(4,0),Vector2(29,11),Color(.02,.08,.08,.3))
	_ink(PackedVector2Array([p+Vector2(-20,0),p+Vector2(-16,-63),p+Vector2(0,-80),p+Vector2(20,-59),p+Vector2(23,0)]),Color("59746d"),3)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-16,-63),p+Vector2(0,-80),p+Vector2(2,-7),p+Vector2(-20,0)]),Color("809280"))
	draw_line(p+Vector2(-14,-23),p+Vector2(15,-28),GOLD.darkened(.2),3)
	var color := GOLD if active_landmark==0 else CYAN
	var q := p+Vector2(0,-47)
	draw_polyline(PackedVector2Array([q+Vector2(0,-17),q+Vector2(-9,-2),q+Vector2(0,8),q+Vector2(9,-2),q+Vector2(0,-17)]),color,2)
	draw_line(q+Vector2(0,-8),q+Vector2(0,17),color,2)
	for i in range(4): draw_circle(q,16+i*7,Color(color,.015))
	if active_landmark==0:
		var y := -109+sin(t*2.4)*4
		draw_colored_polygon(PackedVector2Array([p+Vector2(-6,y),p+Vector2(6,y),p+Vector2(0,y+7)]),GOLD)

func _draw_gate() -> void:
	var p := Vector2(1880,550)
	var portal_color := CYAN if gate_open else Color("657e9b")
	if gate_open:
		for i in range(9):
			_ellipse(p+Vector2(0,-82),Vector2(40+i*4,67+i*3),Color(.3,.83,.85,.02))
		_ellipse(p+Vector2(0,-80),Vector2(48,78),Color(.16,.51,.62,.5))
		for i in range(12):
			var y := -145+fposmod(i*13+t*12,135)
			var width := sin((y+150)/145*PI)*43
			draw_line(p+Vector2(-width,y),p+Vector2(width,y),Color(.7,.95,.9,.2),2)
	for side in [-1,1]:
		var poly := PackedVector2Array([p+Vector2(side*50,2),p+Vector2(side*48,-100),p+Vector2(side*28,-146),p+Vector2(side*46,-155),p+Vector2(side*75,-108),p+Vector2(side*79,2)])
		_ink(poly,Color("425e62"),3)
		draw_polyline(PackedVector2Array([p+Vector2(side*58,-4),p+Vector2(side*57,-99),p+Vector2(side*36,-144)]),GOLD,3)
		draw_polyline(PackedVector2Array([p+Vector2(side*71,-7),p+Vector2(side*68,-104),p+Vector2(side*46,-143)]),Color("77958b"),2)
		for j in range(4):
			draw_line(p+Vector2(side*61,-23-j*17),p+Vector2(side*70,-25-j*17),portal_color,2)
	var crown := p+Vector2(sin(t*.8)*2,-163+sin(t*1.2)*3)
	_ink(PackedVector2Array([crown+Vector2(0,-20),crown+Vector2(17,0),crown+Vector2(0,20),crown+Vector2(-17,0)]),Color("36586a"),2)
	draw_polyline(PackedVector2Array([crown+Vector2(0,-12),crown+Vector2(9,0),crown+Vector2(0,12),crown+Vector2(-9,0),crown+Vector2(0,-12)]),portal_color,2)
	for i in range(4): draw_circle(crown,17+i*9,Color(portal_color,.02))
	if active_landmark>=2:
		var y := -210+sin(t*2.4)*4
		draw_colored_polygon(PackedVector2Array([p+Vector2(-6,y),p+Vector2(6,y),p+Vector2(0,y+7)]),GOLD)

func _draw_camp() -> void:
	var p := Vector2(390,970)
	_ink(PackedVector2Array([p+Vector2(-34,0),p+Vector2(1,-49),p+Vector2(44,0)]),Color("597780"),2)
	draw_colored_polygon(PackedVector2Array([p+Vector2(1,-49),p+Vector2(12,-1),p+Vector2(44,0)]),Color("395761"))
	draw_line(p+Vector2(1,-48),p+Vector2(12,-1),GOLD.darkened(.2),2)
	var lantern := p+Vector2(65,-12)
	_ink(PackedVector2Array([lantern+Vector2(-8,10),lantern+Vector2(-6,-9),lantern+Vector2(6,-9),lantern+Vector2(8,10)]),Color("8c8764"),2)
	draw_rect(Rect2(lantern+Vector2(-3,-5),Vector2(6,11)),GOLD)
	for i in range(5): draw_circle(lantern,12+i*8,Color(1,.8,.45,.02))

func _draw_atmosphere() -> void:
	for i in range(70):
		var p := Vector2(250+fposmod(i*257.3+sin(t*.19+i)*24,1940),350+fposmod(i*139.7+t*2,1040))
		if not _view.has_point(p): continue
		var alpha := (sin(t*1.4+i*3.1)+1)*.21+.1
		draw_circle(p,1.5,Color(.68,.95,.77,alpha))
		draw_circle(p,5,Color(.68,.95,.77,alpha*.08))
	# Slow translucent mist pools, drawn in world space rather than over HUD.
	for i in range(8):
		var p := Vector2(300+i*280+sin(t*.08+i)*55,690+sin(i*3.2)*370)
		if not _view.grow(250).has_point(p): continue
		_ellipse(p,Vector2(170,22),Color(.56,.77,.74,.022))
		_ellipse(p+Vector2(40,5),Vector2(130,17),Color(.63,.83,.78,.018))

func _ellipse(p: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(32):
		var a := TAU*float(i)/32
		points.append(p+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_colored_polygon(points,color)

func _ellipse_line(p: Vector2, radii: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(49):
		var a := TAU*float(i)/48
		points.append(p+Vector2(cos(a)*radii.x,sin(a)*radii.y))
	draw_polyline(points,color,width,true)
