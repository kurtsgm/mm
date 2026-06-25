class_name DungeonTheme
extends Resource

# 一個「主題」= 一套 3D 磚塊 kit。加新主題 = 加一個 .tres（或程式碼生成），不碰引擎層。
@export var theme_id: String = ""
@export var mesh_library: MeshLibrary           # 該主題整套磚塊；null = 程式碼生成主題
@export var floor_item: String = "floor"        # 鋪在每個可走格的地板 item 名稱
@export var item_for_tile: Dictionary = {}      # MapData.TileType(int) -> 特徵 item 名稱(String)
@export var has_ceiling: bool = false           # 是否在可走格上方鋪天花板
@export var ceiling_item: String = ""           # 天花板 item 名稱（has_ceiling 為真時用）
