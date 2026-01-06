import 'package:flutter/material.dart';
import 'package:conversion_hub/state/models.dart';

class AppState extends ChangeNotifier {
  AppSettings settings;
  final Set<String> _favorites;
  final List<HistoryItem> recents;

  AppState({
    required this.settings,
    Set<String>? favorites,
    List<HistoryItem>? recents,
  })  : _favorites = favorites ?? <String>{},
        recents = recents ?? <HistoryItem>[];

  void updateSettings(AppSettings next) {
    settings = next;
    notifyListeners();
  }

  bool isFavorite(String toolId) => _favorites.contains(toolId);

  void toggleFavorite(String toolId) {
    if (_favorites.contains(toolId)) {
      _favorites.remove(toolId);
    } else {
      _favorites.add(toolId);
    }
    notifyListeners();
  }

  void addRecent(HistoryItem item) {
    recents.removeWhere((r) => r.toolId == item.toolId);
    recents.insert(0, item);
    if (recents.length > 50) recents.removeRange(50, recents.length);
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}
