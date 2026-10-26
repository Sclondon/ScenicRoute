extends RefCounted
## The places you can go, in the order their postcards are dealt. Each is a script (see PLACES.md for what one
## must do) and a postcard picture of it (`cards/<id>.jpg`, made by tests/cards.gd from its own view).

const PLACES := [
	{"id": "amberwood", "name": "Amberwood", "line": "An autumn wood at the golden hour",
		"script": "res://scripts/amberwood/amberwood.gd", "tint": Color(0.86, 0.5, 0.18)},
	{"id": "plumeria", "name": "The Plumeria Beach Club", "line": "A Hawaiian beach club as the sun goes down",
		"script": "res://scripts/plumeria/plumeria.gd", "tint": Color(0.95, 0.55, 0.45)},
	{"id": "velvet_moth", "name": "The Velvet Moth", "line": "A night club, late, the floor still full",
		"script": "res://scripts/velvet_moth/velvet_moth.gd", "tint": Color(0.55, 0.25, 0.75)},
	{"id": "caffe_del_porto", "name": "Caffè del Porto", "line": "A seaside cafe on the Italian coast, mid-morning",
		"script": "res://scripts/caffe_del_porto/caffe_del_porto.gd", "tint": Color(0.3, 0.6, 0.85)},
]


## The places whose scripts are there (one being made may not be yet).
static func ready_places() -> Array:
	return PLACES.filter(func(p: Dictionary) -> bool: return ResourceLoader.exists(p.script))


static func card_path(id: String) -> String:
	return "res://cards/%s.jpg" % id
