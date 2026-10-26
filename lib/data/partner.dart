/// The conversation partner: everyday scenes where the app speaks a line
/// aloud, then waits — patiently — for the user's answer. Works offline;
/// the partner does not need to understand the answer, because the point is
/// speaking fluently to someone, not the content.
library;

import 'partner_scenes.dart';

class Turn {
  final String partner; // what the partner says
  final String hint; // idea for the user's answer
  const Turn(this.partner, this.hint);
}

class Scene {
  final String id;
  final String title;
  final int level; // 1 easy .. 3 hard
  final String role; // who the partner is
  final List<Turn> turns;
  const Scene(this.id, this.title, this.level, this.role, this.turns);

  String audio(int turn) => 'partner/$id-$turn.mp3';
}

Scene sceneById(String id) => partnerScenes.firstWhere(
  (s) => s.id == id,
  orElse: () => partnerScenes.first,
);

/// Scenes in path order: easy ones first, then harder.
final List<Scene> scenesByLevel = [...partnerScenes]
  ..sort((a, b) => a.level.compareTo(b.level));

/// Silence after the user's last phrase that ends their turn. Long on
/// purpose: people who stutter often need time, and a partner that jumps in
/// early adds the very pressure we want to remove.
const turnEndSec = 2.8;
