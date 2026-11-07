# Skeletor Integration — Architecture & Findings

Reverse-engineered and verified live on 2026-11-06 against:

| Component | Version |
|---|---|
| Pixelorama | `v1.2.4-stable` (tag, 2026-11-03) |
| Godot | 4.7.2 stable |
| Skeletor | `v0.19` (official `Skeletor.pck` release asset) |
| Pixelorama ExtensionsApi | 10 |
| pix-MCP bridge | 0.2.1 |

## 1. How the pieces connect

```
MCP client ──stdio──▶ Node MCP server (mcp-server/)
                          │ HTTP POST 127.0.0.1:7373/command  {"tool":…,"params":…}
                          ▼
                 PixMcpBridge.pck ─┐  sibling Pixelorama extensions,
                 Skeletor.pck ─────┘  same Godot SceneTree, same process
                          ▼
                 Pixelorama ExtensionsApi
```

**Skeletor has no API of its own and needs none.** Because both are extensions in one
process, the bridge reaches Skeletor's manager node directly through the scene tree.
No fork of Skeletor and no changes to Pixelorama are required.

## 2. Locating the Skeletor manager

It is a child of `api.general.get_canvas()`, node name `SkeletonPreview`,
script `res://src/Extensions/Skeletor/Manager/skeleton_manager.gd`.

Locate it by **duck-typing, never by name or script path** — those are the parts most
likely to churn in a pre-1.0 extension:

```gdscript
func find_skeletor(api):
    for c in api.general.get_canvas().get_children():
        if c.has_method("generate_pose") and c.has_method("find_pose_layer"):
            return c
    return null
```

Keep every Skeletor touchpoint behind a single adapter file so there is exactly one
place to fix when upstream moves, and probe on startup so a shape change fails loudly
instead of silently corrupting pose data.

## 3. Data model

- **A bone is a Group Layer.** Nesting group layers = bone hierarchy.
- **The Pose Layer** is a Pixel Layer that Skeletor renders the final posed frame into.
  It is found two ways:
  - by meta flag `SkeletorPoseLayer` (set once assigned), via `is_pose_layer()`;
  - on first discovery, by name — `fix_skeleton_heirarchy()` matches any pixel layer
    where `"Pose Layer" in layer.name.capitalize()`.

  Name discovery sets only the manager's **in-memory** reference; it never writes the
  `SkeletorPoseLayer` flag that `is_pose_layer()`/`find_pose_layer()` read back. The flag is
  written exclusively by the `pose_layer` **setter** (which calls `assign_pose_layer()`), and
  upstream only reaches that setter through the tool UI's assign menu item. Nothing does that
  headlessly, so the choice does not survive a manager reset or a project reload unless the
  adapter assigns through the setter itself:

  ```gdscript
  mgr.pose_layer = layer   # setter -> assign_pose_layer() -> sets SkeletorPoseLayer
  ```

  This also constrains naming: a pose layer whose name does not contain "Pose Layer" can never be
  re-discovered, so `setup_skeletor_rig` rejects one.
- **Pose data is cel metadata**, *not* layer or canvas data. Per frame, on the pose
  layer's cel, key `SkeletorSkeleton`, a `var_to_str`-serialized
  `{bone_name: {...}}` dictionary.

Each bone serializes to exactly these fields (`SkeletonBone.serialize()`):

| Field | Type | Meaning |
|---|---|---|
| `bone_name` | String | must equal the group layer's name |
| `parent_bone_name` | String | parent group's name, `""` for root |
| `gizmo_origin` | Vector2 | pivot, in canvas coordinates |
| `gizmo_rotate_origin` | float | base gizmo angle, radians |
| `start_point` | Vector2 | translation, relative to `gizmo_origin` |
| `bone_rotation` | float | rotation, radians, relative to `gizmo_rotate_origin` |
| `transformation_algorithm` | int | `DrawingAlgos.RotationAlgorithm` (0=cleanEdge, 1=OmniScale, 2=NNS) |
| `gizmo_length` | int | gizmo handle length (UI affordance only) |

