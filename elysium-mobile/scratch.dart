import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/core/utils.dart';

void main() async {
  final res = await http.get(Uri.parse('http://localhost:7771/api/itunes-proxy/rss/us/topsongs?limit=20'));
  final body = json.decode(res.body);
  final entries = body['feed']['entry'] as List;
  for (var e in entries.take(3)) {
    final title = e['title']?['label'] ?? '';
    final link = e['link'];
    final url = extractItunesUrl(link);
    print('Title: $title');
    print('Extracted URL: "$url"');
    print('Is blank? ${url.isEmpty}');
    print('-------');
  }
}
