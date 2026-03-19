import 'dart:convert';
import 'package:http/http.dart' as http;

class FirestoreRestClient {
  final String projectId;
  FirestoreRestClient({required this.projectId});

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
      };

  String get _songsPath => '$_base/songs';

  Map<String, dynamic> _toFields(Map<String, dynamic> src) {
    final out = <String, dynamic>{};
    for (final e in src.entries) {
      final k = e.key;
      final v = e.value;
      if (v == null) continue;
      if (v is String) out[k] = {'stringValue': v};
      else if (v is int) out[k] = {'integerValue': v.toString()};
      else if (v is bool) out[k] = {'booleanValue': v};
      else out[k] = {'stringValue': v.toString()};
    }
    return out;
  }

  Map<String, dynamic> _fromFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((k, v) {
      final m = (v as Map).cast<String, dynamic>();
      if (m.containsKey('stringValue')) out[k] = m['stringValue'];
      else if (m.containsKey('integerValue')) out[k] = int.tryParse(m['integerValue'].toString()) ?? 0;
      else if (m.containsKey('booleanValue')) out[k] = m['booleanValue'] == true;
    });
    return out;
  }

  Future<void> upsertSong({
    required String docId,
    required Map<String, dynamic> songFields,
  }) async {
    final url = Uri.parse('$_songsPath/$docId');
    final body = jsonEncode({'fields': _toFields(songFields)});
    final res = await http.patch(url, headers: _headers, body: body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Upsert failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteSong({required String docId}) async {
    final url = Uri.parse('$_songsPath/$docId');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Delete failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getChangesSince({required int since}) async {
    final url = Uri.parse('$_base:runQuery');

    final body = {
      'structuredQuery': {
        'from': [
          {'collectionId': 'songs'}
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'updatedAt'},
            'op': 'GREATER_THAN',
            'value': {'integerValue': since.toString()},
          }
        },
        'orderBy': [
          {'field': {'fieldPath': 'updatedAt'}, 'direction': 'ASCENDING'}
        ],
      },
    };

    final res = await http.post(url, headers: _headers, body: jsonEncode(body));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('runQuery failed: ${res.statusCode} ${res.body}');
    }

    final arr = (jsonDecode(res.body) as List).cast<Map>();
    final out = <Map<String, dynamic>>[];

    for (final row in arr) {
      final r = row.cast<String, dynamic>();
      final doc = r['document'];
      if (doc == null) continue;
      final d = (doc as Map).cast<String, dynamic>();
      final name = d['name'] as String;
      final docId = name.split('/').last;
      final fields = (d['fields'] as Map?)?.cast<String, dynamic>() ?? {};
      final m = _fromFields(fields);
      m['id'] = docId;
      out.add(m);
    }
    return out;
  }
}