extends SceneTree
const Terrain = preload("res://intro/terrain.gd")
var count = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var world = Terrain.new()
	var checkpoints = [Vector2(450,950),Vector2(780,850),Vector2(1250,750),Vector2(1880,550)]
	var previous = []
	for seed_value in [1,7,72641,32768,999983]:
		world.generate(seed_value)
		check(world.landmarks[0].id == "beacon","First landmark must match interaction ID")
		check(world.is_walkable(world.spawn_point()),"Spawn is on land")
		check(not world.is_walkable(Vector2(-50,500)),"World bounds block movement")
		check(world.fauna_spawns.size() >= 3,"World has wildlife")
		for segment in range(checkpoints.size()-1):
			for i in range(51):
				var p: Vector2 = checkpoints[segment].lerp(checkpoints[segment+1],float(i)/50.0)
				check(world.is_walkable(p),"Story path stays walkable seed%s segment%s point%s" % [seed_value,segment,p])
		var signature = [world._outline.duplicate(),world._trees.duplicate(true),world.fauna_spawns.duplicate()]
		world.generate(seed_value)
		check(signature == [world._outline,world._trees,world.fauna_spawns],"Same seed reproduces landscape")
		if not previous.is_empty(): check(previous != signature,"Different seed changes landscape")
		previous = signature
	world.free()
	print("INTRO TERRAIN: %d checks, %d failures" % [count,failures])
	quit(1 if failures else 0)