`_apply_bone()` early-returns when `bone_rotation == 0 and start_point == Vector2.ZERO`,
so an untouched bone costs nothing.

## 4. Verified call sequence

```gdscript
var mgr = find_skeletor(api)
mgr.update_frame_data()                 # catalogues every group layer as a bone
var bone = mgr.current_frame_bones["Arm_R"]
bone.gizmo_origin  = Vector2(38, 26)    # pivot (shoulder)
bone.bone_rotation = deg_to_rad(45.0)
mgr.generate_pose(0)                    # renders frame 0 into the Pose Layer
```

Useful manager members: `current_frame_bones`, `pose_layer`, `generate_pose(frame, save_before_render)`,
`load_frame_data(project, frame)` (plain dicts), `load_frame_bones(project, frame)` (SkeletonBone objects),
`save_frame_info(project, bones, frame)`, `get_best_origin(layer_idx)` (quick-set pivot),
`add_to_generation_queue(frame)`, `fix_skeleton_heirarchy(data)`.

**Verified result:** a 2-bone rig (`Torso` → `Arm_R`) posed 45° rendered correctly —
Pose Layer went from empty to `64x64 used=(26,20 26x28)`, and `bone_rotation` persisted
as `45.0°` in cel metadata. See `scripts/dev/spikes/rig_pose_spike.gd`.

## 5. Building a rig programmatically

New layers nest according to the **currently selected layer**:
`AnimationTimeline.add_layer()` parents the new layer into `project.layers[current_layer]`
only if that layer is a `GroupLayer` **and** `expanded == true`. Toggle `expanded` to
choose child-of-group vs. sibling-above.

Verified hierarchy produced this way:

```
5  Pose Layer                      pixel,  top level
4  Torso            t=1  parent=            <- root bone
3    Arm_R          t=1  parent=Torso       <- child bone
2      Arm_Sprite   t=0  parent=Arm_R
1    Torso_Sprite   t=0  parent=Torso
```

…which Skeletor catalogued as `{Arm_R: parent "Torso", Torso: parent ""}`.

## 6. Upstream bugs found (all fixed on this branch — see §10)

### 6a. `ExtensionsApi.add_new_layer()` mis-names nested layers

`add_new_layer()` renames `project.layers[above_layer + 1]`. That assumes the new layer
lands *above* the anchor — true only when it does **not** nest. When it nests into a
group it is inserted *at* `above_layer` and the group shifts up, so the rename lands on
**the group instead of the new layer**. Observed live: a group ended up named
`Torso_Sprite` while the real new layer kept its default name.

Workaround (used in the spike): snapshot `project.layers` before the add, then identify
the created layer by object identity and rename that.

### 6b. The bridge ignores Pixelorama's sparse cels — *all pixel writes currently clip*

Pixelorama 1.2 cels are **sparse**: `cel.image` holds only the used content, positioned
by `cel.offset`, and `PixelLayer.new_empty_cel()` deliberately creates a **1×1**
placeholder. `project.crop_image_to_project_size(image, cel.offset)` expands it for
compositing.

The bridge assumes `cel.get_image()` is project-sized. Against Pixelorama 1.2.4 a plain
`create_canvas` + `draw_rect` therefore reports:

```
{"pixels_drawn": 0, "pixels_clipped": 400}
```

This is **not** Skeletor-specific — it breaks the stock bridge's whole drawing surface,
and it reproduces on both `v1.2.4-stable` and `master`. Fix: write through the cel's own
growing primitives rather than into `get_image()` directly —

```gdscript
var src = Image.create_empty(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
# …draw into src in canvas coordinates…
cel.blit_image_to_cel(src)   # grows the cel and sets offset
cel.update_texture()
```

`PixelCel` also offers `ensure_canvas_point_in_bounds(point)`, `resize_cel_image(size, offset)`
and `shrink_to_content()` for finer-grained writes.

### 6c. `_api.project.current_layer = …` aborts both layer commands

