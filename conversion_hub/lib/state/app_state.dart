import 'package:flutter/material.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  AppSettings settings;

  /// Recent tool usage (for "Recents" tab / sorting)
  final List<HistoryItem> recents;

  /// Favorites tool IDs
  final Set<String> favorites;

  AppState({
    required this.settings,
    List<HistoryItem>? recents,
    Set<String>? favorites,
  })  : recents = recents ?? <HistoryItem>[],
        favorites = favorites ?? <String>{};

  // -----------------------------
  // Settings updates
  // -----------------------------
  void updateSettings(AppSettings next) {
    settings = next;
    notifyListeners();
  }

  void setDecimals(int decimals) {
    settings = settings.copyWith(decimals: decimals);
    notifyListeners();
  }

  void setDefaultLengthUnit(String unit) {
    settings = settings.copyWith(defaultLengthUnit: unit);
    notifyListeners();
  }

  void setHaptics(bool enabled) {
    settings = settings.copyWith(haptics: enabled);
    notifyListeners();
  }

  void setScientific(bool enabled) {
    settings = settings.copyWith(scientific: enabled);
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    settings = settings.copyWith(themeMode: mode);
    notifyListeners();
  }

  // -----------------------------
  // Recents
  // -----------------------------
  void addRecent(HistoryItem item) {
    recents.insert(0, item);
    if (recents.length > 50) {
      recents.removeRange(50, recents.length);
    }
    notifyListeners();
  }

  void clearRecents() {
    recents.clear();
    notifyListeners();
  }

  // -----------------------------
  // Favorites
  // -----------------------------
  bool isFavorite(String toolId) => favorites.contains(toolId);

  void toggleFavorite(String toolId) {
    if (favorites.contains(toolId)) {
      favorites.remove(toolId);
    } else {
      favorites.add(toolId);
    }
    notifyListeners();
  }

  void clearFavorites() {
    favorites.clear();
    notifyListeners();
  }
}

/// Provides AppState + rebuilds dependents when AppState notifies.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found above in the widget tree');
    return scope!.notifier!;
  }
}
