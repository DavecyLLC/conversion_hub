import 'package:flutter/material.dart';

// Import the tool screens that exist in your app right now.
// If you don't have these yet, comment them out and keep only the ones you do have.
import 'package:conversion_hub/tools/geometry/circle_tool.dart';
import 'package:conversion_hub/tools/math/pythagoras_tool.dart';
import 'package:conversion_hub/tools/geometry/cone_tool.dart';
import 'package:conversion_hub/tools/optics/thin_lens_tool.dart';
import 'package:conversion_hub/tools/optics/fov_tool.dart';

import 'tools_registry.dart';

final List<ToolMeta> allTools = [
  ToolMeta(
    id: 'circle',
    title: 'Circle Geometry',
    subtitle: 'Diameter ↔ Radius ↔ Circumference',
    icon: Icons.circle_outlined,
    builder: () => const CircleTool(),
  ),
  ToolMeta(
    id: 'pythagoras',
    title: 'Right Triangle Solver',
    subtitle: 'a, b, c + angles',
    icon: Icons.square_foot,
    builder: () => const PythagorasToolScreen(),
  ),
  ToolMeta(
    id: 'cone',
    title: 'Cone / Frustum',
    subtitle: 'Slant, volume, areas',
    icon: Icons.change_history,
    builder: () => const ConeToolScreen(),
  ),
  ToolMeta(
    id: 'thin_lens',
    title: 'Thin Lens',
    subtitle: 'f, do, di + magnification',
    icon: Icons.camera_alt_outlined,
    builder: () => const ThinLensTool(),
  ),
  ToolMeta(
    id: 'fov',
    title: 'Field of View (FOV)',
    subtitle: 'sensor + focal length → degrees',
    icon: Icons.crop_free,
    builder: () => const FovTool(),
  ),
];

