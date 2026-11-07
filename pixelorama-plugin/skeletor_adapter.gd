## pix-MCP ⇄ Skeletor adapter
##
## The ONLY file in this plugin that touches Skeletor. Skeletor exposes no API of its own, so
## everything here is reached by duck-typing its manager node out of the scene tree -- both are
## sibling Pixelorama extensions in one process, so no fork of either is needed.
##
## Two rules keep this maintainable:
##   1. Nothing outside this file may reference a Skeletor method, property or metadata key.
##      When upstream moves, this is the one place to fix.
##   2. probe() checks the whole shape we depend on and reports exactly what is missing, so a
##      Skeletor update fails loudly on the first call instead of silently corrupting pose data.
##
## Skeletor's higher-level features (tween, quick-set, copy-pose, IK) live in its tool UI script,
## a Control wired to popup menus, and cannot be driven headlessly. They are thin wrappers over
## the manager primitives below and are reimplemented in command_handler.gd instead.
##
## See docs/skeletor-integration.md for the reverse-engineering notes behind every workaround here.
extends RefCounted

## Manager methods we call. A missing one means the integration is broken, not degraded.
const REQUIRED_METHODS: Array[String] = [
	"generate_pose",
	"find_pose_layer",
	"update_frame_data",
	"load_frame_bones",
	"load_frame_data",
	"save_frame_info",
	"is_pose_layer",
	"fix_skeleton_heirarchy",
]

## Manager properties we read or write.
const REQUIRED_PROPERTIES: Array[String] = [
	"current_frame_bones",
	"pose_layer",
	"current_frame",
]

## Bone fields, i.e. exactly what SkeletonBone.serialize() round-trips through cel metadata.
const BONE_FIELDS: Array[String] = [
	"bone_name",
	"parent_bone_name",
	"gizmo_origin",
	"gizmo_rotate_origin",
	"start_point",
	"bone_rotation",
	"transformation_algorithm",
	"gizmo_length",
]

## Bone fields a tween may interpolate. The two name fields are strings and the algorithm is a
## discrete enum, so interpolating any of them is meaningless.
const TWEENABLE_FIELDS: Array[String] = [
	"gizmo_origin",
	"gizmo_rotate_origin",
	"start_point",
	"bone_rotation",
	"gizmo_length",
]

const DEFAULT_POSE_LAYER_NAME: String = "Pose Layer"

var _api: Node = null


func initialize(api: Node) -> void:
	_api = api


## Accessors for the constants above. command_handler.gd holds this adapter as a plain RefCounted,
## so it cannot reach class constants through the instance -- only methods resolve dynamically.
func tweenable_fields() -> Array[String]:
	return TWEENABLE_FIELDS


func default_pose_layer_name() -> String:
	return DEFAULT_POSE_LAYER_NAME


# ─────────────────────────────────────────────
# DISCOVERY
# ─────────────────────────────────────────────

## Finds Skeletor's manager node, or null when the extension is not installed/enabled.
## Deliberately matched on behaviour rather than node name or script path -- those are the parts
## most likely to churn in a pre-1.0 extension. Re-resolved on every call rather than cached,
## because Skeletor may be enabled after this plugin has already started.
func manager():
	if _api == null:
		return null
	var canvas = _api.general.get_canvas()
	if canvas == null:
		return null
	for child in canvas.get_children():
		if child.has_method("generate_pose") and child.has_method("find_pose_layer"):
			return child
	return null


## Verifies the whole manager and bone shape this adapter depends on.
## Returns {"ok": bool, "installed": bool, "missing_methods": [...], "missing_properties": [...]}.
func probe() -> Dictionary:
	var result := {
		"ok": false,
		"installed": false,
		"missing_methods": [],
		"missing_properties": [],
	}
	var mgr = manager()
	if mgr == null:
		return result
	result["installed"] = true
	for method_name in REQUIRED_METHODS:
		if not mgr.has_method(method_name):
			result["missing_methods"].append(method_name)
	for property_name in REQUIRED_PROPERTIES:
		if not property_name in mgr:
			result["missing_properties"].append(property_name)
	result["ok"] = (
		result["missing_methods"].is_empty() and result["missing_properties"].is_empty()
	)
	return result


