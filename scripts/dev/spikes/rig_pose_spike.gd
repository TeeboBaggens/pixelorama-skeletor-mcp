extends RefCounted

func find_mgr(api):
	for c in api.general.get_canvas().get_children():
		if c.has_method("generate_pose") and c.has_method("find_pose_layer"):
			return c
	return null

func idx(project, n):
	return project.layers.find_custom(func(l): return l.name == n)

func add_layer(api, project, type, lname, anchor, nest):
	var grp = null
	if anchor >= 0 and anchor < project.layers.size():
		grp = project.layers[anchor]
	if grp != null and grp.get_layer_type() == 1:
		grp.expanded = nest
	var seen = []
	for l in project.layers:
		seen.append(l)
	project.current_layer = anchor
	api.general.get_global().animation_timeline.on_add_layer_list_id_pressed(type)
	var created = null
	for l in project.layers:
		if not seen.has(l):
			created = l
			break
	if created == null:
		return -1
	created.name = lname
	if grp != null and grp.get_layer_type() == 1:
		grp.expanded = true
	for i in range(project.layers.size()):
		project.layers[i].index = i
	project.order_layers()
	return project.layers.find(created)

# Sparse-cel-safe fill: build a project-sized image, then let the cel grow to fit.
func paint(project, lname, rect, col):
	var i = idx(project, lname)
	if i < 0:
		return "no layer " + lname
	var cel = project.frames[0].cels[i]
	var src = Image.create_empty(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
	src.fill_rect(rect, col)
	cel.blit_image_to_cel(src)
	if cel.has_method("update_texture"):
		cel.update_texture()
	return rpt(project, lname)

func rpt(project, lname):
	var i = idx(project, lname)
	if i < 0:
		return "missing"
	var cel = project.frames[0].cels[i]
	var img = cel.get_image()
	var r = img.get_used_rect()
	return "img=%dx%d off=(%d,%d) used=(%d,%d %dx%d)" % [img.get_width(), img.get_height(), cel.offset.x, cel.offset.y, r.position.x, r.position.y, r.size.x, r.size.y]

func run(api, image, project, params):
	var mgr = find_mgr(api)
	if mgr == null:
		return {"error": "manager not found"}
	var out = {}
	add_layer(api, project, 1, "Torso", 0, false)
	add_layer(api, project, 0, "Torso_Sprite", idx(project, "Torso"), true)
	add_layer(api, project, 1, "Arm_R", idx(project, "Torso"), true)
	add_layer(api, project, 0, "Arm_Sprite", idx(project, "Arm_R"), true)
	add_layer(api, project, 0, "Pose Layer", project.layers.size() - 1, false)

	out["torso_paint"] = paint(project, "Torso_Sprite", Rect2i(26, 20, 12, 28), Color(0.2, 0.4, 0.9, 1))
	out["arm_paint"] = paint(project, "Arm_Sprite", Rect2i(38, 24, 18, 5), Color(0.9, 0.5, 0.2, 1))

	mgr.update_frame_data()
	out["bones"] = mgr.current_frame_bones.keys()
	out["pose_before"] = rpt(project, "Pose Layer")

	if not mgr.current_frame_bones.has("Arm_R"):
		return out
	var bone = mgr.current_frame_bones["Arm_R"]
	bone.gizmo_origin = Vector2(38, 26)
	bone.bone_rotation = deg_to_rad(45.0)
	mgr.generate_pose(0)

	out["pose_after"] = rpt(project, "Pose Layer")
	out["arm_after"] = rpt(project, "Arm_Sprite")
	var saved = mgr.load_frame_data(project, 0)
	out["saved_rotation_deg"] = rad_to_deg(saved.get("Arm_R", {}).get("bone_rotation", 0.0))
	return out
