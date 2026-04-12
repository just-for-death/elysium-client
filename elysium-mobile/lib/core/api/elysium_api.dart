import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../models/track.dart';

/// Complete Dart port of ElysiumApi.ts.
/// Every method maps 1:1 to the REST endpoints on the Elysium server.
class ElysiumApi {
  final String baseUrl;

  ElysiumApi(this.baseUrl);

  String get _lib => '$baseUrl/api/v1/library';
  String get _invidious => '$baseUrl/api/invidious';

  // ── Core fetch helper ─────────────────────────────────────────────────────
  Future<dynamic> _get(String url, {Map<String, String>? headers}) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) {
      throw Exception('API ${res.statusCode}: $url');
    }
    return json.decode(res.body);
  }

  Future<dynamic> _post(String url, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    final res = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: json.encode(body),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) {
      throw Exception('API ${res.statusCode}: $url');
    }
    return json.decode(res.body);
  }

  Future<dynamic> _put(String url, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) {
      throw Exception('API ${res.statusCode}: $url');
    }
    return json.decode(res.body);
  }

  Future<dynamic> _delete(String url) async {
    final res = await http.delete(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) {
      throw Exception('API ${res.statusCode}: $url');
    }
    return json.decode(res.body);
  }

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
      '$baseUrl/api/itunes-proxy/search?term=${Uri.encodeComponent(term)}&entity=song&limit=$limit',
    );
  }

  Future<dynamic> itunesTopSongs(String cc, {int limit = 30}) async {
    return _get('$baseUrl/api/itunes-proxy/rss/$cc/topsongs?limit=$limit');
  }

  // ── Lyrics Proxy ──────────────────────────────────────────────────────────
  Future<dynamic> lyricsSearch(String query) async {
    return _get(
      '$baseUrl/api/lyrics-proxy/netease/search?s=${Uri.encodeComponent(query)}&limit=5',
    );
  }

  Future<dynamic> lyricsGet(String id) async {
    return _get('$baseUrl/api/lyrics-proxy/netease/lyric?id=$id');
  }

  // ── Invidious Proxy ───────────────────────────────────────────────────────
  Future<List<Track>> invidiousSearch(String query, {required String instanceUrl, String type = 'video'}) async {
    if (instanceUrl.isEmpty) return [];
    final data = await _get(
      '$_invidious/search?instanceUrl=${Uri.encodeComponent(instanceUrl)}&q=${Uri.encodeComponent(query)}&type=$type',
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
      '$_invidious/video/$videoId',
      headers: {
        'x-invidious-instance': instanceUrl,
        if (sid != null) 'x-invidious-sid': sid,
      },
    ) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> invidiousLogin(String instanceUrl, String username, String password) async {
    return await _post(
      '$_invidious/login',
      {'instanceUrl': instanceUrl, 'username': username, 'password': password},
    ) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInvidiousPlaylists({required String instanceUrl, required String sid}) async {
    final data = await _get(
      '$_invidious/playlists',
      headers: {
        'x-invidious-instance': instanceUrl,
        'x-invidious-sid': sid,
      },
    );
    return data as List<dynamic>;
  }

  Future<dynamic> syncInvidiousPlaylist(String playlistId, {required String instanceUrl, required String sid}) async {
    return await _post(
      '$_invidious/sync-playlist/$playlistId',
      {},
      headers: {
        'x-invidious-instance': instanceUrl,
        'x-invidious-sid': sid,
      },
    );
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
    await _post('$baseUrl/api/v1/scrobble', {
      'track_metadata': {
        'artist_name': artistName,
        'track_name': trackName,
        if (releaseName != null) 'release_name': releaseName,
      },
    });
  }
}