## One-line reason the adapter cannot run, or "" when it can.
func unavailable_reason() -> String:
	var p := probe()
	if not p["installed"]:
		return (
			"Skeletor extension not found. Install Skeletor.pck into Pixelorama's "
			+ "extensions folder and enable it ([extensions] Skeletor=true in config.ini, "
			+ "or Edit > Preferences > Extensions), then restart Pixelorama."
		)
	if not p["ok"]:
		return (
			"Skeletor is installed but its manager no longer matches the shape pix-MCP expects "
			+ "(missing methods: %s; missing properties: %s). This adapter needs updating -- see "
			+ "docs/skeletor-integration.md."
		) % [str(p["missing_methods"]), str(p["missing_properties"])]
	return ""


# ─────────────────────────────────────────────
# POSE LAYER
# ─────────────────────────────────────────────

## Resolves the project's pose layer, or null.
func pose_layer(project):
	var mgr = manager()
	if mgr == null or project == null:
		return null
	if mgr.pose_layer != null and project.layers.has(mgr.pose_layer):
		return mgr.pose_layer
	mgr.pose_layer = mgr.find_pose_layer(project)
	return mgr.pose_layer


## Marks a layer as the pose layer and persists that choice.
##
## Skeletor's fix_skeleton_heirarchy() adopts any pixel layer whose capitalised name contains
## "Pose Layer", but only sets the manager's in-memory reference -- it never writes the
## "SkeletorPoseLayer" metadata flag that is_pose_layer()/find_pose_layer() read back. Upstream
## only writes that flag through the pose_layer setter, which the tool UI's "assign pose layer"
## menu item triggers. Nothing does that headlessly, so assigning through the setter here is what
## makes the choice survive a project reload or a manager reset.
func assign_pose_layer(project, layer) -> bool:
	var mgr = manager()
	if mgr == null or layer == null:
		return false
	mgr.pose_layer = layer  # setter writes the SkeletorPoseLayer metadata flag
	return mgr.is_pose_layer(layer)


# ─────────────────────────────────────────────
# BULK LAYER EDITING
# ─────────────────────────────────────────────

## Suspends Skeletor's reaction to layer changes for the duration of bulk layer work.
##
## Skeletor re-catalogues its whole bone set on every layer change, and with NESTED bone groups
## that cost grows explosively. Measured per bone while building a nested rig:
##
##     bone 1   17 ms      bone 4     49 ms
##     bone 2    9 ms      bone 5    928 ms
##     bone 3   11 ms      bone 6  32740 ms
##
## A 13-bone rig never finishes: it exceeds the bridge's 60s main-thread cap and leaves
## Pixelorama wedged. The same nested creation with the Skeletor extension disabled runs at
## 1-2 ms per bone, so the cost is entirely Skeletor's reaction, not Pixelorama's layer code.
## Disconnecting its project signals for the duration removes it: 1-2 ms per bone with the
## extension still installed and working.
##
## Returns whether signals were actually suspended; pass that to end_bulk_layer_edit().
func begin_bulk_layer_edit() -> bool:
	var mgr = manager()
	if mgr == null or not mgr.has_method("manage_project_signals"):
		return false
	mgr.manage_project_signals(false)
	return true


## Restores what begin_bulk_layer_edit() suspended.
##
## Upstream's connect branch is a coroutine -- it awaits two frames before restoring the UI
## signals -- so this call returns before it has fully finished. The per-layer reconnections it
## performs are synchronous, which is what matters here, and callers catalogue() afterwards.
func end_bulk_layer_edit(was_suspended: bool) -> void:
	if not was_suspended:
		return
	var mgr = manager()
	if mgr == null:
		return
	mgr.manage_project_signals(true)


# ─────────────────────────────────────────────
# BONES
# ─────────────────────────────────────────────

## Re-catalogues every group layer as a bone and syncs the manager to the project's current frame.
## Must be called after any layer or frame change, or bone lookups miss.
func catalogue(project) -> void:
	var mgr = manager()
	if mgr == null:
		return
	if pose_layer(project) == null:
		return
	mgr.update_frame_data()


## SkeletonBone objects for one frame, keyed by bone name. Empty when the frame has no skeleton.
func bones_at(project, frame: int) -> Dictionary:
	var mgr = manager()
	if mgr == null:
		return {}
	return mgr.load_frame_bones(project, frame)


## Raw serialized bone dictionaries for one frame -- plain values, safe to diff and interpolate.
func data_at(project, frame: int) -> Dictionary:
	var mgr = manager()
	if mgr == null:
		return {}
	return mgr.load_frame_data(project, frame)


