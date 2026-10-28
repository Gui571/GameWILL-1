extends RefCounted
## Eight-direction, bone-rigged sprites generated from the MIT Pixel Creatures core.
## Runtime is dependency-free: atlas + exported metadata. See tools/creature_generator.
var _cache: Dictionary = {}
const HEIGHTS = {"william":85.0,"guardian":110.0,"fox":48.0,"moth":36.0,"plant":51.0}

func _load_kind(kind: String) -> Dictionary:
	if _cache.has(kind): return _cache[kind]
	var base = "res://intro/creatures/" + kind
	var file = FileAccess.open(base + ".json", FileAccess.READ)
	if file == null: return {}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var data: Dictionary = parser.data
	var textures: Array = []
	for page in data.pages:
		textures.append(load("res://intro/creatures/" + str(page.file)))
	var clips: Dictionary = {}
	for clip in data.clips:
		clips[str(clip.state) + ":" + str(int(clip.direction))] = clip
	data["textures"] = textures
	data["lookup"] = clips
	_cache[kind] = data
	return data

func get_actor(kind: String, pos: Vector2, moving: bool, facing: Vector2, time: float, action: String = "idle") -> Dictionary:
	if not HEIGHTS.has(kind): kind = "fox"
	var data = _load_kind(kind)
	if data.is_empty(): return {"pos":pos}
	var direction = posmod(int(round(atan2(-facing.y, facing.x) / (PI / 4.0))), 8) if facing.length_squared() > 0.001 else 6
	var state = "walk" if moving else "idle"
	if action not in ["idle", "", "walk"]: state = "action"
	var clip: Dictionary = data.lookup[state + ":" + str(direction)]
	var frame_id = posmod(int(time * float(clip.fps)), clip.frames.size())
	var frame: Dictionary = clip.frames[frame_id]
	return {
		"pos":pos, "texture":data.textures[int(frame.page)],
		"region":Rect2(float(frame.x),float(frame.y),float(data.frameWidth),float(data.frameHeight)),
		"pivot":Vector2(float(data.originX),float(data.originY)),
		"scale":float(HEIGHTS[kind]) / maxf(float(data.originY),1.0),
		"flip":false, "tint":Color.WHITE
	}
