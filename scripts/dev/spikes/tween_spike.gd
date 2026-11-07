extends RefCounted

func find_mgr(api):
	for c in api.general.get_canvas().get_children():
		if c.has_method("generate_pose") and c.has_method("find_pose_layer"):
			return c
	return null

func set_key(mgr, project, frame, bone_name, pivot, rot_deg):
	var bones = mgr.load_frame_bones(project, frame)
	if not bones.has(bone_name):
		return false
	bones[bone_name].gizmo_origin = pivot
	bones[bone_name].bone_rotation = deg_to_rad(rot_deg)
	mgr.save_frame_info(project, bones, frame)
	return true

func pose_rect(project, mgr, frame):
	var i = project.layers.find(mgr.pose_layer)
	var cel = project.frames[frame].cels[i]
	var img = cel.get_image()
	var r = img.get_used_rect()
	return "(%d,%d %dx%d)+off(%d,%d)" % [r.position.x, r.position.y, r.size.x, r.size.y, cel.offset.x, cel.offset.y]

func run(api, image, project, params):
	var mgr = find_mgr(api)
	if mgr == null:
		return {"error": "manager not found"}
	var bone_name = "Arm_R"
	var pivot = Vector2(38, 26)
	var from_frame = 0
	var to_frame = project.frames.size() - 1
	mgr.update_frame_data()

	# duplicate_frame does NOT copy cel metadata, so frames 1..n have no skeleton.
	# Seed every frame from the frame that does have one.
	var seed_bones = mgr.load_frame_bones(project, from_frame)
	if seed_bones.is_empty():
		return {"error": "source frame has no skeleton"}
	for f in range(project.frames.size()):
		if f != from_frame:
			mgr.save_frame_info(project, seed_bones, f)

	# generate_pose() bails out early if the CURRENT frame's in-memory bones are empty,
	# even when asked to render a different frame. Refresh them after seeding.
	mgr.current_frame_bones = mgr.load_frame_bones(project, mgr.current_frame)

	# keyframes at both ends
	set_key(mgr, project, from_frame, bone_name, pivot, 0.0)
	set_key(mgr, project, to_frame, bone_name, pivot, 90.0)

	# --- tween, reimplemented so easing is selectable (upstream hardcodes LINEAR/EASE_IN)
	var trans = Tween.TRANS_SINE
	var ease_t = Tween.EASE_IN_OUT
	var start_data = mgr.load_frame_data(project, from_frame)
	var end_data = mgr.load_frame_data(project, to_frame)
	if not (start_data.has(bone_name) and end_data.has(bone_name)):
		return {"error": "bone missing from keyframes"}

	for frame_idx in range(from_frame + 1, to_frame):
		var frame_bones = mgr.load_frame_bones(project, frame_idx)
		if not frame_bones.has(bone_name):
			continue
		var bone = frame_bones[bone_name]
		for key in start_data[bone_name].keys():
			var prop = bone.get(key)
			if typeof(prop) == TYPE_STRING or prop == null:
				continue
			bone.set(key, Tween.interpolate_value(
				start_data[bone_name][key],
				end_data[bone_name][key] - start_data[bone_name][key],
				float(frame_idx - from_frame),
				float(to_frame - from_frame),
				trans, ease_t))
		mgr.save_frame_info(project, frame_bones, frame_idx)

	# The current frame renders from in-memory bones, not from cel metadata, so it must be
	# re-synced after any metadata write or it renders a stale pose.
	mgr.current_frame_bones = mgr.load_frame_bones(project, mgr.current_frame)

	# render every frame
	for f in range(project.frames.size()):
		mgr.generate_pose(f, false)

	var rows = []
	for f in range(project.frames.size()):
		var d = mgr.load_frame_data(project, f)
		var deg = rad_to_deg(d.get(bone_name, {}).get("bone_rotation", 0.0))
		rows.append("frame %d  rot=%6.2f deg  pose=%s" % [f, deg, pose_rect(project, mgr, f)])
	return {"frames": project.frames.size(), "easing": "TRANS_SINE / EASE_IN_OUT", "timeline": rows}