## Writes a frame's bones back to cel metadata.
##
## When the frame is the manager's current one its in-memory bone set is re-synced too. Skeletor
## keeps that set as the authority for the current frame: it renders from it (see render_frames),
## and update_frame_data() ends by writing it straight back to cel metadata. So a metadata-only
## write is silently reverted by the next catalogue() -- which is how a pivot set at rig creation
## would vanish on the following pose call.
func save_bones(project, bones: Dictionary, frame: int) -> void:
	var mgr = manager()
	if mgr == null:
		return
	mgr.save_frame_info(project, bones, frame)
	if frame == mgr.current_frame:
		mgr.current_frame_bones = mgr.load_frame_bones(project, frame)


## Copies one frame's skeleton onto every frame that has none.
##
## Pixelorama's duplicate_frame copies cel images but not cel metadata, and Skeletor keeps each
## frame's entire skeleton in cel metadata, so frames added by any means start with no bones at
## all. (command_handler.gd's _cmd_duplicate_frame now carries metadata across, but frames created
## any other way -- or before that fix -- still need seeding.) Returns the frames seeded.
func seed_frames_from(project, source_frame: int) -> Array:
	var mgr = manager()
	if mgr == null:
		return []
	var seed_bones := bones_at(project, source_frame)
	if seed_bones.is_empty():
		return []
	var seeded := []
	for frame_idx in range(project.frames.size()):
		if frame_idx == source_frame:
			continue
		if bones_at(project, frame_idx).is_empty():
			mgr.save_frame_info(project, seed_bones, frame_idx)
			seeded.append(frame_idx)
	return seeded


## The pivot Skeletor's "quick set bones" would choose: the centre of a bone group's merged
## content, in canvas coordinates.
##
## Not delegated to the manager's get_best_origin(): that reads get_used_rect() straight off the
## cel image, which on Pixelorama 1.2's sparse cels is in cel-local coordinates. It is only
## correct while cel.offset happens to be zero. Adding the offset here makes it correct regardless.
func best_origin(project, layer_idx: int) -> Vector2i:
	if project == null or layer_idx < 0 or layer_idx >= project.layers.size():
		return Vector2i.ZERO
	var layer = project.layers[layer_idx]
	if layer.get_layer_type() != _api.tools.LayerTypes.GROUP:
		return Vector2i.ZERO
	var frame_idx: int = project.current_frame
	if frame_idx < 0 or frame_idx >= project.frames.size():
		return Vector2i.ZERO
	var merged := Rect2i()
	for child in layer.get_children(false):
		var cel = project.frames[frame_idx].cels[child.index]
		if cel.get_class_name() != "PixelCel":
			continue
		var used: Rect2i = cel.get_image().get_used_rect()
		if not used.has_area():
			continue
		if "offset" in cel:
			used.position += Vector2i(cel.offset)
		merged = used if not merged.has_area() else merged.merge(used)
	if not merged.has_area():
		return Vector2i.ZERO
	return merged.position + (merged.size / 2)


## A bone's state as plain JSON-safe values.
func describe_bone(bone) -> Dictionary:
	if bone == null:
		return {}
	return {
		"name": str(bone.bone_name),
		"parent": str(bone.parent_bone_name),
		"pivot": {"x": bone.gizmo_origin.x, "y": bone.gizmo_origin.y},
		"rotation_deg": rad_to_deg(bone.bone_rotation),
		"translate": {"x": bone.start_point.x, "y": bone.start_point.y},
		"rotate_origin_deg": rad_to_deg(bone.gizmo_rotate_origin),
		"transformation_algorithm": int(bone.transformation_algorithm),
	}


# ─────────────────────────────────────────────
# RENDERING
# ─────────────────────────────────────────────

## Renders the posed result of each requested frame into the pose layer's cel.
##
## generate_pose() has three failure modes that all return silently, so they are handled here
## rather than at each call site:
##
##   * it early-returns unless the pose layer is visible, so a render issued while the project is
##     in draw view does nothing. The layer is shown for the render and the previous visibility
##     restored afterwards -- the rendered pixels persist in the cel either way.
##   * a failsafe checks whether the CURRENT frame's in-memory bones are empty and, if so, renders
##     an empty image to the current frame and returns -- even when asked for a different frame.
##     So one skeleton-less current frame suppresses every render and blanks that frame.
##   * for the current frame it composites from the in-memory bone set, not from cel metadata, so
##     a frame whose metadata was just written renders its previous pose unless memory is re-synced.
##
## Both of the latter two are fixed by re-syncing current_frame_bones from metadata first.
## save_bones_before_render is always false: upstream would otherwise write the in-memory bones of
## the current frame over the frame being rendered.
func render_frames(project, frames: Array) -> Dictionary:
	var mgr = manager()
	if mgr == null:
		return {"rendered": [], "error": "Skeletor manager not available"}
	var layer = pose_layer(project)
	if layer == null:
		return {"rendered": [], "error": "Project has no pose layer"}

	var was_visible: bool = layer.visible
	if not was_visible:
		layer.visible = true

	mgr.current_frame_bones = mgr.load_frame_bones(project, mgr.current_frame)

	var rendered := []
	for frame_idx in frames:
		var f := int(frame_idx)
		if f < 0 or f >= project.frames.size():
			continue
		mgr.generate_pose(f, false)
		rendered.append(f)

	if not was_visible:
		layer.visible = was_visible

	_refresh_canvas()
	return {"rendered": rendered, "pose_layer_was_hidden": not was_visible}


