import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/track.dart';

/// Complete Dart port of ElysiumApi.ts.
/// Every method maps 1:1 to the REST endpoints on the Elysium server.
class ElysiumApi {
  final String baseUrl;
  final String apiSecret;

  ElysiumApi(this.baseUrl, {this.apiSecret = ''});

  String get _lib => '$baseUrl/api/v1/library';
  String get _invidious => '$_lib/invidious';

  // ── Core fetch helper ─────────────────────────────────────────────────────
  Future<dynamic> _request(
    String method,
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    final uri = Uri.parse(url);
    final requestHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (apiSecret.isNotEmpty) 'Authorization': 'Bearer $apiSecret',
      ...?headers,
    };

    try {
      final http.Response res;
      final timeout = const Duration(seconds: 15);

      switch (method.toUpperCase()) {
        case 'POST':
          res = await http
              .post(uri, headers: requestHeaders, body: json.encode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          res = await http
              .put(uri, headers: requestHeaders, body: json.encode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          res = await http
              .delete(uri, headers: requestHeaders)
              .timeout(timeout);
          break;
        default:
          res = await http
              .get(uri, headers: requestHeaders)
              .timeout(timeout);
      }

      final dynamic data = _safeDecode(res.body);

      if (res.statusCode >= 400) {
        String message = 'Server Error (${res.statusCode})';
        if (data is Map && data.containsKey('error')) {
          message = data['error'].toString();
          if (data.containsKey('detail')) {
            message += ': ${data['detail']}';
          }
        }
        throw Exception(message);
      }

      return data;
    } catch (e) {
      if (e is http.ClientException || e is Exception) rethrow;
      throw Exception('Network Error: $e');
    }
  }

  dynamic _safeDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return json.decode(body);
    } catch (_) {
      return body; // Return raw body if not JSON
    }
  }

  Future<dynamic> _get(String url, {Map<String, String>? headers}) =>
      _request('GET', url, headers: headers);

  Future<dynamic> _post(String url, Map<String, dynamic> body,
          {Map<String, String>? headers}) =>
      _request('POST', url, body: body, headers: headers);

  Future<dynamic> _put(String url, Map<String, dynamic> body) =>
      _request('PUT', url, body: body);

  Future<dynamic> _delete(String url) => _request('DELETE', url);

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<ElysiumSettings> getSettings() async {
    final data = await _get('$_lib/settings');
    return ElysiumSettings.fromJson(data as Map<String, dynamic>);
  }

  Future<ElysiumSettings> updateSettings(Map<String, dynamic> data) async {
    final res = await _put('$_lib/settings', data);
    return ElysiumSettings.fromJson(res as Map<String, dynamic>);
  }

  // ── History ───────────────────────────────────────────────────────────────
  Future<List<Track>> getHistory() async {
    final data = await _get('$_lib/history');
    return (data as List<dynamic>)
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addHistory(Track track) async {
    await _post('$_lib/history', track.toJson());
  }

  Future<void> deleteHistoryItem(String id) async {
    await _delete('$_lib/history/$id');
  }

  Future<void> clearHistory() async {
    await _delete('$_lib/history');
  }

  // ── Favorites ─────────────────────────────────────────────────────────────
  Future<List<Track>> getFavorites() async {
    final data = await _get('$_lib/favorites');
    return (data as List<dynamic>)
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addFavorite(Track track) async {
    await _post('$_lib/favorites', track.toJson());
  }

  Future<void> deleteFavorite(String id) async {
    await _delete('$_lib/favorites/$id');
  }

  // ── Playlists ─────────────────────────────────────────────────────────────
  Future<List<Playlist>> getPlaylists() async {
    final data = await _get('$_lib/playlists');
    return (data as List<dynamic>)
        .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Playlist> getPlaylist(String id) async {
    final data = await _get('$_lib/playlists/$id');
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<Playlist> createPlaylist(String title) async {
    final data = await _post('$_lib/playlists', {'title': title});
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePlaylist(String id) async {
    await _delete('$_lib/playlists/$id');
  }

  // ── Artists ───────────────────────────────────────────────────────────────
  Future<List<Artist>> getArtists() async {
    final data = await _get('$_lib/artists');
    return (data as List<dynamic>)
        .map((e) => Artist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Albums ────────────────────────────────────────────────────────────────
  Future<List<Album>> getAlbums() async {
    final data = await _get('$_lib/albums');
    return (data as List<dynamic>)
        .map((e) => Album.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── iTunes Proxy ──────────────────────────────────────────────────────────
  Future<dynamic> itunesSearch(String term, {int limit = 30}) async {
    return _get(
      '$_lib/itunes/search?term=${Uri.encodeComponent(term)}&entity=song&limit=$limit',
    );
  }

  Future<dynamic> itunesTopSongs(String cc, {int limit = 30}) async {
    return _get('$_lib/itunes/rss/$cc/topsongs?limit=$limit');
  }

  // ── Lyrics Proxy ──────────────────────────────────────────────────────────
  Future<dynamic> lyricsSearch(String query) async {
    return _get(
      '$_lib/netease/search?s=${Uri.encodeComponent(query)}&limit=5',
    );
  }

  Future<dynamic> lyricsGet(String id) async {
    return _get('$_lib/netease/lyric?id=$id');
  }

  // ── Invidious Proxy ───────────────────────────────────────────────────────
  Future<List<Track>> invidiousSearch(String query, {required String instanceUrl, String type = 'video'}) async {
    if (instanceUrl.isEmpty) return [];
    final data = await _get(
      '$_lib/invidious/search?instanceUrl=${Uri.encodeComponent(instanceUrl)}&q=${Uri.encodeComponent(query)}&type=$type',
    );
    if (data is! List) return [];
    return data.map((v) => Track(
      id: v['videoId'] ?? '',
      videoId: v['videoId'],
      title: v['title'] ?? '',
      artist: v['author'] ?? '',
      artwork: v['videoThumbnails']?[0]?['url'],
      duration: v['lengthSeconds'],
    )).toList();
  }

  Future<Map<String, dynamic>> getVideoDetails(String videoId, {required String instanceUrl, String? sid}) async {
    return await _get(
      '$_lib/invidious/video/$videoId',
      headers: {
        'x-invidious-instance': instanceUrl,
        if (sid != null) 'x-invidious-sid': sid,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> invidiousLogin(String instanceUrl, String username, String password) async {
    return await _post(
      '$_lib/invidious/login',
      {'instanceUrl': instanceUrl, 'username': username, 'password': password},
    ) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInvidiousPlaylists({required String instanceUrl, String? sid}) async {
    final data = await _get(
      '$_lib/invidious/playlists',
      headers: {
        'x-invidious-instance': instanceUrl,
        if (sid != null) 'x-invidious-sid': sid,
      },
    );
    // The server now returns a direct list or handles the wrapping
    return data as List<dynamic>;
  }

  Future<dynamic> syncInvidiousPlaylist(String playlistId, {required String instanceUrl, String? sid}) async {
    return await _post(
      '$_invidious/sync-playlist/$playlistId',
      {},
      headers: {
        'x-invidious-instance': instanceUrl,
        if (sid != null) 'x-invidious-sid': sid,
      },
    );
  }

  Future<Map<String, dynamic>> validateListenBrainzToken(String token) async {
    return await _get(
      '$_lib/listenbrainz/validate?token=${Uri.encodeComponent(token)}',
    ) as Map<String, dynamic>;
  }

  Future<void> bulkScrobble(List<Track> tracks) async {
    await _post(
      '$_lib/scrobble',
      {
        'listen_type': 'import',
        'tracks': tracks.map((t) => {
          'artist_name': t.artist,
          'track_name': t.title,
          if (t.album != null) 'release_name': t.album,
        }).toList(),
      },
    );
  }

  Future<List<dynamic>> getListenBrainzPlaylists() async {
    final data = await _get('$_lib/listenbrainz/playlists');
    return data as List<dynamic>;
  }

  Future<Map<String, dynamic>> syncPlaylistToListenBrainz(String localId) async {
    return await _post(
      '$_lib/listenbrainz/sync-playlist/$localId',
      {},
    ) as Map<String, dynamic>;
  }

  Future<Playlist> getListenBrainzPlaylistDetail(String mbid) async {
    final data = await _get('$_lib/listenbrainz/playlist/$mbid');
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> importListenBrainzPlaylist(String mbid) async {
    return await _post(
      '$_lib/listenbrainz/import-playlist/$mbid',
      {},
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateLastFmKey(String apiKey) async {
    return await _get(
      '$_lib/lastfm/validate?apiKey=${Uri.encodeComponent(apiKey)}',
    ) as Map<String, dynamic>;
  }

  Future<Playlist> getInvidiousPlaylistDetail(String playlistId, {required String instanceUrl, String? sid}) async {
    final data = await _get(
      '$_invidious/playlists/$playlistId',
      headers: {
        'x-invidious-instance': instanceUrl,
        if (sid != null) 'x-invidious-sid': sid,
      },
    );
    return Playlist.fromJson(data as Map<String, dynamic>);
  }

  // ── AI Queue ──────────────────────────────────────────────────────────────
  Future<Track?> generateAIQueue(Track current) async {
    try {
      final res = await _post('$_lib/recommendations/queue', {
        'currentSong': current.toJson(),
      });
      final trackData = res['track'] as Map<String, dynamic>?;
      if (trackData == null) return null;
      return Track.fromJson(trackData);
    } catch (_) {
      return null;
    }
  }

  // ── Scrobble ──────────────────────────────────────────────────────────────
  Future<void> scrobble({
    required String artistName,
    required String trackName,
    String? releaseName,
  }) async {
    await _post('$_lib/scrobble', {
      'track_metadata': {
        'artist_name': artistName,
        'track_name': trackName,
        if (releaseName != null) 'release_name': releaseName,
      },
    });
  }
}
