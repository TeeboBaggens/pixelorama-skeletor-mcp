<div align="center">

# 🎨 Pixelorama-MCP

### Let AI draw pixel art directly inside [Pixelorama](https://www.pixelorama.org/).

**For the ones who can imagine it but can't draw it.**

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/abidoo22/Pixelorama-MCP?style=flat&logo=github)](https://github.com/abidoo22/Pixelorama-MCP/stargazers)
[![MCP Server](https://img.shields.io/badge/MCP-Model%20Context%20Protocol-blueviolet)](https://modelcontextprotocol.io/)
[![Pixelorama](https://img.shields.io/badge/Pixelorama-v1.1.10%20%7C%20v1.2%2B-orange)](https://www.pixelorama.org/)
[![Node.js](https://img.shields.io/badge/node-%E2%89%A522.13-brightgreen)](https://nodejs.org/)
[![Tools](https://img.shields.io/badge/MCP%20tools-75%2B%20(111%20total)-blue)](docs/tool-reference.md)
[![Skeletor](https://img.shields.io/badge/Skeletor-skeletal%20animation-9cf)](docs/skeletor-integration.md)

<img src="moonlit_sanctuary_3x.png" alt="Moonlit Sanctuary: a pixel art lakeside pagoda under a full moon, drawn by an AI inside Pixelorama" width="100%">

<sub><i>"Moonlit Sanctuary", painted live inside Pixelorama by an LLM via the Pixelorama-MCP toolset.</i></sub>

</div>

---

**Pixelorama-MCP** is an open-source [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server that seamlessly bridges AI assistants—including **Claude Desktop**, **Cursor**, **Google Antigravity**, **ChatGPT**, **Gemini**, **Qwen**, and custom autonomous agents—directly to **Pixelorama**, the free and open-source pixel art editor built on Godot Engine.

You describe your creative vision in natural language. The AI computes geometry, palettes, shading math, dithering, and layers, then draws them **live onto your Pixelorama canvas**. Everything created is a native Pixelorama project (`.pxo`) with complete undo history, layer hierarchies, and cel animations that you can continue editing by hand.

> **Note:** This is an independent open-source community project. It is not officially affiliated with or endorsed by Orama Interactive.

---

## 📑 Table of Contents

- [🚀 Key Capabilities](#-key-capabilities)
- [🎮 Example Gallery](#-example-gallery)
- [⚡ Quick Start](#-quick-start)
- [💬 Prompt Recipes & Ideas](#-prompt-recipes--ideas)
- [🖼️ Image Importer & Pixelizer](#️-image-importer--pixelizer)
- [🏗️ How It Works](#️-how-it-works)
- [🛠️ Toolset Overview](#️-toolset-overview)
- [🦴 Skeletal Animation with Skeletor](#-skeletal-animation-with-skeletor)
- [🗂️ Documentation](#️-documentation)
- [🔧 Troubleshooting & FAQ](#-troubleshooting--faq)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🚀 Key Capabilities

- 🖌️ **Natural Language to Pixel Art:** Prompt sprites, UI panels, game assets, textures, and landscapes in plain English.
- ⚡ **Ultra-Fast Drawing Throughput:** Features `draw_pixels_fast` accepting flat coordinate/color arrays (`[x,y,col]` or `[x,y,r,g,b,a]`) running at **~0.02 ms/pixel**—over 100× faster than per-pixel roundtrips.
- ⚙️ **Direct GDScript Eval Hook (`eval_gdscript`):** Execute dynamic GDScript in-engine with cross-layer sampling (`api.get_layer_image`), bulk Image / buffer assignment, auto-fallback for `:=` type inference, and pinpoint line-number error reporting.
- 🧱 **Stable Layer Identifiers (`layer_id`):** Layer tools return persistent UUID handles, allowing safe layer targeting by ID, name, or index without index-shift corruption.
- 🌈 **Advanced Shading & Gradients:** Non-destructive radial and linear gradients with Bayer dithering, alpha blending (`blend: true`), elliptical falloff, smoothstep curves, and bloom glow.
- 📐 **Composition & Scene Planning (`generate_scene_plan`):** Generates horizon placement, rule-of-thirds focal points, value silhouettes, depth hierarchies, and layer plans for large scenes.
- 👁️ **Visual Inspection & Magnification:** `capture_canvas_image` supports custom bounding regions, downscaling (< 1.0) to save tokens, and nearest-neighbor magnification (up to 32×) for pixel-level multimodal visual inspection.
- 🦴 **Skeletal Animation (Skeletor):** Build bone hierarchies, pose joints by angle, and tween poses across frames with any Godot easing curve — driving the [Skeletor](https://github.com/Variable-Interactive/Skeletor) extension, which has no API or MCP server of its own.
- 🎞️ **Animation & Cel Cloning:** Create walk cycles, frame tweens, onion skinning, and frame-rate configs with deep-cloning support.
- 📦 **Godot 4 Game Asset Pipeline:** Direct export to Godot 4 `SpriteFrames` (`.tres`), Godot 4 `TileSet`, APNG, GIF, and spritesheets.

---

## 🎮 Example Gallery

Every asset below was created by an AI agent communicating with Pixelorama through this MCP server:

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/examples/leviathan_dawn.png" alt="Celestial leviathan soaring through dawn clouds" width="100%"><br>
      <b>🐋 Leviathan at Dawn</b><br><sub>Celestial leviathan soaring through dawn clouds</sub>
    </td>
    <td align="center" width="50%">
      <img src="docs/examples/museum_gallery_2x.png" alt="Spotlighted museum hall with framed art and a sculpture" width="100%"><br>
      <b>🏛️ Museum Gallery</b><br><sub>Spotlit hall with framed art and a marble bust</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <img src="docs/examples/showcase_cyberpunk_banner.gif" alt="Animated cyberpunk city banner" width="100%"><br>
      <b>🌆 Neo-Metropolis Overlook</b><br><sub>192×64 animated cyberpunk city and cyber-ronin</sub>
    </td>
    <td align="center" width="50%">
      <img src="docs/examples/showcase_astral_banner.gif" alt="Animated floating island with a levitating mana crystal" width="100%"><br>
      <b>🌌 The Astral Drift</b><br><sub>192×64 floating island with a levitating mana crystal</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <img src="docs/examples/Sinister_Wendigo_Walk.png" alt="8-frame wendigo walk cycle spritesheet" width="100%"><br>
      <b>🦌 Sinister Wendigo Walk</b><br><sub>8-frame walk cycle spritesheet</sub>
    </td>
    <td align="center" width="50%">
      <img src="docs/examples/dungeon_tileset_4x.png" alt="Dungeon tileset with stone walls, water, lava, doors and spikes" width="100%"><br>
      <b>🏰 Dungeon Tileset</b><br><sub>Stone walls, water, lava, doors, spikes, and props</sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <img src="docs/examples/ts_labs.png" alt="Sci-fi lab tileset with consoles, containment tubes and server racks" width="100%"><br>
      <b>🔬 Sci-Fi Lab Tileset</b><br><sub>Consoles, containment tubes, server racks, flooring</sub>
    </td>
    <td align="center" width="50%">
      <img src="docs/examples/dialog_box_2x.png" alt="Retro RPG dialogue box with corner ornaments" width="100%"><br>
      <b>💬 Retro Dialog Box</b><br><sub>RPG dialogue frame with ornaments and a prompt cursor</sub>
    </td>
  </tr>
  <tr>
    <td align="center" colspan="2">
      <img src="docs/examples/coin.png" alt="Golden coin with a 3D star and drop shadow" width="160"><br>
      <b>🪙 Golden Coin</b><br><sub>Classic shaded 3D star coin with a drop shadow</sub>
    </td>
  </tr>
</table>

---

## ⚡ Quick Start

Setting up takes under 5 minutes.

### Prerequisites

- [Node.js](https://nodejs.org/) **v22.13 or newer** — Node 18 and 20 are end-of-life
- [Pixelorama](https://www.pixelorama.org/) (**v1.1.10** or **v1.2+**)
- Optional: [Skeletor](https://github.com/Variable-Interactive/Skeletor) for skeletal animation — see [Skeletal Animation with Skeletor](#-skeletal-animation-with-skeletor)
- An MCP Client: [Claude Desktop](https://claude.ai/download), [Cursor](https://cursor.com/), [Antigravity](https://github.com/), or any MCP-compatible environment

### 1. Clone & Build the MCP Server

```bash
git clone https://github.com/abidoo22/Pixelorama-MCP.git
cd Pixelorama-MCP/mcp-server
npm install
npm run build
```

### 2. Install the Bridge Extension in Pixelorama

1. Open Pixelorama and navigate to **Edit → Preferences** (`Ctrl+,`) → **Extensions**.
2. Click **Add Extension** and select `pixelorama-plugin/PixMcpBridge.pck` (or download it from Releases).
3. Ensure the extension is **Enabled**, then **restart Pixelorama**.
4. The bridge will listen locally on `http://127.0.0.1:7373`. You can verify by opening:
   ```bash
   curl http://127.0.0.1:7373/health
   # Returns: {"status":"ok","server":"pix-mcp-bridge","pixelorama_version":"...","api_version":9}
   ```

### 3. Connect Your MCP Client

#### Claude Desktop

Add this entry to your `claude_desktop_config.json`:
- **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Linux:** `~/.config/Claude/claude_desktop_config.json`
- **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "pixelorama": {
      "command": "node",
      "args": [
        "--max-old-space-size=4096",
        "/absolute/path/to/Pixelorama-MCP/mcp-server/dist/index.js"
      ]
    }
  }
}
```

#### Cursor IDE

1. Open Cursor **Settings → Features → MCP Servers**.
2. Click **Add New MCP Server**.
3. Set **Name** to `pixelorama`, **Type** to `command`.
4. Set **Command** to: `node --max-old-space-size=4096 /absolute/path/to/Pixelorama-MCP/mcp-server/dist/index.js`

Now restart your AI client, open Pixelorama, and give it your first drawing prompt!

---

## 💬 Prompt Recipes & Ideas

Try pasting any of these prompts into your connected AI:

| Purpose | Example Prompt |
|---|---|
| **RPG Item Icon** | *"Draw a 64×64 golden dragon amulet with an emerald gemstone core, metallic bevel highlights, and a soft drop shadow."* |
| **Character Sprite** | *"Create a 32×32 pixel art necromancer character with purple robes, glowing cyan eyes, and a magical staff."* |
| **Animation Loop** | *"Make a 4-frame 32×32 idle breathing animation for a slime monster with smooth squash and stretch."* |
| **Landscape / Scene** | *"Paint a 320×180 atmospheric night scene: a pine forest silhouette, distant aurora borealis with radial glow, and a moonlit lake reflection."* |
| **Game Tileset** | *"Create a 16×16 top-down dungeon tileset on separate layers: cobble floor, cracked stone wall, wooden chest, and an iron dungeon door."* |
| **Procedural Scripting** | *"Use eval_gdscript to generate a 64×64 cellular automata cave map with rocky walls and mossy ground."* |

> 💡 **Tip:** Mentioning light sources (*"top-left lighting"*), palettes (*"PICO-8"* or *"Game Boy 4-color"*), and resolution gives sharper, more cohesive art.

---

## 🖼️ Image Importer & Pixelizer

Turn any reference image or AI-generated photo into transparent pixel art:

```bash
node docs/examples/import_universal_asset.js
```

The smart asset importer automatically detects solid or gradient backgrounds, extracts the foreground subject, snaps pixels to grid dimensions, and streams the asset straight into Pixelorama.

---

## 🏗️ How It Works

```
┌─────────────────────────────────────────────────────────┐
│        AI Assistant (Claude / Cursor / Antigravity)      │
└──────────────────────────┬──────────────────────────────┘
                           │  JSON-RPC over stdio (MCP)
                           ▼
┌─────────────────────────────────────────────────────────┐
│             Pixelorama-MCP Server (Node.js)             │
│   • Schema Coercion & Validation (Zod)                  │
│   • Mathematical Color & Geometry Helpers               │
│   • Dynamic GDScript Runtime Wrapper                    │
└──────────────────────────┬──────────────────────────────┘
                           │  HTTP REST (localhost:7373)
                           ▼
┌─────────────────────────────────────────────────────────┐
│        PixMcpBridge Plugin (GDScript / Godot 4)         │
│   • UndoRedo Integration (Full History & Reversible)    │
│   • Engine-Speed Flat Buffer Rasterization (0.02ms/px)  │
│   • ExtensionsApi Integration (Layers, Frames, Cels)    │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│            Pixelorama Pixel Art Editor Canvas           │
└─────────────────────────────────────────────────────────┘
```

All communication occurs locally via `127.0.0.1:7373`. No canvas data is transmitted externally outside your local machine.

---

## 🛠️ Toolset Overview

Pixelorama-MCP exposes over 70 tools organized by domain:

### 1. Canvas & Project Management
- `create_canvas`: Initialize new projects with custom width, height, and fill.
- `list_canvases` / `switch_canvas` / `close_canvas`: Multi-tab project workspace management.
- `crop_to_content`: Trim empty borders without clipping cels or losing coordinate alignment.
- `scale_canvas`: Upscale/downscale projects with nearest-neighbor scaling.
- `fit_viewport`: Center and scale the active viewport onto the canvas.

### 2. High-Performance Drawing
- `draw_pixels_fast`: High-throughput flat array drawer (`[x,y,col]` or `[x,y,r,g,b,a]`) executing at 0.02 ms/px.
- `draw_pixels`: Batch drawing of pixel arrays in a single atomic undoable action.
- `draw_rect`, `draw_ellipse`, `draw_line`, `draw_polygon`, `draw_path`: Primitive rasterizers with explicit `alpha` and `blend` support.
- `fill_area`: Flood fill algorithm with 8-direction adjacency and color tolerance.
- `draw_text`: Render crisp bitmap typography directly onto pixel cels.

### 3. Layer System & Organization
- `add_layer` / `delete_layer`: Create and delete layers, returning persistent `layer_id` handles.
- `get_layers`: Inspect layer hierarchy, blend modes, opacity, and IDs.
- `set_layer_opacity` / `set_layer_blend_mode` / `set_layer_visibility`: Control compositing.
- `duplicate_layer` / `merge_layers` / `reorder_layers`: Non-destructive layer management.

### 4. Shading & Procedural FX
- `apply_gradient`: Linear and radial gradients with Bayer dithering, elliptical shapes, bloom falloff, and alpha preservation.
- `apply_glow`: Neon and magical bloom generation on active layer or dedicated additive glow layer.
- `apply_drop_shadow`: Cast silhouette drop shadows with configurable offsets and opacity.
- `eval_gdscript`: Execute dynamic GDScript code in-engine on canvas images with full engine API access.

### 5. Color, Palettes & Diagnostics
- `get_palette_usage`: Bounded color frequency histogram (`top: N`) with total unique count.
- `color_replace` / `adjust_hsv`: Non-destructive hue shifting, saturation adjustment, and recoloring.
- `clean_isolated_pixels`: Remove stray single-pixel noise.
- `check_seamless_tile`: Validate and auto-stitch repeating tile wrap seams.

### 6. Animation & Frames
- `add_frame`, `duplicate_frame`, `delete_frame`, `switch_frame`: Frame sequencing.
- `copy_cel`, `clear_cel`, `tween_cel`: Cel operations with reversible undo integration.
- `set_fps` / `set_frame_duration`: Playback configuration.

### 7. Export & Game Engine Integration
- `export_image` (PNG), `export_gif`, `export_apng`, `export_aseprite_json`.
- `export_godot_spriteframes`: Ready-to-use Godot 4 `SpriteFrames` resource (`.tres`).
- `export_godot_tileset`: Ready-to-use Godot 4 `TileSet` resource.

### 8. Skeletal Animation (Skeletor)
- `get_skeletor_state`: Report whether Skeletor is installed and compatible, plus the rig's bones, pivots, pose layer and view mode.
- `setup_skeletor_rig`: Build a bone hierarchy with a drawable sprite layer per bone and the pose layer.
- `apply_bone_pose`: Rotate, translate or re-pivot bones on one frame and render the posed result.
- `generate_skeletor_tween`: Interpolate poses between two keyframes using any Godot easing curve.
- `set_skeletor_mode`: Switch between the draw view (source artwork) and the pose view (posed result).

See the full [Tool Reference](docs/tool-reference.md) for argument tables and JSON examples.

---

## 🦴 Skeletal Animation with Skeletor

[Skeletor](https://github.com/Variable-Interactive/Skeletor) adds bone-based animation to Pixelorama:
a bone is a group layer, nesting group layers builds the hierarchy, and each frame's pose is stored
in that frame's cel metadata. It ships no API and no MCP server, so these five tools drive it
directly — both Skeletor and the pix-MCP bridge are Pixelorama extensions loaded into the same
Godot process, which lets the bridge reach Skeletor's manager through the scene tree. **No fork of
Skeletor or of Pixelorama is required.**

<img src="docs/spike-arm-swing.gif" alt="An eight-frame arm swing: a blue torso with an orange arm pivoting at the shoulder from horizontal to vertical with sine ease-in-out" width="256">

### Setup

Skeletor is optional — the other tools work without it. To enable it:

1. Download `Skeletor.pck` from the [Skeletor releases](https://github.com/Variable-Interactive/Skeletor/releases).
2. Drop it into Pixelorama's `extensions/` folder, next to `PixMcpBridge.pck`.
3. Enable it in **Edit → Preferences → Extensions** (or add `Skeletor=true` under `[extensions]` in `config.ini`) and restart Pixelorama.
4. Run `get_skeletor_state` to confirm the bridge can see it.

On macOS the extensions folder is `~/Library/Application Support/pixelorama/extensions`.
`scripts/dev/setup-macos.sh` does all of this for a development checkout.

### Workflow

```
setup_skeletor_rig       bones as nested group layers + a sprite layer each + the Pose Layer
   ↓
draw_rect / draw_pixels  paint each body part into its own sprite layer
   ↓
apply_bone_pose          set the pose on the first and last frame (your keyframes)
   ↓
generate_skeletor_tween  interpolate every frame in between, with easing
   ↓
set_skeletor_mode        switch to the pose view
   ↓
export_gif               export the animation
```

A worked example, posing a two-bone arm across eight frames:

```jsonc
// 1. Bones may be listed in any order, as long as every named parent is in the list.
setup_skeletor_rig {
  "bones": [
    { "name": "Torso", "pivot": { "x": 32, "y": 34 } },
    { "name": "Arm_R", "parent": "Torso", "pivot": { "x": 38, "y": 26 } }
  ]
}
// -> Torso @ layer 4 (sprite Torso_Sprite @ 1), Arm_R @ layer 3 (sprite Arm_R_Sprite @ 2)

// 2. Paint into the sprite layers, then duplicate the frame up to eight.

// 3. Keyframes at both ends.
apply_bone_pose { "bone": "Arm_R", "rotation_deg": 0,  "frame": 0 }
apply_bone_pose { "bone": "Arm_R", "rotation_deg": 90, "frame": 7 }

// 4. Fill in the middle. Skeletor's own tween is hardcoded to linear/ease-in;
//    because this one is reimplemented, every Godot curve is available.
generate_skeletor_tween {
  "from_frame": 0, "to_frame": 7,
  "bones": ["Arm_R"], "transition": "sine", "easing": "in_out"
}
// -> 0.0  4.5  16.9  35.0  55.0  73.1  85.5  90.0 degrees

// 5. Show the posed result rather than the source artwork, then export.
set_skeletor_mode { "mode": "pose" }
```

**Rotation is inherited**: rotating `Torso` carries `Arm_R` and its artwork with it. Pivots are in
canvas coordinates — put each one on the joint the bone turns around (a shoulder, an elbow), not on
the centre of the sprite. Pass `"quick_set_pivot": true` to `apply_bone_pose` to centre any pivot you
have not set on that bone's own artwork, which is Skeletor's "quick set bones".

Architecture, Skeletor's data model and the full reverse-engineering notes are in
[Skeletor Integration](docs/skeletor-integration.md).

---

## 🗂️ Documentation

- 📖 [Getting Started Guide](docs/getting-started.md) — Step-by-step installation and client setup.
- 🛠️ [Tool Reference](docs/tool-reference.md) — Exhaustive documentation of all tools and schemas.
- 🎨 [Agentic Drawing Playbook](AGENTIC_DRAWING_PLAYBOOK.md) — Shading rules, color ramps, geometry recipes, and batching tricks for LLM agents.
- 🦴 [Skeletor Integration](docs/skeletor-integration.md) — Architecture, Skeletor's data model, and the upstream quirks worked around.
- 🔌 [Plugin Setup & Compilation](docs/plugin-setup.md) — Building and packing the `.pck` file with Godot Engine.
- 📂 [Example Scripts](docs/examples/) — Scripts demonstrating asset imports, banners, and tilesets.

---

## 🔧 Troubleshooting & FAQ

### Connection & setup

#### The AI client cannot see the tools
- Ensure you ran `npm run build` inside `mcp-server/`.
- Verify the path in your client configuration is an **absolute path** to `mcp-server/dist/index.js`.
- Fully restart your AI client after editing configuration.

#### `npm install` fails with `ERESOLVE` on eslint
- You are on Node 18 or 20. Both are end-of-life and below eslint 10's floor
  (`^20.19 || ^22.13 || >=24`). Use Node 22.13 or newer.

#### Why are there two TypeScript packages?
TypeScript 7.0 is the new native compiler and **ships no compiler API** — its main export is just
`version.cjs`, with the API behind explicitly `unstable/*` subpaths. `typescript-eslint` imports
that API, so it cannot run against TS 7 at all and fails fast with
`typescript-eslint does not support TS 7.0` ([typescript-eslint#10940] tracks support).

This project therefore uses Microsoft's documented side-by-side arrangement from the
[TypeScript 7.0 announcement]:

```json
"@typescript/native": "npm:typescript@^7.0.2",
"typescript": "npm:@typescript/typescript6@^6.0.2"
```

The first alias supplies TypeScript 7's `tsc`, so `typecheck` and `build` run on 7. The
`typescript` specifier resolves to `@typescript/typescript6`, which re-exports the 6.0 API, so
`typescript-eslint` keeps working. **Both are stable releases — no prerelease is involved**, and
`npm install` resolves without `--legacy-peer-deps`.

Check what you have with `npx tsc --version` (expect 7.x) and `npm ls typescript` (expect
`@typescript/typescript6`). Once typescript-eslint supports TS 7, both entries collapse back to a
plain `"typescript"`.

[typescript-eslint#10940]: https://github.com/typescript-eslint/typescript-eslint/issues/10940
[TypeScript 7.0 announcement]: https://devblogs.microsoft.com/typescript/announcing-typescript-7-0/#running-side-by-side-with-typescript-6.0

#### Pixelorama is open, but commands time out
- Verify that `PixMcpBridge.pck` is enabled under **Edit → Preferences → Extensions**.
- Check that Pixelorama was restarted after enabling the extension.
- Test `curl http://127.0.0.1:7373/health` to confirm the local port is reachable.

#### The extension is installed but never starts
Extensions are **disabled by default**. Dropping a `.pck` into `extensions/` loads it but does not
enable it — `[extensions] <name>=true` must be set in `config.ini`, or the extension ticked in
**Edit → Preferences → Extensions**. The key is the `name` field of `extension.json`, which must
also match the `.pck` filename.

#### The extension vanished after a crash
If Pixelorama is killed rather than quit, stale `.running` and `extensions/Monitoring.ini` files
make the next launch treat the session as a crash and **quarantine every extension** into
`give_in_bug_report/`. Delete both files and relaunch. `scripts/dev/run-pixelorama.sh` does this
automatically.

---

### Drawing & export

#### Drawing reports `pixels_drawn: 0, pixels_clipped: N` — nothing appears
Fixed in this fork; if you see it, the bridge build predates the fix.

Pixelorama 1.2 made cels **sparse**: `cel.image` holds only the used content and is positioned on
the canvas by `cel.offset`, and an empty cel is a **1×1** placeholder rather than a canvas-sized
image. Code that writes straight into `cel.get_image()` using canvas coordinates therefore writes
outside that 1×1 image, and every pixel is silently clipped — which broke the bridge's *entire*
drawing surface against Pixelorama 1.2.x. The bridge now normalises a cel to a full-canvas image at
offset zero before any read or write (`_ensure_full_canvas_cel`).

Writing through the cel's own growing primitives is the alternative, if you are scripting this
yourself via `eval_gdscript`:

```gdscript
var src = Image.create_empty(project.size.x, project.size.y, false, Image.FORMAT_RGBA8)
# ...draw into src in canvas coordinates...
cel.blit_image_to_cel(src)   # grows the cel and sets its offset for you
cel.update_texture()
```

#### Exported images show artwork stamped at the top-left corner
Same sparse-cel root cause, on the read side: the frame compositor blitted every cel at
`Vector2i.ZERO` instead of at `cel.offset`, so each layer's content landed at the canvas origin
rather than where it was drawn. Fixed in this fork.

#### An `eval_gdscript` script reports `N pixels clipped` and writes nothing
The script reached past the image it was given. `eval_gdscript` injects an `image` that the bridge
has already normalised to canvas size, but a script that fetches its own cel —

```gdscript
var img = project.frames[0].cels[0].get_image()   # RAW sparse cel
img.set_pixel(x, y, color)                        # canvas coords land outside it
```

— gets the **raw sparse cel**: only as large as its used content, positioned by `cel.offset`. Writes
in canvas coordinates then fall outside it and are clipped. Use the injected `image`, or
`api.get_layer_image(layer)` which returns a canvas-sized copy.

#### A layer command returns an empty `{}` for a layer that was clearly created
`ProjectAPI.current_layer` is read-only. `add_layer` and `create_layer_group` both assigned to it,
which raised `Invalid assignment of property or key 'current_layer' ... on a base object of type
'RefCounted (ProjectAPI)'` and aborted the command *after* creating the layer but *before*
returning — so the caller saw an empty response for a layer that exists. Fixed in this fork.

#### A new layer got the wrong name, or a group got named instead
`ExtensionsApi.add_new_layer()` renames `project.layers[above_layer + 1]`, which assumes the new
layer lands *above* the anchor. That only holds when it does **not** nest into a group: when it
does, it is inserted *at* `above_layer` and the group shifts up, so the rename lands on the group.
The bridge now adds layers unnamed and renames whichever layer actually appeared.

#### `delete_frame` returns nothing but the frame is gone
Same read-only-property bug as above, on `current_frame`: `ProjectAPI` exposes `current_project`
as its only setter, so `_api.project.current_frame = ...` raised and aborted the command after the
frame had already been removed. Fixed in this fork.

#### `set_tile_mode` or `set_symmetry_guide` fails with no message
Both were written against Pixelorama 1.1's `Project` API and are fixed in this fork:
- **`set_tile_mode`** used `project.tile_mode`, which moved to `project.tiles.mode` in 1.2
  (`Tiles.MODE` = `NONE, BOTH, X_AXIS, Y_AXIS`).
- **`set_symmetry_guide`** used `project.show_x_symmetry` / `show_y_symmetry`, which no longer
  exist. See below for what the axes actually mean.

#### Which symmetry axis is which?
The naming crosses over, which is why this was wrong for so long. An **axis** is named for the
coordinate it mirrors *about*; a **guide** is named for the line's orientation:

| You ask for | It mirrors | Line you see | Internals | Default colour |
|---|---|---|---|---|
| `horizontal` | left ↔ right (flips X) | **vertical** line at `x_pos` | `y_symmetry_axis`, `Global.show_y_symmetry_axis`, `Tools.horizontal_mirror`, `x_symmetry_point` | green `#2ecc40` |
| `vertical` | top ↔ bottom (flips Y) | **horizontal** line at `y_pos` | `x_symmetry_axis`, `Global.show_x_symmetry_axis`, `Tools.vertical_mirror`, `y_symmetry_point` | orange `#ff851b` |

The two guides get distinct colours by default so they can't be confused on screen. Note the
symmetry *points* are in doubled coordinates (`mirror = symmetry_point - pos`), so a line at canvas
position P stores `2P - 1` — matching Pixelorama's own default of `size - 1` for a centred line.

Mirroring applies to **hand-drawing in the app**. The MCP drawing tools write to cel images
directly and are not mirrored.

#### `switch_palette` reports `Palette 'Default' not found`
There is no palette named "Default" — the tool is working, the name is wrong. Call `list_palettes`
for the installed names; a stock install ships "Pixelorama" and "DawnBringer 32". Create your own
with `create_palette` first if you need a known one.

#### A duplicated frame lost its extension data
`duplicate_frame` copied cel images but neither the sparse-cel `offset` nor cel **metadata**.
Extensions keep per-frame state in cel metadata — Skeletor stores each frame's entire skeleton
there — so duplicating a frame silently produced one with no pose data at all. Fixed in this fork.

---

### Skeletor

#### `get_skeletor_state` says Skeletor is not installed
`Skeletor.pck` must be in the same `extensions/` folder as `PixMcpBridge.pck` **and** enabled —
see "The extension is installed but never starts" above. Restart Pixelorama after enabling it.

#### `get_skeletor_state` says Skeletor is installed but incompatible
The bridge reaches Skeletor by duck-typing its manager out of the scene tree, and checks on every
call that the methods and properties it needs are still present. This message means a Skeletor
update moved something; the reported names say what. Everything that touches Skeletor lives in
`pixelorama-plugin/skeletor_adapter.gd`, so that is the one file to update.

#### Posing or tweening appears to do nothing
`generate_pose()` returns silently unless the pose layer is visible, so a render issued while the
project is in the draw view produces no visible change. The bridge shows the pose layer for the
render and restores the previous visibility afterwards, and reports `pose_layer_was_hidden` when it
did. The pixels are in the cel either way — call `set_skeletor_mode` with `"pose"` to see them.

#### An export shows the unposed artwork on top of the posed result
Skeletor swaps between its draw view and pose view in `manage_layer_visibility()`, which only runs
when the **UI** changes the selected layer. Driven over MCP nothing ever selects the pose layer, so
the source sprites stay visible alongside the rendered pose. Call `set_skeletor_mode` with
`"mode": "pose"` before exporting or screenshotting.

#### A pivot set earlier reverted to (0,0)
Skeletor treats its in-memory bone set as the authority for the *current* frame: it renders from
it, and `update_frame_data()` ends by writing it straight back to cel metadata. So a metadata-only
write is reverted by the next catalogue pass. The bridge re-syncs that in-memory set on every
write. If you are scripting Skeletor yourself via `eval_gdscript`, you must do the same.

#### Frames in the middle of an animation have no skeleton
Each frame's skeleton lives in that frame's cel metadata, and frames created by some paths start
without any. The bridge seeds them from the nearest frame that has one before posing or tweening;
`get_skeletor_state` lists them under `frames_without_skeleton`.

#### Renders of *other* frames stopped working too
A failsafe in `generate_pose()` checks whether the **current** frame's in-memory bones are empty
and, if so, renders an empty image to the current frame and returns — even when asked for a
different frame. One skeleton-less current frame therefore suppresses every render and blanks that
frame. The bridge populates the in-memory set before rendering anything.

#### A bone's rotation does not move its artwork
A bone is a **group layer**; only artwork on layers *inside* that group is transformed. If you drew
into a layer outside the bone group, nothing will move. `setup_skeletor_rig` creates a sprite layer
inside each bone for exactly this reason — check `sprite_layer_index` in its response and draw there.

---

### General

#### The macOS menu bar says "godot", not "Pixelorama"
Expected when running Pixelorama from source (`godot --path .../pixelorama`, which the dev scripts
here do): macOS names the menu bar after the running bundle, which is `Godot.app`. The app itself is
Pixelorama and the bridge is unaffected. To see "Pixelorama" there, run an exported `Pixelorama.app`
and install `PixMcpBridge.pck` into its extensions folder instead — that is also how an end user
would run it.

#### Which AI models produce the best art?
- Models with strong spatial reasoning and mathematical capability (such as Claude 3.5 Sonnet, Claude 3.7 Sonnet, GPT-4o, and Gemini 1.5 Pro) produce remarkable shading, dithering, and composition.

---

## 🤝 Contributing

Contributions are warmly welcome! Whether you want to add new procedural drawing tools, improve Godot integration, or submit artwork prompts:

1. Fork the repository and create a feature branch (`git checkout -b feature/awesome-tool`).
2. Make your edits and ensure tests pass (`node test_all_fixes.js`).
3. Submit a Pull Request with a clear description of the enhancement.

---

## 📄 License

Pixelorama-MCP is released under the [MIT License](LICENSE).

---

## 🙏 Credits & Acknowledgments

- [Pixelorama](https://www.pixelorama.org/) — Created by Orama Interactive and the open-source community.
- [Godot Engine](https://godotengine.org/) — The powerhouse game engine behind Pixelorama.
- [Model Context Protocol](https://modelcontextprotocol.io/) — Created by Anthropic.

---

<div align="center">
<sub><b>Search Keywords:</b> Pixelorama MCP, Model Context Protocol, Pixel Art AI, Claude Pixel Art, Cursor MCP Pixel Art, Godot Pixel Art, AI Sprite Generator, Pixel Art LLM, Prompt to Pixel Art, Procedural Pixel Art GDScript.</sub>
</div>