# ─────────────────────────────────────────────
# VIEW MODE
# ─────────────────────────────────────────────

## Switches the project between Skeletor's draw view and pose view.
##
## Upstream does this in manage_layer_visibility(), which only runs when the UI changes the
## selected layer. Driven over MCP nothing ever selects the pose layer, so the source sprites stay
## visible alongside the rendered pose and any export shows both. Pose view is the pose layer
## visible with every ROOT group hidden; draw view is the inverse. Nested groups are left alone --
## Skeletor ignores group visibility while compositing, and toggling them would discard the user's
## own per-group visibility choices.
func set_view_mode(project, pose_view: bool) -> Dictionary:
	var layer = pose_layer(project)
	if layer == null:
		return {"error": "Project has no pose layer"}
	layer.visible = pose_view
	var toggled := []
	for l in project.layers:
		if l.get_layer_type() == _api.tools.LayerTypes.GROUP and not l.parent:
			l.visible = not pose_view
			toggled.append(str(l.name))
	_refresh_canvas()
	return {
		"mode": "pose" if pose_view else "draw",
		"pose_layer_visible": layer.visible,
		"root_groups_toggled": toggled,
	}


## Reports the current view mode without changing it.
func view_mode(project) -> String:
	var layer = pose_layer(project)
	if layer == null:
		return "unknown"
	if not layer.visible:
		return "draw"
	for l in project.layers:
		if l.get_layer_type() == _api.tools.LayerTypes.GROUP and not l.parent:
			if l.visible:
				return "mixed"
	return "pose"


func _refresh_canvas() -> void:
	var canvas = _api.general.get_canvas()
	if canvas == null:
		return
	if "update_all_layers" in canvas:
		canvas.update_all_layers = true
	canvas.queue_redraw()


# ─────────────────────────────────────────────
# ANIMATION TRANSFER (.skeletor files)
# ─────────────────────────────────────────────
#
# Skeletor defines a `.skeletor` format -- a ConfigFile with one section per frame, key
# "skeleton", holding that frame's serialized bone dictionary -- plus an exporter and a
# "Load Skeleton" menu item. Both are broken in v0.17-v0.19: Main.gd calls
# skeleton_manager.load_frame_info() and .current_frame_data, neither of which exists since the
# manager was refactored in b0fe3b8 (2025-11-24). The export silently writes a 0-byte file and
# reports success; the import dereferences the resulting null and segfaults Pixelorama.
#
# These read and write the same format, so files stay interchangeable if upstream fixes theirs.

## Fields that describe a pose. `bone_name` and `parent_bone_name` are deliberately excluded:
## identity and hierarchy always come from the target rig, never from the file.
const POSE_FIELDS: Array[String] = [
	"bone_rotation",
	"gizmo_rotate_origin",
	"start_point",
	"transformation_algorithm",
	"gizmo_length",
]

## Pivot, in absolute canvas coordinates. Copied only on request -- see import_animation().
const PIVOT_FIELD: String = "gizmo_origin"


## Writes every frame's skeleton to a `.skeletor` file. Returns {"error": ...} or a summary.
func export_animation(project, path: String) -> Dictionary:
	if manager() == null:
		return {"error": "Skeletor manager not available"}
	if pose_layer(project) == null:
		return {"error": "Project has no pose layer"}
	var save_file := ConfigFile.new()
	var frames_written := []
	var bone_names := {}
	for frame_idx in range(project.frames.size()):
		var frame_data: Dictionary = data_at(project, frame_idx)
		if frame_data.is_empty():
			continue
		save_file.set_value(str(frame_idx), "skeleton", frame_data)
		frames_written.append(frame_idx)
		for bone_name in frame_data.keys():
			bone_names[str(bone_name)] = true
	if frames_written.is_empty():
		return {"error": "No frame in this project has a skeleton to export"}
	var code := save_file.save(path)
	if code != OK:
		return {"error": "Could not write '%s' (error %d)" % [path, code]}
	var written_size := 0
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		written_size = f.get_length()
		f.close()
	return {
		"path": path,
		"bytes": written_size,
		"frames": frames_written,
		"bones": bone_names.keys(),
	}


