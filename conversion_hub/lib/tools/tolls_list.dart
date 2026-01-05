import 'package:flutter/material.dart';
import 'package:conversion_hub/tools/tools_registry.dart';

import 'geometry/circle_tool.dart';
import 'geometry/cylinder_tool.dart';
import 'geometry/cone_tool.dart';
import 'geometry/bolt_circle_tool.dart';

import 'math/pythagoras_tool.dart';
import 'electrical/ohms_tool.dart';
import 'machining/rpm_sfm_tool.dart';

import 'optics/thin_lens_tool.dart';
import 'optics/fov_tool.dart';

final List<ToolMeta> allTools = [
  ToolMeta(
    id: 'circle',
    title: 'Circle Geometry',
    subtitle: 'Diameter ↔ Radius ↔ Circumference',
    icon: Icons.circle_outlined,
    builder: () => const CircleTool(),
  ),
  ToolMeta(
    id: 'cylinder',
    title: 'Cylinder / Tube',
    subtitle: 'Volume, area, mass-ready',
    icon: Icons.view_in_ar,
    builder: () => const CylinderTool(),
  ),
  ToolMeta(
    id: 'cone',
    title: 'Cone / Frustum',
    subtitle: 'Slant, volume, areas',
    icon: Icons.change_history,
    builder: () => const ConeToolScreen(),
  ),
  ToolMeta(
    id: 'bolt_circle',
    title: 'Bolt Circle (PCD)',
    subtitle: 'Hole coordinates + angle step',
    icon: Icons.blur_circular,
    builder: () => const BoltCircleTool(),
  ),
  ToolMeta(
    id: 'pythagoras',
    title: 'Right Triangle Solver',
    subtitle: 'a,b,c + angles',
    icon: Icons.square_foot,
    builder: () => const PythagorasToolScreen(),
  ),
  ToolMeta(
    id: 'ohms',
    title: 'Ohm’s Law',
    subtitle: 'V, I, R, P solve',
    icon: Icons.electric_bolt,
    builder: () => const OhmsTool(),
  ),
  ToolMeta(
    id: 'rpm_sfm',
    title: 'RPM ↔ Surface Speed',
    subtitle: 'SFM / m/min from diameter',
    icon: Icons.speed,
    builder: () => const RpmSfmTool(),
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

