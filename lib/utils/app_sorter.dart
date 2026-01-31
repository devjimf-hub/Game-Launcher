import 'package:arcade_launcher/models/app_info.dart';

/// Utility class for efficiently sorting app lists.
/// Uses HashMap for O(1) lookups instead of O(n) indexOf() calls.
class AppSorter {
  AppSorter._(); // Private constructor

  /// Sort apps by custom order with O(n log n) complexity instead of O(n²).
  /// Apps not in the order list are placed at the end, sorted alphabetically.
  static void sortByOrder(List<AppInfo> apps, List<String> appOrder) {
    if (appOrder.isEmpty) {
      // No custom order, sort alphabetically
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return;
    }

    // Create index map for O(1) lookups - this is the key optimization
    final indexMap = <String, int>{};
    for (var i = 0; i < appOrder.length; i++) {
      indexMap[appOrder[i]] = i;
    }

    // Use a large number for apps not in the order list
    const notFoundIndex = 999999;

    apps.sort((a, b) {
      final indexA = indexMap[a.packageName] ?? notFoundIndex;
      final indexB = indexMap[b.packageName] ?? notFoundIndex;

      if (indexA == indexB) {
        // Both not in order list or same index - sort alphabetically
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return indexA.compareTo(indexB);
    });
  }

  /// Sort apps alphabetically by name (case-insensitive)
  static void sortAlphabetically(List<AppInfo> apps) {
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Sort apps by last played time (most recent first)
  static void sortByRecent(
    List<AppInfo> apps,
    Map<String, int> lastPlayedMap,
  ) {
    apps.sort((a, b) {
      final timeA = lastPlayedMap[a.packageName] ?? 0;
      final timeB = lastPlayedMap[b.packageName] ?? 0;
      return timeB.compareTo(timeA); // Descending order
    });
  }
}
