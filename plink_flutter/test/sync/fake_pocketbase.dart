import 'dart:typed_data';

import 'package:nas_sync/nas_sync.dart';

/// An in-memory stand-in for the NAS's PocketBase `sync_items` table, with
/// the same rules the server enforces: rows are private per user, and
/// (owner, app, kind, item_key) is unique.
class FakePocketBase {
  final Map<String, String> passwords = {
    'alice@test.local': 'pw-alice-12345',
    'bob@test.local': 'pw-bob-12345',
  };
  final Map<String, Map<String, dynamic>> records = {};
  final Map<String, Uint8List> files = {};

  /// Set to make the next request fail like an unreachable server.
  int failNextRequests = 0;

  /// Set to reject tokens, like an expired or removed account.
  bool rejectTokens = false;

  int _counter = 0;

  String _stamp() =>
      '2026-11-14 00:00:00.${(++_counter).toString().padLeft(9, '0')}Z';

  void _maybeFail() {
    if (failNextRequests > 0) {
      failNextRequests--;
      throw Exception('Connection timed out');
    }
  }
}

class FakePbClient extends PbClient {
  FakePbClient(this.server, {super.auth}) : super('http://fake.test/');

  final FakePocketBase server;

  String get _owner {
    server._maybeFail();
    if (auth == null || server.rejectTokens) {
      throw PbException(401, 'The request requires valid authorization.');
    }
    return auth!.userId;
  }

  PbAuth _issue(String email) => auth = PbAuth(
    token: 'token-$email-${server._counter++}',
    userId: email.split('@').first,
    email: email,
  );

  @override
  Future<PbAuth> signIn(String email, String password) async {
    server._maybeFail();
    if (server.passwords[email] != password) {
      throw PbException(400, 'Failed to authenticate.');
    }
    return _issue(email);
  }

  @override
  Future<PbAuth> refresh() async {
    _owner;
    return _issue(auth!.email);
  }

  @override
  Future<List<Map<String, dynamic>>> listSince(
    String app,
    String? since,
  ) async {
    final owner = _owner;
    final rows = server.records.values
        .where(
          (r) =>
              r['owner'] == owner &&
              r['app'] == app &&
              (since == null || (r['updated'] as String).compareTo(since) >= 0),
        )
        .map((r) => {...r})
        .toList();
    rows.sort((a, b) => (a['updated'] as String).compareTo(b['updated']));
    return rows;
  }

  @override
  Future<Map<String, dynamic>?> getRecord(String id) async {
    final owner = _owner;
    final r = server.records[id];
    return r == null || r['owner'] != owner ? null : {...r};
  }

  @override
  Future<Map<String, dynamic>> saveRecord({
    String? id,
    required Map<String, dynamic> fields,
    Uint8List? blob,
    bool clearBlob = false,
  }) async {
    final owner = _owner;
    final existing = id == null ? null : server.records[id];
    if (id != null && (existing == null || existing['owner'] != owner)) {
      throw PbException(404, 'The requested resource wasn\'t found.');
    }
    final clash = server.records.values.any(
      (r) =>
          r['id'] != id &&
          r['owner'] == fields['owner'] &&
          r['app'] == fields['app'] &&
          r['kind'] == fields['kind'] &&
          r['item_key'] == fields['item_key'],
    );
    if (clash) {
      throw PbException(400, 'Failed to create record.', {
        'item_key': {'code': 'validation_not_unique'},
      });
    }
    final recordId = id ?? 'rec${server._counter++}';
    var file = existing?['blob'] as String? ?? '';
    if (blob != null) {
      file = 'item_${server._counter++}.bin';
      server.files['$recordId/$file'] = blob;
    } else if (clearBlob) {
      file = '';
    }
    final row = {
      ...fields,
      'id': recordId,
      'blob': file,
      'updated': server._stamp(),
    };
    server.records[recordId] = row;
    return {...row};
  }

  @override
  Future<String> fileToken() async {
    _owner;
    return 'file-token';
  }

  @override
  Future<Uint8List> download(
    String recordId,
    String filename,
    String fileToken,
  ) async {
    _owner;
    final bytes = server.files['$recordId/$filename'];
    if (bytes == null) throw PbException(404, 'Could not download $filename');
    return bytes;
  }
}
