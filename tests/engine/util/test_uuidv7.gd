extends GutTest

func test_format_length_and_dashes():
	var u := Uuidv7.generate()
	assert_eq(u.length(), 36)
	assert_eq(u[8], "-"); assert_eq(u[13], "-"); assert_eq(u[18], "-"); assert_eq(u[23], "-")

func test_version_and_variant_nibbles():
	var u := Uuidv7.generate()
	assert_eq(u[14], "7", "版本 nibble 應為 7")
	assert_true("89ab".contains(u[19]), "變體 nibble 應為 8/9/a/b")

func test_unique_batch():
	var seen := {}
	for i in 200:
		var u := Uuidv7.generate()
		assert_false(seen.has(u), "重複 uid")
		seen[u] = true
