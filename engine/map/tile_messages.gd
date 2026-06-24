class_name TileMessages
extends Object

static func for_tile(tile_type: int) -> String:
	match tile_type:
		MapData.TileType.DOOR:
			return "你穿過一扇門。"
		MapData.TileType.STAIRS_UP:
			return "一道向上的階梯。"
		MapData.TileType.STAIRS_DOWN:
			return "一道向下的階梯。"
		_:
			return ""
