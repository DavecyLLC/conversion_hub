import 'package:flutter/material.dart';

import 'package:conversion_hub/tools/geometry/circle_tool.dart';
import 'package:conversion_hub/tools/math/pythagoras_tool.dart';
import 'package:conversion_hub/tools/geometry/cone_tool.dart';
import 'package:conversion_hub/tools/optics/thin_lens_tool.dart';
import 'package:conversion_hub/tools/optics/fov_tool.dart';

import 'package:conversion_hub/tools/mech/gear_tool.dart';
import 'package:conversion_hub/tools/mech/stress_strain_tool.dart';
import 'package:conversion_hub/tools/mech/bending_torsion_tool.dart';
import 'package:conversion_hub/tools/fea/axial_bar_fea_tool.dart';

typedef ToolBuilder = Widget Function();

class ToolDef {
  final String id;
  final String title;
  final IconData icon;
  final ToolBuilder builder;
  final List<String> keywords;

  const ToolDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.builder,
    required this.keywords,
  });
}

final List<ToolDef> allTools = [
  ToolDef(
    id: 'circle',
    title: 'Circle Geometry',
    icon: Icons.circle_outlined,
    builder: () => const CircleTool(),
    keywords: ['circle', 'diameter', 'radius', 'circumference'],
  ),
  ToolDef(
    id: 'pythagoras',
    title: 'Right Triangle (Pythagoras)',
    icon: Icons.change_history,
    builder: () => const PythagorasToolScreen(),
    keywords: ['triangle', 'pythagoras', 'hypotenuse', 'angle'],
  ),
  ToolDef(
    id: 'cone',
    title: 'Cone / Frustum',
    icon: Icons.construction_outlined,
    builder: () => const ConeToolScreen(),
    keywords: ['cone', 'frustum', 'slant', 'volume', 'area'],
  ),
  ToolDef(
    id: 'thin_lens',
    title: 'Thin Lens',
    icon: Icons.visibility_outlined,
    builder: () => const ThinLensTool(),
    keywords: ['optics', 'lens', 'focal', 'magnification'],
  ),
  ToolDef(
    id: 'fov',
    title: 'Field of View (FOV)',
    icon: Icons.photo_camera_outlined,
    builder: () => const FovTool(),
    keywords: ['fov', 'camera', 'sensor', 'optics'],
  ),

  // ✅ NEW (Mechanical)
  ToolDef(
    id: 'gears',
    title: 'Gears: Driver / Driven',
    icon: Icons.settings_suggest_outlined,
    builder: () => const GearToolScreen(),
    keywords: ['gear', 'ratio', 'rpm', 'torque', 'module', 'dp', 'center distance'],
  ),
  ToolDef(
    id: 'stress_strain',
    title: 'Stress / Strain',
    icon: Icons.straighten,
    builder: () => const StressStrainToolScreen(),
    keywords: ['stress', 'strain', 'youngs modulus', 'sigma', 'epsilon'],
  ),
  ToolDef(
    id: 'bending_torsion',
    title: 'Bending & Torsion',
    icon: Icons.architecture_outlined,
    builder: () => const BendingTorsionToolScreen(),
    keywords: ['beam', 'bending', 'torsion', 'deflection', 'twist'],
  ),

  // ✅ NEW (FEA)
  ToolDef(
    id: 'fea_axial',
    title: 'FEA Lite: Axial Bar (1D)',
    icon: Icons.grid_on_outlined,
    builder: () => const AxialBarFeaToolScreen(),
    keywords: ['fea', 'finite element', 'axial', 'bar', 'stiffness'],
  ),
];
