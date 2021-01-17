extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var currentLevel = 1

var scene_root = null
var player = null
var exit = null
var tilemap = null
onready var astar =  AStar2D.new()
var astar_points_cache = {}
var treasure_ind = 0


onready var roomsTextureData = preload("res://Art/rooms.png").get_data()

var key = preload("res://Objects/Key.tscn")
var door = preload("res://Objects/Door.tscn")
var enemy = preload("res://Objects/Enemy.tscn")
var potion = preload("res://Objects/Potion.tscn")
var chest = preload("res://Objects/Chest.tscn")

const START_ROOM_COUNT = 3 # not including starting room and exit room
const ROOM_COUNT_INCREASE_PER_LEVEL = 2
const EXIT_ROOM_TYPE_IND = 15
const START_ROOM_TYPE_IND = 0

const CELL_SIZE = 16
const ROOMS_SIZE = 8
const ROOM_DATA_IMAGE_ROW_LEN = 4
const NUM_OF_ROOM_TYPES = 16

const NUM_OF_WALL_TYPES = 4
const CHANCE_OF_NON_BLANK_WALL = 4

const KEY_COUNT = 1
const DOOR_COUNT = 1
const MAX_DOOR_COUNT = 3

const START_ENEMY_COUNT = 2
const ENEMY_COUNT_INCREASE_PER_LEVEL = 1
const START_POTION_COUNT = 1
const POTION_COUNT_INCREASE_PER_LEVEL = 1

const CHANCE_OF_TREASURE_SPAWNING = 2
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(scn_root, tilemapRef, playerRef, exitRef):
	scene_root = scn_root 
	player = playerRef 
	exit = exitRef 
	tilemap = tilemapRef

func generateWorld(currLevel):
	currentLevel = currLevel
	astar.clear()
	tilemap.clear()
	#clear all enemies, keys, potions, etc
	get_tree().call_group("enemies", "queue_free")
	get_tree().call_group("keys", "queue_free")
	get_tree().call_group("potions", "queue_free")
	get_tree().call_group("doors", "queue_free")
	get_tree().call_group("chests", "queue_free")
	
	var roomData = generateRoomData()
	var spawnLocations = generateRooms(roomData)
	var worldData = generateWorldObjects(spawnLocations)
	worldData["astar"] = astar
	worldData["astar_points_cache"] = astar_points_cache
	#account for unwinnable worlds
	if worldData.keys.size() < KEY_COUNT:
		worldData = generateWorld(currentLevel)
	return worldData
	

func generateRoomData():
	var roomCount = START_ROOM_COUNT + currentLevel*ROOM_COUNT_INCREASE_PER_LEVEL
	var roomData = {
		str([0,0]):{"type":START_ROOM_TYPE_IND, "coords":[0,0]}
	}
	var possRoomLocs = getOpenAdjacentRooms(roomData, [0,0])
	var generatedRooms = []
	for _i in range(roomCount):
		var randRoomType = 0
		while randRoomType == START_ROOM_TYPE_IND or randRoomType == EXIT_ROOM_TYPE_IND:
			randRoomType = (randi() % NUM_OF_ROOM_TYPES-1) +1
		var randRoomLoc = selectRandomRoomLoc(possRoomLocs, roomData)
		roomData[str(randRoomLoc)] = {"type":randRoomType, "coords":randRoomLoc}
		generatedRooms.append(randRoomLoc)
		possRoomLocs += getOpenAdjacentRooms(roomData, randRoomLoc)
	#exit room
	var randRoomLoc = selectRandomRoomLoc(possRoomLocs, roomData)
	roomData[str(randRoomLoc)] = {"type":EXIT_ROOM_TYPE_IND, "coords":randRoomLoc}
	return roomData
	

func getOpenAdjacentRooms(rooms_data: Dictionary, coords):
	var empty_adjacent_rooms = []
	var adj_coords = [
		[coords[0]+0, coords[1]+1], # up
		[coords[0]+1, coords[1]+0], # right
		[coords[0]+0, coords[1]-1], # down
		[coords[0]-1, coords[1]+0], # left
	]
	for coord in adj_coords:
		if not str(coord) in rooms_data:
			empty_adjacent_rooms.append(coord)
	return empty_adjacent_rooms
	
