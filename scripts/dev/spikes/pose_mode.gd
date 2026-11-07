extends RefCounted
## Switches the project between Skeletor's "draw" and "pose" views.
## Skeletor normally does this from the UI in manage_layer_visibility() when you select the
## Pose Layer. Headlessly nothing selects it, so the source sprites stay visible and any
## render/export shows BOTH the unposed sprites and the posed result.
## Pose mode = Pose Layer visible + every ROOT group layer hidden. Draw mode is the inverse.

func find_mgr(api):
	for c in api.general.get_canvas().get_children():
		if c.has_method("generate_pose") and c.has_method("find_pose_layer"):
			return c
	return null

func run(api, image, project, params):
	var mgr = find_mgr(api)
	if mgr == null:
		return {"error": "manager not found"}
	var pose_mode = bool(params.get("pose_mode", true))
	if mgr.pose_layer == null:
		mgr.pose_layer = mgr.find_pose_layer(project)
	if mgr.pose_layer == null:
		return {"error": "no pose layer in project"}
	mgr.pose_layer.visible = pose_mode
	var hidden = []
	for l in project.layers:
		if l.get_layer_type() == api.tools.LayerTypes.GROUP and not l.parent:
			l.visible = not pose_mode
			hidden.append(str(l.name))
	var canvas = api.general.get_canvas()
	if canvas:
		canvas.set("update_all_layers", true)
		canvas.queue_redraw()
	return {"pose_mode": pose_mode, "pose_layer_visible": mgr.pose_layer.visible, "root_groups_toggled": hidden}
