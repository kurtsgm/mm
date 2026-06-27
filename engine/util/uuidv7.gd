class_name Uuidv7
extends Object
# UUIDv7：48-bit 毫秒時戳 + 版本 7 + 變體 10 + 隨機。標準 8-4-4-4-12 小寫十六進位。

static func generate() -> String:
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	var b := PackedByteArray()
	b.resize(16)
	b[0] = (ms >> 40) & 0xFF
	b[1] = (ms >> 32) & 0xFF
	b[2] = (ms >> 24) & 0xFF
	b[3] = (ms >> 16) & 0xFF
	b[4] = (ms >> 8) & 0xFF
	b[5] = ms & 0xFF
	for i in range(6, 16):
		b[i] = randi() & 0xFF
	b[6] = (b[6] & 0x0F) | 0x70   # version 7
	b[8] = (b[8] & 0x3F) | 0x80   # variant 10
	var h := ""
	for x in b:
		h += "%02x" % x
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