## Reads a `.skeletor` file into {frame_index: {bone_name: {field: value}}}.
func read_animation_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "No such file: %s" % path}
	var file := ConfigFile.new()
	var code := file.load(path)
	if code != OK:
		return {"error": "Could not read '%s' as a .skeletor file (error %d)" % [path, code]}
	var frames := {}
	for section in file.get_sections():
		var frame_idx = str_to_var(section)
		if typeof(frame_idx) != TYPE_INT:
			continue
		# The format writes one key, "skeleton"; fall back to the first key defensively.
		var value = file.get_value(section, "skeleton", {})
		if typeof(value) != TYPE_DICTIONARY or value.is_empty():
			var keys := file.get_section_keys(section)
			if keys.size() > 0:
				value = file.get_value(section, keys[0], {})
		if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
			frames[int(frame_idx)] = value
	if frames.is_empty():
		return {"error": "'%s' contains no frame data (a 0-byte file is what Skeletor's own broken exporter produces)" % path}
	return {"frames": frames}


## Applies an animation onto this project's rig, matching bones by name.
##
## Bones the target does not have are skipped, and the target's own hierarchy is always kept --
## `parent_bone_name` is never taken from the file, so a rig with the same bone names but a
## different parenting still receives the motion.
##
## `include_pivots` is false by default. `gizmo_origin` is an ABSOLUTE canvas coordinate, so
## copying it moves every joint to wherever the source character's joints were; that is only
## correct when the two rigs share proportions and canvas size. Leaving it off transfers the
## motion while each rig keeps its own joint positions, which is what retargeting usually means.
func import_animation(project, frames_data: Dictionary, include_pivots: bool) -> Dictionary:
	var mgr = manager()
	if mgr == null:
		return {"error": "Skeletor manager not available"}
	if pose_layer(project) == null:
		return {"error": "Project has no pose layer"}

	var target_bones: Dictionary = bones_at(project, project.current_frame)
	if target_bones.is_empty():
		for frame_idx in range(project.frames.size()):
			target_bones = bones_at(project, frame_idx)
			if not target_bones.is_empty():
				break
	if target_bones.is_empty():
		return {"error": "This project has no rig to apply the animation to"}

	var matched := {}
	var unmatched_in_file := {}
	var applied_frames := []
	var skipped_frames := []

	var frame_keys := frames_data.keys()
	frame_keys.sort()
	for frame_idx in frame_keys:
		var f := int(frame_idx)
		if f < 0 or f >= project.frames.size():
			skipped_frames.append(f)
			continue
		var frame_bones: Dictionary = bones_at(project, f)
		if frame_bones.is_empty():
			continue
		var source: Dictionary = frames_data[frame_idx]
		for bone_name in source.keys():
			var name := str(bone_name)
			if not frame_bones.has(name):
				unmatched_in_file[name] = true
				continue
			matched[name] = true
			# Feed SkeletonBone.deserialize() only the fields we mean to transfer; it leaves
			# every field absent from the dictionary at its current value, and already accepts
			# both the string-encoded and typed forms a ConfigFile may hold.
			var incoming: Dictionary = source[bone_name]
			var filtered := {}
			for field in POSE_FIELDS:
				if incoming.has(field):
					filtered[field] = incoming[field]
			if include_pivots and incoming.has(PIVOT_FIELD):
				filtered[PIVOT_FIELD] = incoming[PIVOT_FIELD]
			frame_bones[name].deserialize(filtered, true)
		save_bones(project, frame_bones, f)
		applied_frames.append(f)

	var unmatched_in_rig := []
	for name in target_bones.keys():
		if not matched.has(str(name)):
			unmatched_in_rig.append(str(name))

	return {
		"applied_frames": applied_frames,
		"skipped_frames": skipped_frames,
		"bones_applied": matched.keys(),
		"bones_in_file_not_in_rig": unmatched_in_file.keys(),
		"bones_in_rig_not_in_file": unmatched_in_rig,
		"pivots_copied": include_pivots,
	}