func selectRandomRoomLoc(possibleRoomLocs: Array, roomData: Dictionary):
	var randIndex = randi() % possibleRoomLocs.size()
	var randLoc = possibleRoomLocs[randIndex]
	possibleRoomLocs.remove(randIndex)
	if str(randLoc) in roomData:
		randLoc = selectRandomRoomLoc(possibleRoomLocs, roomData)
	return randLoc

func generateRooms(roomData: Dictionary) -> Dictionary:
	var spawnLocations = {
		"enemySpawns": [],
		"pickupSpawns": [],
		"doorCoords": [],
		"exitCoords": [0,0]
	}
	var ind = 0
	var walkable_floor_tiles = {}
	for room_data in roomData.values():
		var only_do_walls = ind == 0 # only want to create walls if it's the first room since that's where the player starts
		ind += 1
		var coords = room_data.coords
		var x_pos = coords[0] * ROOMS_SIZE
		var y_pos = coords[1] * ROOMS_SIZE
		var type = room_data.type
		var x_pos_img = (type % ROOM_DATA_IMAGE_ROW_LEN) * ROOMS_SIZE
		var y_pos_img = (type / ROOM_DATA_IMAGE_ROW_LEN) * ROOMS_SIZE
		for x in range(ROOMS_SIZE):
			for y in range(ROOMS_SIZE):
				roomsTextureData.lock()
				var cell_data = roomsTextureData.get_pixel(x_pos_img+x, y_pos_img+y)
				var cell_coords = [x_pos+x, y_pos+y]
				var wall_tile = false
				if cell_data == Color.black:
					var wall_type = get_rand_wall_type()
					tilemap.set_cell(x_pos+x, y_pos+y, wall_type, randi()%2==0,randi()%2==0)
					wall_tile = true
				if !only_do_walls:
					if cell_data == Color.red:
						spawnLocations.enemySpawns.append(cell_coords)
					elif cell_data == Color.green:
						spawnLocations.pickupSpawns.append(cell_coords)
					elif cell_data == Color.blue:
						spawnLocations.exitCoords = cell_coords
					elif cell_data == Color.magenta:
						spawnLocations.doorCoords.append(cell_coords)
				if !wall_tile:
					walkable_floor_tiles[str([x_pos+x, y_pos+y])] = [x_pos+x, y_pos+y]
		
		var scoords = ""
		var room_at_left = str([coords[0]-1, coords[1]]) in roomData
		var room_at_right = str([coords[0]+1, coords[1]]) in roomData
		var room_at_top = str([coords[0], coords[1]-1]) in roomData
		var room_at_bottom = str([coords[0], coords[1]+1]) in roomData
		if !room_at_left:
			tilemap.set_cell(x_pos, y_pos+3, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			tilemap.set_cell(x_pos, y_pos+4, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			scoords = str([x_pos, y_pos+3])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
			scoords = str([x_pos, y_pos+4])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
		if !room_at_right:
			tilemap.set_cell(x_pos+ROOMS_SIZE-1, y_pos+3, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			tilemap.set_cell(x_pos+ROOMS_SIZE-1, y_pos+4, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			scoords = str([x_pos+ROOMS_SIZE-1, y_pos+3])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
			scoords = str([x_pos+ROOMS_SIZE-1, y_pos+4])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
		if !room_at_top:
			tilemap.set_cell(x_pos+3, y_pos, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			tilemap.set_cell(x_pos+4, y_pos, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			scoords = str([x_pos+3, y_pos])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
			scoords = str([x_pos+4, y_pos])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
		if !room_at_bottom:
			tilemap.set_cell(x_pos+3, y_pos+ROOMS_SIZE-1, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			tilemap.set_cell(x_pos+4, y_pos+ROOMS_SIZE-1, get_rand_wall_type(), randi()%2==0,randi()%2==0)
			scoords = str([x_pos+3, y_pos+ROOMS_SIZE-1])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
			scoords = str([x_pos+4, y_pos+ROOMS_SIZE-1])
			if scoords in walkable_floor_tiles:
				walkable_floor_tiles.erase(scoords)
	generate_astar_grid(walkable_floor_tiles)
	return spawnLocations
	
func generateWorldObjects(spawnLocations):
	player.global_position = map_coord_to_world_pos(Vector2.ONE)
	var exitWorldCoords = map_coord_to_world_pos(spawnLocations.exitCoords)
	print(exitWorldCoords)
	exitWorldCoords.x += 8
	exitWorldCoords.y += 8
	exit.global_position = exitWorldCoords
	print(exit.global_position)
	var enemy_count = START_ENEMY_COUNT + ENEMY_COUNT_INCREASE_PER_LEVEL * currentLevel
	var enemies = spawnObjects(enemy, spawnLocations.enemySpawns, enemy_count, "enemies")
	var keys = []
	var doors = []
	var keysToSpawn = KEY_COUNT + currentLevel
	if keysToSpawn > MAX_DOOR_COUNT:
		keys = spawnObjects(key, spawnLocations.pickupSpawns, MAX_DOOR_COUNT, "keys")
		doors = spawnObjects(door, spawnLocations.doorCoords, MAX_DOOR_COUNT, "doors", false)
	else:
		keys = spawnObjects(key, spawnLocations.pickupSpawns, keysToSpawn, "keys")
		doors = spawnObjects(door, spawnLocations.doorCoords, keysToSpawn, "doors", false)
	
	var potionsToSpawn = START_POTION_COUNT + currentLevel * POTION_COUNT_INCREASE_PER_LEVEL
	var potions = spawnObjects(potion, spawnLocations.pickupSpawns, potionsToSpawn, "potions")
	var chests = spawnObjects(chest, spawnLocations.pickupSpawns, 1, "chests")
	
	var data = {
		"enemies": enemies,
		"keys": keys,
		"potions": potions,
		"doors": doors,
		"player": player,
		"exit": exit,
		"chests": chests
	}
	return data

func spawnObjects(object, locationList: Array, numToSpawn: int, groupName: String, flipRandomly=true) -> Dictionary:
	var spawnedObjs = {}
	for _i in range(numToSpawn):
		if locationList.size() == 0:
			return spawnedObjs
		var instance = object.instance()
		scene_root.add_child(instance)
		var randLocIndex = randi() % locationList.size()
		var coord = locationList[randLocIndex]
		var worldCoord = map_coord_to_world_pos(coord)
		worldCoord.x += 8
		worldCoord.y += 8
		instance.global_position = worldCoord
		locationList.remove(randLocIndex)
		spawnedObjs[str(coord)] = instance
		instance.add_to_group(groupName)
		if flipRandomly and instance.has_node("Sprite") and randi() % 2 == 0:
			instance.get_node("Sprite").flip_h = true
	return spawnedObjs

func generate_astar_grid(walkable_floor_tiles):
	astar_points_cache = {}
	for tile_coord in walkable_floor_tiles.values():
		var tile_id = astar.get_available_point_id()
		astar.add_point(tile_id, Vector2(tile_coord[0], tile_coord[1]))
		astar_points_cache[str([tile_coord[0], tile_coord[1]])] = tile_id
	
	for tile_coord in walkable_floor_tiles.values():
		var tile_id = astar_points_cache[str([tile_coord[0], tile_coord[1]])]
		var left_x_key = str([tile_coord[0]-1, tile_coord[1]])
		if left_x_key in astar_points_cache:
			astar.connect_points(astar_points_cache[left_x_key], tile_id)
		var up_y_key = str([tile_coord[0], tile_coord[1]-1])
		if up_y_key in astar_points_cache:
			astar.connect_points(astar_points_cache[up_y_key], tile_id)

func get_rand_wall_type():
	var wall_type = 0
	if randi() % CHANCE_OF_NON_BLANK_WALL == 0:
		wall_type = randi() % NUM_OF_WALL_TYPES
	return wall_type
	
func map_coord_to_world_pos(coord):
	return tilemap.map_to_world(Vector2(coord[0], coord[1]))
