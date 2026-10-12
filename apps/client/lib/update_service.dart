/// Android beta update metadata. All links are checked before being opened.
class AndroidUpdate {
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
