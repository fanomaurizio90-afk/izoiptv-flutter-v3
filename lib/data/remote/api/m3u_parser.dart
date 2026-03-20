import '../../../domain/entities/channel.dart';

class M3uParser {
  static List<Channel> parse(String content) {
    final lines   = content.split('\n').map((l) => l.trim()).toList();
    final channels = <Channel>[];
    int id = 1;

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i];
      if (!line.startsWith('#EXTINF:')) continue;

      final url = lines[i + 1];
      if (url.isEmpty || url.startsWith('#')) continue;

      final name     = _extractAttribute(line, 'tvg-name') ?? _extractTitle(line);
      final logoUrl  = _extractAttribute(line, 'tvg-logo');
      final groupStr = _extractAttribute(line, 'group-title') ?? 'All';

      channels.add(Channel(
        id:         id++,
        name:       name,
        streamUrl:  url,
        categoryId: groupStr.hashCode.abs(),
        logoUrl:    logoUrl,
        sortOrder:  id,
      ));
    }
    return channels;
  }

  static String? _extractAttribute(String line, String attr) {
    final pattern = RegExp('$attr="([^"]*)"');
    final match   = pattern.firstMatch(line);
    return match?.group(1);
  }

  static String _extractTitle(String line) {
    final comma = line.lastIndexOf(',');
    if (comma == -1) return 'Unknown';
    return line.substring(comma + 1).trim();
  }
}
