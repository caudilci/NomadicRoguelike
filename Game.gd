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
var keys = {}
var chests = {}

var astar = null
var astar_points_cache = {}

const RIGHT = [1,0]
const LEFT = [-1,0]
const UP = [0,-1]
const DOWN = [0,1]

var maxHealth = 3
var health = 3
var damage = 1
var attackRange = 1
var attackBreadth = 1

var keysHeld = 0

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
	health = maxHealth
	#update collected item UI
	updateCollectionsUI()
	var worldData = worldGenerator.generateWorld(currentLevel)
	enemies = worldData.enemies
	doors = worldData.doors
	potions = worldData.potions
	keys = worldData.keys
	astar = worldData.astar
	astar_points_cache = worldData.astar_points_cache
	print(astar_points_cache)
	chests = worldData.chests
	

func updateCollectionsUI():
	$CanvasLayer/HealthLabel.text = "Health: " + str(health)
	$CanvasLayer/KeysLabel.text = "Keys: " + str(keysHeld)
	$CanvasLayer/LevelLabel.text = "Level: " + str(currentLevel)
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _input(event):
	if !event.is_pressed():
		return
	if event.is_action("Left") and dead==false:
		movePlayer(LEFT)
	elif event.is_action("Right") and dead == false:
		movePlayer(RIGHT)
	elif event.is_action("Up") and dead == false:
		movePlayer(UP)
	elif event.is_action("Down") and dead == false:
		movePlayer(DOWN)
	elif event.is_action("Restart"):
		restart()
	elif event.is_action("Skip"):
		pass
	elif event.is_action("Exit"):
		get_tree().quit()
	
	$CanvasLayer/StartScreen.hide()
	
	if dead == false:
		processEnemyTurns()
	

func moveEnemy(enemy, delta):
	var oldPosArray = world_pos_to_map_coord(enemy.global_position)
	var x = enemy.global_position.x + delta[0]*16
	var y = enemy.global_position.y + delta[1]*16
	var pos = Vector2(x,y)
	var mapPos = tilemap.world_to_map(pos)
	var mapPosArray = [mapPos.x,mapPos.y]
	if tilemap.get_cellv(tilemap.world_to_map(pos)) >= 0:
		return false
	elif mapPos.is_equal_approx(tilemap.world_to_map(player.global_position)):
		health -= 1
		if health <= 0:
			die()
		updateCollectionsUI()
	elif str(mapPosArray) in enemies:
		print("Enemy Collistion!")
		return false
	else: 
		enemies.erase(str(oldPosArray))
		enemies[str(mapPosArray)] = enemy
		enemy.global_position = pos

func movePlayer(delta):
	var x = player.global_position.x + delta[0]*16
	var y = player.global_position.y + delta[1]*16
	var pos = Vector2(x,y)
	var mapPos = world_pos_to_map_coord(pos)
	var mapPosStr = str(mapPos)
	if tilemap.get_cellv(tilemap.world_to_map(Vector2(x,y))) >= 0:
		return false
	elif mapPosStr in enemies:
		hit(mapPosStr)
		return false
	elif mapPosStr in potions:
		var potion = potions[mapPosStr]
		potion.queue_free()
		potions.erase(mapPosStr)
		health = maxHealth
		updateCollectionsUI()
		player.global_position = Vector2(x,y)
		player.flip_h = !player.flip_h
	elif mapPosStr in keys:
		var key = keys[mapPosStr]
		key.queue_free()
		keys.erase(mapPosStr)
		keysHeld += 1
		updateCollectionsUI()
		player.global_position = Vector2(x,y)
		player.flip_h = !player.flip_h
	elif mapPosStr in doors:
		if keysHeld <= 0:
			return false
		else:
			var door = doors[mapPosStr]
			door.queue_free()
			doors.erase(mapPosStr)
			keysHeld -= 1
			updateCollectionsUI()
			player.global_position = Vector2(x,y)
			player.flip_h = !player.flip_h
	elif mapPosStr == str(world_pos_to_map_coord(exit.global_position)):
		advanceLevel()
	else:
		player.global_position = Vector2(x,y)
		print(tilemap.world_to_map(player.global_position))
		player.flip_h = !player.flip_h
		
func world_pos_to_map_coord(pos: Vector2):
	var vcoords = tilemap.world_to_map(pos)
	var coords = [int(round(vcoords.x)), int(round(vcoords.y))]
	return coords
	
func hit(coord):
	var enemy = enemies[coord]
	enemy.health -= damage
	if enemy.health <= 0:
		enemy.queue_free()
		enemies.erase(coord)
		

func processEnemyTurns():
	for enemy in enemies.values():
			var playerPos = world_pos_to_map_coord(player.global_position)
			var enemyPos = world_pos_to_map_coord(enemy.global_position)
			if enemy.alerted:
				if playerPos[0] > enemyPos[0] and !enemy.get_node("Sprite").flip_h:
					enemy.get_node("Sprite").flip_h = true
				if playerPos[0] < enemyPos[0] and enemy.get_node("Sprite").flip_h:
					enemy.get_node("Sprite").flip_h = false
				var path = enemy.getGridPath(enemyPos, playerPos, astar, astar_points_cache)
				if path.size() > 1:
					if enemyPos[0] < int(round(path[1].x)):
						moveEnemy(enemy, RIGHT)
					elif enemyPos[0] > int(round(path[1].x)):
						moveEnemy(enemy, LEFT)
					elif enemyPos[1] < int(round(path[1].y)):
						moveEnemy(enemy, DOWN)
					elif enemyPos[1] > int(round(path[1].y)):
						moveEnemy(enemy, UP)
			elif enemy.hasLineOfSight(enemyPos, playerPos, tilemap):
				enemy.alert()

func die():
	dead=true
	$CanvasLayer/DeathScreen.show()
	return
	

func restart():
	keysHeld = 0
	currentLevel = 0
	$CanvasLayer/DeathScreen.hide()
	generateWorld()
	return

func advanceLevel():
	keysHeld = 0
	currentLevel += 1
	generateWorld()
