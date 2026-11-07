/**
 * Skeletor Tools
 *
 * Skeletal animation via the Skeletor Pixelorama extension (Variable-Interactive/Skeletor).
 *
 * Skeletor ships no API of its own and its higher-level features live in its tool UI, so these
 * tools are reimplemented over its manager primitives on the GDScript side — see
 * pixelorama-plugin/skeletor_adapter.gd and docs/skeletor-integration.md. Requires Skeletor to be
 * installed and enabled alongside the pix-MCP bridge; get_skeletor_state reports whether it is.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { sendCommand } from "../bridge/pixelorama_client.js";
import { coerceInt, coerceBool, safeJsonArray } from "../utils/schema_helpers.js";

/** A pivot or translation, accepted as {x, y} or [x, y]. */
const vec2Schema = z.union([
  z.object({ x: z.coerce.number(), y: z.coerce.number() }),
  z.tuple([z.coerce.number(), z.coerce.number()]),
]);

const TRANSITIONS = [
  "linear",
  "sine",
  "quad",
  "cubic",
  "quart",
  "quint",
  "expo",
  "circ",
  "back",
  "elastic",
  "bounce",
  "spring",
] as const;

const EASINGS = ["in", "out", "in_out", "out_in"] as const;

interface BoneRow {
  name?: string;
  parent?: string;
  pivot?: { x: number; y: number };
  rotation_deg?: number;
  layer_index?: number;
  sprite_layer?: string;
  sprite_layer_index?: number;
}

function formatBone(bone: BoneRow): string {
  const parts: string[] = [`  • ${bone.name}`];
  if (bone.parent) parts.push(`parent=${bone.parent}`);
  if (bone.pivot) parts.push(`pivot=(${bone.pivot.x},${bone.pivot.y})`);
  if (typeof bone.rotation_deg === "number") {
    parts.push(`rot=${bone.rotation_deg.toFixed(1)}°`);
  }
  if (typeof bone.layer_index === "number") parts.push(`layer=${bone.layer_index}`);
  if (bone.sprite_layer) {
    parts.push(`sprite='${bone.sprite_layer}'@${bone.sprite_layer_index}`);
  }
  return parts.join("  ");
}

function text(body: string) {
  return { content: [{ type: "text" as const, text: body }] };
}