`ProjectAPI` exposes `current_layer` read-only. `_cmd_add_layer` and `_cmd_create_layer_group`
both assigned to it, raising
`Invalid assignment of property or key 'current_layer' … on a base object of type 'RefCounted (ProjectAPI)'`
and aborting the command *after* the layer was created but *before* it returned — so the caller
got an empty `{}` response for a layer that actually exists. The line above it already sets
`project.current_layer` directly, so the assignment was redundant as well as fatal.

### 6d. `get_best_origin()` ignores sparse-cel offsets

Skeletor's quick-set pivot reads `get_used_rect()` straight off the cel image. On Pixelorama 1.2's
sparse cels that rect is in **cel-local** coordinates, so the returned pivot is only correct while
`cel.offset` happens to be zero. The adapter computes the merged rect itself and adds the offset
(`best_origin()`) instead of delegating.

## 7. What must be reimplemented bridge-side

> **Status:** tweening, quick-set and the draw/pose view switch are implemented and verified —
> see `pixelorama-plugin/skeletor_adapter.gd` and the `_cmd_*skeletor*` / `_cmd_apply_bone_pose`
> handlers in `command_handler.gd`. Copy-pose and IK are not.

Skeletor's higher-level features live in its **tool UI script** (`Tool/skeleton_tool.gd`,
a `Control` wired to popup menus), not in the manager, so they cannot be called headlessly.
They are all thin wrappers over manager primitives and are cheaper to reimplement than to puppet:

- **Tweening** (`tween_skeleton_data`): loads start/end frame data and walks intermediate
  frames with `Tween.interpolate_value`, hardcoded `TRANS_LINEAR` / `EASE_IN`, then
  `save_frame_info` + `add_to_generation_queue` per frame. Reimplementing it is what lets
  us expose easing options at all — upstream has none.
