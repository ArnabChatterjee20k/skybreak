extends GutTest
## Code-built power and gadget views (T-D26).


func test_every_power_and_gadget_has_a_model_with_meshes() -> void:
	for kind: int in Power.Kind.values().slice(1):
		var model := PowerModels.build(kind)
		assert_gt(model.find_children("*", "MeshInstance3D", true, false).size(), 2, Power.power_name(kind))
		model.free()


func test_every_gadget_has_a_world_view() -> void:
	for kind: Power.Kind in Power.GADGETS:
		var gadget := Gadget.new()
		gadget.kind = kind
		var node := WeaponLayer.make_gadget(gadget)
		assert_not_null(node.get_node_or_null("Model"))
		node.free()


func test_the_nocked_arrow_pulls_back_with_the_draw_level() -> void:
	assert_lt(WeaponLayer.nock_offset(0), WeaponLayer.nock_offset(1))
	assert_lt(WeaponLayer.nock_offset(1), WeaponLayer.nock_offset(3))
	var arrow := PowerModels.nocked_arrow(false)
	assert_eq(arrow.name, &"NockedArrow")
	arrow.free()


func test_the_layer_draws_power_drops_and_gadgets_from_sim_state() -> void:
	var sim := CombatSim.new(1)
	sim.add_fighter(Vector3.ZERO)
	sim.add_fighter(Vector3(0, 0, -6))
	var layer := WeaponLayer.new()
	add_child_autofree(layer)
	layer.setup(sim, [] as Array[FighterView])
	var drop := PowerRules.drop_power(sim, Power.Kind.AEGIS, Vector3(3, 2, 0))
	sim.fighters[0].powers.gadget = Power.Kind.GRAVITY_MINE
	PowerRules.use_gadget(sim, 0)
	layer.remember_previous_tick()
	layer.present(1.0, 1.0 / 60.0)
	assert_eq(layer.get_child_count(), 2, "one pickup, one gadget")
	sim.pickups.erase(drop)
	sim.gadgets.clear()
	layer.present(1.0, 1.0 / 60.0)
	await wait_process_frames(1)
	assert_eq(layer.get_child_count(), 0, "gone with the sim state")