export function registerSkeletorTools(server: McpServer): void {
  server.tool(
    "get_skeletor_state",
    "Inspect the Skeletor rig: whether Skeletor is installed and compatible, the pose layer, the current view mode (draw/pose), every bone with its pivot and rotation, and which frames are missing a skeleton. Call this first — the other skeletor tools depend on a rig existing.",
    {
      frame: coerceInt(0).optional().describe("Frame to report bones for (defaults to the current frame)"),
    },
    async ({ frame }) => {
      const result = await sendCommand("get_skeletor_state", frame === undefined ? {} : { frame });
      if (!result.success) return text(`❌ ${result.error}`);
      const d = result.data ?? {};

      if (!d.installed) {
        return text(`⚠️ Skeletor is not installed or not enabled.\n${d.reason ?? ""}`);
      }
      if (!d.adapter_ok) {
        return text(`⚠️ Skeletor is installed but incompatible with this bridge.\n${d.reason ?? ""}`);
      }
      if (!d.pose_layer) {
        return text(
          "⚠️ Skeletor is ready but this project has no rig yet (no pose layer). " +
            "Run setup_skeletor_rig to create one."
        );
      }

      const bones: BoneRow[] = d.bones ?? [];
      const lines = [
        `✅ Skeletor ready — mode: ${d.mode}`,
        `Pose layer: '${d.pose_layer}' (index ${d.pose_layer_index})`,
        `Frame ${d.frame} of ${d.frame_count}, ${bones.length} bone(s):`,
        ...bones.map(formatBone),
      ];
      const gaps: number[] = d.frames_without_skeleton ?? [];
      if (gaps.length > 0) {
        lines.push(
          `⚠️ Frames with no skeleton: ${gaps.join(", ")}. ` +
            "Posing or tweening will seed them from the nearest frame that has one."
        );
      }
      return text(lines.join("\n"));
    }
  );

  server.tool(
    "setup_skeletor_rig",
    "Create a Skeletor rig: one group layer per bone in the requested hierarchy, an empty pixel layer inside each bone to draw that body part into, and the Pose Layer that the posed result is rendered to. Bones may be listed in any order as long as every named parent is also in the list (or already exists). Draw each body part into its sprite layer afterwards, then pose with apply_bone_pose.",
    {
      bones: safeJsonArray(
        z.object({
          name: z.string().min(1).describe("Bone name; also becomes the group layer's name, so it must be unique"),
          parent: z.string().optional().describe("Parent bone's name. Omit or leave empty for a root bone."),
          pivot: vec2Schema.optional().describe("Pivot point in canvas coordinates — the joint this bone rotates around"),
          sprite_layer: coerceBool().optional().describe("Create a pixel layer inside the bone to draw into (default true)"),
          sprite_layer_name: z.string().optional().describe("Name for that pixel layer (default '<bone>_Sprite')"),
        }),
        1
      ).describe("Bones to create, e.g. [{name:'Torso',pivot:{x:32,y:40}},{name:'Arm_R',parent:'Torso',pivot:{x:38,y:26}}]"),
      pose_layer_name: z
        .string()
        .optional()
        .describe("Name of the pose layer (default 'Pose Layer'). Must contain 'Pose Layer' — Skeletor identifies it by name."),
    },
    async ({ bones, pose_layer_name }) => {
      const params: Record<string, unknown> = { bones };
      if (pose_layer_name) params.pose_layer_name = pose_layer_name;
      const result = await sendCommand("setup_skeletor_rig", params);
      if (!result.success) return text(`❌ ${result.error}`);
      const d = result.data ?? {};
      const rows: BoneRow[] = d.bones ?? [];
      return text(
        [
          `✅ Rig created with ${rows.length} bone(s) on frame ${d.frame}`,
          `Pose layer: '${d.pose_layer}' (index ${d.pose_layer_index}${d.pose_layer_created ? ", created" : ", reused"})`,
          ...rows.map(formatBone),
          "",
          "Next: draw each body part into its sprite layer, then apply_bone_pose.",
        ].join("\n")
      );
    }
  );

  server.tool(
    "apply_bone_pose",
    "Pose one or more bones on a single frame and render the result into the pose layer. Rotation is in degrees around the bone's pivot and is inherited by child bones. Use this to set the keyframes that generate_skeletor_tween interpolates between.",
    {
      bones: safeJsonArray(
        z.object({
          name: z.string().min(1).describe("Bone name"),
          rotation_deg: z.coerce.number().optional().describe("Rotation around the pivot, in degrees"),
          pivot: vec2Schema.optional().describe("Move the pivot to this canvas coordinate"),
          translate: vec2Schema.optional().describe("Offset the bone from its pivot, in pixels"),
          rotate_origin_deg: z.coerce.number().optional().describe("Base gizmo angle in degrees; rotation_deg is relative to it"),
          transformation_algorithm: coerceInt(0, 2)
            .optional()
            .describe("Rotation algorithm: 0 = cleanEdge, 1 = OmniScale, 2 = nearest-neighbour"),
        }),
        1
      )
        .optional()
        .describe("Bones to pose. For a single bone you may instead pass bone/rotation_deg/pivot at the top level."),
      bone: z.string().optional().describe("Shorthand for posing one bone: its name"),
      rotation_deg: z.coerce.number().optional().describe("Shorthand: rotation for 'bone', in degrees"),
      pivot: vec2Schema.optional().describe("Shorthand: pivot for 'bone'"),
      translate: vec2Schema.optional().describe("Shorthand: translation for 'bone'"),
      frame: coerceInt(0).optional().describe("Frame to pose (defaults to the current frame)"),
      quick_set_pivot: coerceBool()
        .optional()
        .describe("For bones given no pivot, centre it on that bone's artwork (Skeletor's 'quick set bones'). Default false."),
      render: coerceBool().optional().describe("Render the posed frame into the pose layer (default true)"),
    },
    async (args) => {
      const params: Record<string, unknown> = {};
      for (const key of [
        "bones",
        "bone",
        "rotation_deg",
        "pivot",
        "translate",
        "frame",
        "quick_set_pivot",
        "render",
      ] as const) {
        if (args[key] !== undefined) params[key] = args[key];
      }
      const result = await sendCommand("apply_bone_pose", params);
      if (!result.success) return text(`❌ ${result.error}`);
      const d = result.data ?? {};
      const rows: BoneRow[] = d.bones ?? [];
      const lines = [`✅ Posed ${rows.length} bone(s) on frame ${d.frame}`, ...rows.map(formatBone)];
      if (d.rendered?.length) lines.push(`Rendered frame(s): ${d.rendered.join(", ")}`);
      if (d.pose_layer_was_hidden) {
        lines.push(
          "ℹ️ The project is in draw mode, so the render is stored but not shown. " +
            "Call set_skeletor_mode with mode='pose' to see or export it."
        );
      }
      return text(lines.join("\n"));
    }
  );

  server.tool(
    "generate_skeletor_tween",
    "Interpolate bone poses across the frames between two keyframes and render each one. Pose from_frame and to_frame with apply_bone_pose first. Unlike Skeletor's own tween, which is hardcoded to linear/ease-in, any Godot easing curve can be used here.",
    {
      from_frame: coerceInt(0).describe("Start keyframe (already posed)"),
      to_frame: coerceInt(0).describe("End keyframe (already posed). Must be at least 2 frames after from_frame."),
      bones: safeJsonArray(z.string(), 1)
        .optional()
        .describe("Bone names to tween (defaults to every bone present at both keyframes)"),
      transition: z
        .enum(TRANSITIONS)
        .optional()
        .describe("Easing curve shape (default 'linear'). 'sine' with easing 'in_out' gives natural limb motion."),
      easing: z.enum(EASINGS).optional().describe("Which end the curve is applied to (default 'in_out')"),
      render: coerceBool().optional().describe("Render every frame in the range (default true)"),
    },
    async ({ from_frame, to_frame, bones, transition, easing, render }) => {
      const params: Record<string, unknown> = { from_frame, to_frame };
      if (bones !== undefined) params.bones = bones;
      if (transition !== undefined) params.transition = transition;
      if (easing !== undefined) params.easing = easing;
      if (render !== undefined) params.render = render;

      const result = await sendCommand("generate_skeletor_tween", params);
      if (!result.success) return text(`❌ ${result.error}`);
      const d = result.data ?? {};
      const boneNames: string[] = d.bones ?? [];
      const lines = [
        `✅ Tweened ${boneNames.length} bone(s) across frames ${d.from_frame}→${d.to_frame} (${d.transition}/${d.easing})`,
        `Interpolated frames: ${(d.tweened_frames ?? []).join(", ")}`,
      ];

      const timeline: Array<Record<string, number>> = d.rotation_deg_timeline ?? [];
      if (timeline.length > 0) {
        lines.push("", "Rotation (degrees) per frame:");
        lines.push(`  frame  ${boneNames.join("  ")}`);
        for (const row of timeline) {
          const cells = boneNames.map((n) => (row[n] ?? 0).toFixed(1).padStart(8));
          lines.push(`  ${String(row.frame).padStart(5)}${cells.join("")}`);
        }
      }
      if (d.pose_layer_was_hidden) {
        lines.push(
          "",
          "ℹ️ The project is in draw mode, so the renders are stored but not shown. " +
            "Call set_skeletor_mode with mode='pose' before exporting."
        );
      }
      return text(lines.join("\n"));
    }
  );

  server.tool(
    "set_skeletor_mode",
    "Switch between Skeletor's draw view (source artwork visible, posed result hidden) and pose view (posed result visible, source artwork hidden). Skeletor normally does this when you click the pose layer in the UI, which never happens over MCP — so switch to 'pose' before exporting or screenshotting, or the export shows the unposed artwork on top of the posed result.",
    {
      mode: z.enum(["draw", "pose"]).describe("'pose' to show the posed result, 'draw' to show the source artwork"),
    },
    async ({ mode }) => {
      const result = await sendCommand("set_skeletor_mode", { mode });
      if (!result.success) return text(`❌ ${result.error}`);
      const d = result.data ?? {};
      const toggled: string[] = d.root_groups_toggled ?? [];
      return text(
        `✅ Switched to ${d.mode} view — pose layer ${d.pose_layer_visible ? "visible" : "hidden"}` +
          (toggled.length > 0 ? `, root bone group(s) toggled: ${toggled.join(", ")}` : "")
      );
    }
  );
}
