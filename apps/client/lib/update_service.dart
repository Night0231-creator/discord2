/// Version metadata uses authenticated GitHub pages, never arbitrary binaries.
/// It never downloads, executes, or silently installs a remote file.
abstract class AppUpdateInfo {
  String get version;
  int get build;
  String get notes;
  Uri get downloadUrl;
  bool isNewerThan(int installedBuild) => build > installedBuild;
}

/// Android beta update metadata. All links are checked before being opened.
class AndroidUpdate extends AppUpdateInfo {
  const AndroidUpdate({required this.version,required this.build,required this.notes,required this.downloadUrl});

  final String version;
  final int build;
  final String notes;
  final Uri downloadUrl;

  factory AndroidUpdate.fromJson(Map<String,dynamic> json) {
    final build=json['build'];
    final version=json['version'];
    final notes=json['notes'];
    final source=json['download_url'];
    final rawUri=source is String ? Uri.tryParse(source) : null;

    if(json['schema']!=1 || json['platform']!='android' ||
       json['channel']!='beta' || build is! int || build<1 ||
       version is! String || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
       notes is! String || notes.length>1500 ||
       rawUri==null || rawUri.scheme!='https' ||
       rawUri.host!='github.com' || rawUri.userInfo.isNotEmpty ||
       rawUri.hasQuery || rawUri.hasFragment ||
       !RegExp(r'^/Night0231-creator/discord2/actions/runs/\d+$').hasMatch(rawUri.path)) {
      throw const FormatException('Metadados de atualização inválidos');
    }
    return AndroidUpdate(version:version,build:build,notes:notes,downloadUrl:rawUri);
  }

  bool isNewerThan(int installedBuild) => build>installedBuild;
}


/// Beta Windows updates open the official GitHub run or private Release page.
/// This is a manual installer flow; no executable is downloaded in-app.
class WindowsUpdate extends AppUpdateInfo {
  WindowsUpdate({
    required this.version,
    required this.build,
    required this.notes,
    required this.downloadUrl,
  });

  @override
  final String version;
  @override
  final int build;
  @override
  final String notes;
  @override
  final Uri downloadUrl;

  factory WindowsUpdate.fromJson(Map<String,dynamic> json) {
    final raw=json['download_url'];
    final parsed=raw is String ? Uri.tryParse(raw) : null;
    final version=json['version'];
    final notes=json['notes'];
    final build=json['build'];
    final path=parsed?.path??'';
    final allowedPath=RegExp(
      r'^/Night0231-creator/discord2/(?:actions/runs/[0-9]+|releases/tag/v[0-9]+\.[0-9]+\.[0-9]+-beta)$'
    ).hasMatch(path);
    if(json['schema']!=1 || json['platform']!='windows' ||
      json['channel']!='beta' || json['installation']!='manual' ||
      version is! String || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version) ||
      build is! int || build<1 ||
      notes is! String || notes.length>1500 ||
      parsed==null || parsed.scheme!='https' ||
      parsed.host!='github.com' || parsed.userInfo.isNotEmpty ||
      parsed.hasQuery || parsed.hasFragment || parsed.hasPort ||
      !allowedPath) {
      throw const FormatException('Metadados Windows inválidos');
    }
    return WindowsUpdate(version:version,build:build,notes:notes,downloadUrl:parsed);
  }
}
