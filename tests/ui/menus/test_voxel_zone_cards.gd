extends GutTest
## Zone cards show the voxel look-dev stills in the Voxel art style and the
## classic renders in Classic.


func after_each() -> void:
	ArtStyle.reset()


func test_every_zone_card_is_a_voxel_still_in_the_voxel_style() -> void:
	ArtStyle.set_current(ArtStyle.Kind.VOXEL)
	for id in ZoneCatalog.ids():
		var art := ZoneCatalog.art(id)
		assert_not_null(art, String(id))
		if art != null:
			assert_eq(art.resource_path, ZoneCatalog.VOXEL_ART_DIR + String(id) + ".jpg")
			assert_eq(art.get_size(), Vector2(960, 540), "%s card is scaled down to 960x540" % id)


func test_classic_keeps_the_classic_card_renders() -> void:
	ArtStyle.set_current(ArtStyle.Kind.CLASSIC)
	for id in ZoneCatalog.ids():
		var art := ZoneCatalog.art(id)
		assert_not_null(art, String(id))
		if art != null:
			assert_eq(art.resource_path, ZoneCatalog.ART_DIR + String(id) + ".png")
