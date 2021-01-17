extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var alerted = false
var health = 2

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# line of sight algorithm found here: http://www.roguebasin.com/index.php?title=Bresenham%27s_Line_Algorithm
func hasLineOfSight(start_coord, end_coord, tilemap: TileMap):
	var x1 = start_coord[0]
	var y1 = start_coord[1]
	var x2 = end_coord[0]
	var y2 = end_coord[1]
	var dx = x2 - x1
	var dy = y2 - y1
	# Determine how steep the line is
	var is_steep = abs(dy) > abs(dx)
	var tmp = 0
	# Rotate line
	if is_steep:
		tmp = x1
		x1 = y1
		y1 = tmp
		tmp = x2
		x2 = y2
		y2 = tmp
	# Swap start and end points if necessary and store swap state
	var swapped = false
	if x1 > x2:
		tmp = x1
		x1 = x2
		x2 = tmp
		tmp = y1
		y1 = y2
		y2 = tmp
		swapped = true
	# Recalculate differentials
	dx = x2 - x1
	dy = y2 - y1
	
	# Calculate error
	var error = int(dx / 2.0)
	var ystep = 1 if y1 < y2 else -1

	# Iterate over bounding box generating points between start and end
	var y = y1
	var points = []
	for x in range(x1, x2 + 1):
		var coord = [y, x] if is_steep else [x, y]
		points.append(coord)
		error -= abs(dy)
		if error < 0:
			y += ystep
			error += dx
	
	if swapped:
		points.invert()
	
	for point in points:
		if tilemap.get_cell(point[0], point[1]) >= 0:
			return false
	return true


func getGridPath(startCoord, endCoord, astar: AStar2D, astarPointsCache: Dictionary):
	return astar.get_point_path(astarPointsCache[str(startCoord)], astarPointsCache[str(endCoord)])

func alert():
	alerted=true