- **Quick-set bones** (`quick_set_bones`): sets each bone's `gizmo_origin` to
  `mgr.get_best_origin(layer_idx)` (centre of the group's merged used-rect).
- **Copy pose between frames** (`copy_bone_data`): `deserialize(other.serialize(false), true)`.
- **IK**: `Classes/IKAlgorithms.gd` exposes one static, `get_ik_cels()`; chain size,
  iteration count and error margin are tool UI state.

## 8. Notes on running it

- Pixelorama's user dir on macOS is `~/Library/Application Support/pixelorama`
  (lowercase — `custom_user_dir_name`).
- Extensions are **disabled by default**: dropping a `.pck` in `extensions/` loads it but
  it never starts until `[extensions] <name>=true` is set in `config.ini`, or it is ticked
  in Edit → Preferences → Extensions. The `name` key is the `"name"` field of
  `extension.json`, which must also match the `.pck` filename.
- If Pixelorama is killed rather than quit, stale `.running` / `extensions/Monitoring.ini`
  make the next launch treat the session as a crash and **quarantine the extensions** into
  `give_in_bug_report/`. `scripts/dev/run-pixelorama.sh` clears both before starting.

## 9. Animating across frames — six traps, all verified

Posing one frame is easy; animating is where the sharp edges are. An 8-frame arm swing
(0° → 90°, sine ease-in-out) was built and rendered successfully — see
`scripts/dev/spikes/tween_spike.gd` and `docs/spike-arm-swing.gif`. Six things must be
handled, or it silently produces nothing:

**9a. Duplicating a frame does not duplicate the skeleton.**
`duplicate_frame` copies cel *images* but not cel *metadata*, so new frames have no
`SkeletorSkeleton` at all — `load_frame_data()` returns `{}` and every bone lookup misses.
Any tool that adds frames must explicitly seed them:

```gdscript
var seed_bones = mgr.load_frame_bones(project, source_frame)
for f in range(project.frames.size()):
    if f != source_frame:
        mgr.save_frame_info(project, seed_bones, f)
```

**9b. `generate_pose(frame)` bails out on the *current* frame's bones.**
It correctly loads the target frame's bones for compositing
(`if for_frame != current_frame: bone_set = load_frame_bones(project, for_frame)`),
but an earlier failsafe checks the wrong set:

```gdscript
if current_frame_bones.is_empty():
    _render_image(image)   # renders an EMPTY image, to the CURRENT frame
    return
```

So if the frame you happen to be sitting on has no skeleton, *every* render is skipped —
including renders of other frames — and the current frame gets blanked. Ensure
`mgr.current_frame_bones` is populated before rendering anything.

**9c. The current frame renders from memory, not from metadata.**
For `for_frame == current_frame`, Skeletor uses the in-memory `current_frame_bones`.
Writing pose data to cel metadata alone leaves the current frame rendering a stale pose.
Re-sync immediately before rendering:

```gdscript
mgr.current_frame_bones = mgr.load_frame_bones(project, mgr.current_frame)
```

**Verified output** (arm pivoting at the shoulder, bounding box narrowing as it swings
from horizontal to vertical):

```
frame 0  rot=  0.00°  pose=(26,20 30x28)
frame 1  rot=  4.46°  pose=(26,20 29x28)
frame 2  rot= 16.94°  pose=(26,20 29x28)
frame 3  rot= 34.99°  pose=(26,20 28x28)
frame 4  rot= 55.01°  pose=(26,20 24x28)
frame 5  rot= 73.06°  pose=(26,20 19x28)
frame 6  rot= 85.54°  pose=(26,20 16x28)
frame 7  rot= 90.00°  pose=(26,20 15x28)
```

**9d. Nothing selects the Pose Layer headlessly, so renders and exports double up.**
Skeletor swaps between a *draw* view and a *pose* view in `manage_layer_visibility()`, which only
runs when the UI changes the selected layer. Driven over MCP nothing ever selects the Pose Layer,
so the source sprites stay visible alongside the rendered pose — an export then shows the unposed
sprites *and* the posed result. The rule is simple enough to apply directly:

```gdscript
# pose view: show the result, hide the source art
mgr.pose_layer.visible = true
for l in project.layers:
    if l.get_layer_type() == api.tools.LayerTypes.GROUP and not l.parent:
        l.visible = false   # root groups only; the draw view is the inverse
```

See `scripts/dev/spikes/pose_mode.gd`. Any export or capture after posing needs this, and it is
the natural job of a `set_skeletor_mode` tool.

**9e. The in-memory bone set is the authority for the current frame — in both directions.**
§9c covers the read side. The write side is worse: `update_frame_data()` *ends* by calling
`save_frame_info(project)`, which writes `current_frame_bones` straight back to cel metadata. So a
metadata-only write to the current frame is silently reverted by the next catalogue pass. Observed
live: a pivot set during rig construction read back as `(0,0)` on the following pose call, because
`load_frame_bones()` returns **fresh** `SkeletonBone` objects rather than the manager's own, so
writing to them left `current_frame_bones` holding the stale defaults. Every write must re-sync:

```gdscript
mgr.save_frame_info(project, bones, frame)
if frame == mgr.current_frame:
    mgr.current_frame_bones = mgr.load_frame_bones(project, frame)
```

**9f. `generate_pose()` is a no-op while the pose layer is hidden.**
`if not pose_layer.visible: return`, before any work. Combined with 9d, the default headless state
(draw view, pose layer hidden) means posing silently does nothing. Show the layer for the render
and restore the previous visibility afterwards — the rendered pixels persist in the cel regardless
of visibility.

The easing curve is ours, not Skeletor's: upstream's tween hardcodes
`TRANS_LINEAR / EASE_IN`. Because we reimplement the loop, every Godot `Tween.TransitionType`
and `EaseType` is available to `generate_skeletor_tween`.

## 10. Fixes applied on this branch

All six verified live against Pixelorama v1.2.4-stable. Everything is in
`pixelorama-plugin/command_handler.gd` except #6.

| # | Fix | Verification |
|---|---|---|
| 1 | `_ensure_full_canvas_cel()` normalises sparse cels before any read or write; both `_get_target_cel_and_image` and `_commit_image_change` call it | `draw_rect` went from `drawn 0 / clipped 400` to `drawn 400 / clipped 0` |
| 2 | `_composite_frame_layers` blits each cel at `_cel_offset(cel)` rather than `Vector2i.ZERO` | sprites no longer stamped at the canvas origin in exports |
| 3 | `_add_layer_safely()` adds the layer unnamed, then renames whichever layer actually appeared; used by `_cmd_add_layer` and `_cmd_create_layer_group` | `Arm_Sprite -> Arm_R -> Torso` nests and names correctly |
| 4 | removed four invalid `_api.project.current_layer = ...` assignments | layer commands return real indices and ids instead of `{}` |
| 5 | `_cmd_duplicate_frame` copies cel `offset` and all cel metadata | all 8 frames carry `SkeletorSkeleton` after duplication (was: frame 0 only) |
| 6 | `pack.gd` reads `PIXELORAMA_SRC` / `PIXELORAMA_EXT_DIR` instead of the original author's hardcoded `/home/abido/...` paths, and warns when the GIF shaders are missing rather than silently shipping a build without them | repacks on macOS with shaders included |

### Further Pixelorama 1.2 drift found while verifying the tool layer

| # | Fix | Verification |
|---|---|---|
| 7 | `_cmd_delete_frame` no longer assigns the read-only `_api.project.current_frame` (same bug as #4) | `delete_frame` returns its payload instead of `{}` |
| 8 | `_cmd_set_tile_mode` writes `project.tiles.mode`; `project.tile_mode` was removed in 1.2 | `set_tile_mode` passes |
| 9 | `_cmd_set_symmetry_guide` sets the symmetry points and returns an explicit `warning` rather than raising on the removed `show_x_symmetry` / `show_y_symmetry` | fails loudly, with the migration path recorded in the handler |

The repo's own suite went from **106/111 to 109/111**. The one remaining failure is test data, not a
tool: it asks `switch_palette` for a palette named "Default", which no stock install ships.

### A Skeletor bug we do *not* trigger

`update_frame_data()` dereferences the pose layer before checking it exists:

```gdscript
var d_cel = project.frames[current_frame].cels[project.layers.find(pose_layer)]
...
if p_cel.get_content().get_data() == d_cel.get_content().get_data():
```

With no pose layer, `find(null)` returns `-1`, which indexes the **last** cel; if that is a group
cel, `get_content()` returns an Array and the call raises
`Invalid call. Nonexistent function 'get_data' in base 'Array'`. It fires from Skeletor's own
frame-added signal handler on any rig-less project, so adding a frame to an ordinary drawing logs
the error. It is non-fatal and upstream's. Our adapter never reaches it: `catalogue()` returns
early unless a pose layer resolves.

### Added for the Skeletor tool layer

| Area | Behaviour |
|---|---|
| pose layer flag | assigned through the `pose_layer` setter so `SkeletorPoseLayer` is persisted (§3) |
| in-memory sync | `save_bones()` re-syncs `current_frame_bones` after writing the current frame (§9e) |
| render visibility | `render_frames()` shows the pose layer for the render and restores it (§9f) |
| quick-set pivot | `best_origin()` is offset-aware rather than delegating to `get_best_origin()` (§6d) |
| layer nesting | `_skeletor_add_layer()` toggles the anchor group's `expanded` to choose nest vs. sibling (§5) |
| index reporting | layer indices are resolved after every layer exists, since each insert shifts the rest |

Fixes 1-5 are **not** Skeletor-specific — they repair the bridge's core drawing, layer and export
paths against current Pixelorama. The Skeletor work sits on top of them.

End-to-end check after the fixes: 64x64 canvas -> nested 2-bone rig -> painted sprites -> 8 frames
-> sine ease-in-out tween 0deg->90deg -> pose view -> GIF export, with the arm's bounding box
narrowing monotonically `30 -> 29 -> 29 -> 28 -> 24 -> 19 -> 16 -> 15` px and no compositing
artifacts. See `docs/spike-arm-swing.gif`.
