import 'dart:typed_data';

class AppInfo {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  final String? iconPath;

  AppInfo({
    required this.name,
    required this.packageName,
    this.iconBytes,
    this.iconPath,
  });

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    return AppInfo(
      name: map['name'] ?? '',
      packageName: map['packageName'] ?? '',
      iconBytes: map['icon'] is Uint8List ? map['icon'] : null,
      iconPath: map['iconPath'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          packageName == other.packageName &&
          iconPath == other.iconPath;

  @override
  int get hashCode => name.hashCode ^ packageName.hashCode ^ iconPath.hashCode;
}
