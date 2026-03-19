import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthStateRest {
  final String idToken;
  final String refreshToken;
  final String uid;
  final int expiresAtMs;

  const AuthStateRest({
    required this.idToken,
    required this.refreshToken,
    required this.uid,
    required this.expiresAtMs,
  });

  bool get isExpiredSoon =>
      DateTime.now().millisecondsSinceEpoch > (expiresAtMs - 60 * 1000);

  Map<String, dynamic> toJson() => {
    'idToken': idToken,
    'refreshToken': refreshToken,
    'uid': uid,
    'expiresAtMs': expiresAtMs,
  };

  static AuthStateRest? fromJson(Map<String, dynamic> j) {
    try {
      return AuthStateRest(
        idToken: j['idToken'] as String,
        refreshToken: j['refreshToken'] as String,
        uid: j['uid'] as String,
        expiresAtMs: j['expiresAtMs'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

class FirebaseAuthRestClient {
  final String apiKey;
  static const _kPrefKey = 'auth_rest_state';

  FirebaseAuthRestClient({required this.apiKey});

  Future<AuthStateRest?> loadSaved() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kPrefKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return AuthStateRest.fromJson(j);
  }

  Future<void> save(AuthStateRest s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kPrefKey, jsonEncode(s.toJson()));
  }

  /// Sign in anonymously via Identity Toolkit REST
  Future<AuthStateRest> signInAnonymously({
    required String androidPackageName,
    required String androidSha1Cert,
  }) async {
    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey',
    );

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Android-Package': androidPackageName,
        'X-Android-Cert': androidSha1Cert,
      },
      body: jsonEncode({'returnSecureToken': true}),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'Anonymous sign-in failed: ${res.statusCode} ${res.body}',
      );
    }

    final j = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final idToken = j['idToken'] as String;
    final refreshToken = j['refreshToken'] as String;
    final uid = j['localId'] as String;
    final expiresInSec =
        int.tryParse((j['expiresIn'] as String?) ?? '3600') ?? 3600;
    final expiresAtMs =
        DateTime.now().millisecondsSinceEpoch + expiresInSec * 1000;

    final state = AuthStateRest(
      idToken: idToken,
      refreshToken: refreshToken,
      uid: uid,
      expiresAtMs: expiresAtMs,
    );
    await save(state);
    return state;
  }

  /// Refresh token via Secure Token REST
  Future<AuthStateRest> refresh(AuthStateRest current) async {
    final url = Uri.parse(
      'https://securetoken.googleapis.com/v1/token?key=$apiKey',
    );
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'grant_type': 'refresh_token', 'refresh_token': current.refreshToken}
          .entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&'),
    );

    if (res.statusCode != 200) {
      throw Exception('Token refresh failed: ${res.statusCode} ${res.body}');
    }

    final j = (jsonDecode(res.body) as Map).cast<String, dynamic>();
    final idToken = j['id_token'] as String;
    final refreshToken = j['refresh_token'] as String;
    final uid = j['user_id'] as String;
    final expiresInSec =
        int.tryParse((j['expires_in'] as String?) ?? '3600') ?? 3600;
    final expiresAtMs =
        DateTime.now().millisecondsSinceEpoch + expiresInSec * 1000;

    final next = AuthStateRest(
      idToken: idToken,
      refreshToken: refreshToken,
      uid: uid,
      expiresAtMs: expiresAtMs,
    );
    await save(next);
    return next;
  }

  /// Get a valid (fresh) idToken
  Future<AuthStateRest> getValidAuth() async {
    var s = await loadSaved();
    s ??= await signInAnonymously(
      androidPackageName: 'com.tgfm_music_library',
      androidSha1Cert: 'PASTE_YOUR_SHA1_HERE',
    );
    if (s.isExpiredSoon) {
      s = await refresh(s);
    }
    return s;
  }
}
