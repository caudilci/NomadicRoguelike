extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var player = $Player
onready var exit = $Exit
onready var tilemap = $TileMap
onready var worldGenerator = $WorldGenerator

var currentLevel = 0
var enemies = {}
var doors = {}
var potions = {}
var treasure = {}
var astar = null
var astar_points_cache = {}

const RIGHT = [1,0]
const LEFT = [-1.0]
const UP = [0,-1]
const DOWN = [0,1]

var keysHeld = 0
var potionsHeld = 0
var currentWeapon = "Dagger"
var dead = false


# Called when the node enters the scene tree for the first time.
func _ready():
	OS.set_window_size(Vector2(1280,720))
	randomize()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	worldGenerator.init(self,  $TileMap, $Player, $Exit)
	generateWorld()
	
func generateWorld():
	dead = false
	#update collected item UI
	
	var worldData = worldGenerator.generateWorld(currentLevel)
	#enemies = worldData.enemies
	#doors = worldData.doors
	#potions = worldData.potions
	#keys = worldData.keys
	#astar = worldData.astar
	#astar_points_cache = worldData.astar_points_cache
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event):
	if !event.is_pressed():
		return
	if event.is_action("Left"):
		tryMove(-1,0)
	elif event.is_action("Right"):
		tryMove(1,0)
	elif event.is_action("Up"):
		tryMove(0,-1)
	elif event.is_action("Down"):
		tryMove(0,1)
	

func tryMove(dx,dy):
	var x = player.global_position.x + dx*16
	var y = player.global_position.y + dy*16
	print(tilemap.get_cellv(tilemap.world_to_map(Vector2(x,y))))
	if tilemap.get_cellv(tilemap.world_to_map(Vector2(x,y))) >= 0:
		return false
	else:
		player.global_position = Vector2(x,y)
