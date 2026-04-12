import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final List<Track> videos;

  const Playlist({required this.id, required this.title, this.videos = const []});

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '—',
        videos: (j['videos'] as List<dynamic>? ?? [])
            .map((v) => Track.fromJson(v as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'videos': videos.map((t) => t.toJson()).toList(),
      };
}

class Artist {
  final String artistId;
  final String name;
  final String? artwork;

  const Artist({required this.artistId, required this.name, this.artwork});

  factory Artist.fromJson(Map<String, dynamic> j) => Artist(
        artistId: j['artistId']?.toString() ?? '',
        name: j['name'] ?? '—',
        artwork: j['artwork'],
      );

  Map<String, dynamic> toJson() => {
        'artistId': artistId,
        'name': name,
        if (artwork != null) 'artwork': artwork,
      };
}

class Album {
  final String id;
  final String title;
  final String artist;
  final String? artwork;
  final int? year;
  final List<Track>? tracks;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artwork,
    this.year,
    this.tracks,
  });

  factory Album.fromJson(Map<String, dynamic> j) => Album(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '—',
        artist: j['artist']?.toString() ?? '—',
        artwork: j['artwork']?.toString(),
        year: j['year'] is int ? j['year'] : int.tryParse(j['year']?.toString() ?? ''),
        tracks: (j['tracks'] as List<dynamic>?)
            ?.map((t) => Track.fromJson(t as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        if (artwork != null) 'artwork': artwork,
        if (year != null) 'year': year,
        if (tracks != null)
          'tracks': tracks!.map((t) => t.toJson()).toList(),
      };
}

class ElysiumSettings {
  final bool ollamaEnabled;
  final String ollamaUrl;
  final String ollamaModel;
  final String lastFmApiKey;
  final String listenBrainzToken;
  final String listenBrainzUsername;
  final String apiSecret; // Global auth secret for protected servers
  final bool highQuality;
  final bool cacheEnabled;
  final String queueMode;
  final String invidiousInstance;
  final String? invidiousSid;
  final String? invidiousUsername;
  final bool videoMode;

  const ElysiumSettings({
    this.ollamaEnabled = false,
    this.ollamaUrl = '',
    this.ollamaModel = 'llama3.2:3b',
    this.lastFmApiKey = '',
    this.listenBrainzToken = '',
    this.listenBrainzUsername = '',
    this.apiSecret = '',
    this.highQuality = false,
    this.cacheEnabled = true,
    this.queueMode = 'off',
    this.invidiousInstance = '',
    this.invidiousSid,
    this.invidiousUsername,
    this.videoMode = false,
  });

  factory ElysiumSettings.fromJson(Map<String, dynamic> j) {
    bool toBool(dynamic v, bool def) {
      if (v == null) return def;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      if (v is int) return v == 1;
      return def;
    }

    return ElysiumSettings(
      ollamaEnabled: toBool(j['ollamaEnabled'], false),
      ollamaUrl: j['ollamaUrl']?.toString() ?? '',
      ollamaModel: j['ollamaModel']?.toString() ?? 'llama3.2:3b',
      lastFmApiKey: j['lastFmApiKey']?.toString() ?? '',
      listenBrainzToken: j['listenBrainzToken']?.toString() ?? '',
      listenBrainzUsername: j['listenBrainzUsername']?.toString() ?? '',
      apiSecret: j['apiSecret']?.toString() ?? '',
      highQuality: toBool(j['highQuality'], false),
      cacheEnabled: toBool(j['cacheEnabled'], true),
      queueMode: j['queueMode']?.toString() ?? 'off',
      invidiousInstance: j['invidiousInstance']?.toString() ?? '',
      invidiousSid: j['invidiousSid']?.toString(),
      invidiousUsername: j['invidiousUsername']?.toString(),
      videoMode: toBool(j['videoMode'], false),
    );
  }

  Map<String, dynamic> toJson() => {
        'ollamaEnabled': ollamaEnabled,
        'ollamaUrl': ollamaUrl,
        'ollamaModel': ollamaModel,
        'lastFmApiKey': lastFmApiKey,
        'listenBrainzToken': listenBrainzToken,
        'listenBrainzUsername': listenBrainzUsername,
        'apiSecret': apiSecret,
        'highQuality': highQuality,
        'cacheEnabled': cacheEnabled,
        'queueMode': queueMode,
        'invidiousInstance': invidiousInstance,
        if (invidiousSid != null) 'invidiousSid': invidiousSid,
        if (invidiousUsername != null) 'invidiousUsername': invidiousUsername,
        'videoMode': videoMode,
      };

  ElysiumSettings copyWith({
    bool? ollamaEnabled,
    String? ollamaUrl,
    String? ollamaModel,
    String? lastFmApiKey,
    String? listenBrainzToken,
    String? listenBrainzUsername,
    String? apiSecret,
    bool? highQuality,
    bool? cacheEnabled,
    String? queueMode,
    String? invidiousInstance,
    String? invidiousSid,
    bool clearInvidiousSid = false,
    String? invidiousUsername,
    bool clearInvidiousUsername = false,
    bool? videoMode,
  }) =>
      ElysiumSettings(
        ollamaEnabled: ollamaEnabled ?? this.ollamaEnabled,
        ollamaUrl: ollamaUrl ?? this.ollamaUrl,
        ollamaModel: ollamaModel ?? this.ollamaModel,
        lastFmApiKey: lastFmApiKey ?? this.lastFmApiKey,
        listenBrainzToken: listenBrainzToken ?? this.listenBrainzToken,
        listenBrainzUsername: listenBrainzUsername ?? this.listenBrainzUsername,
        apiSecret: apiSecret ?? this.apiSecret,
        highQuality: highQuality ?? this.highQuality,
        cacheEnabled: cacheEnabled ?? this.cacheEnabled,
        queueMode: queueMode ?? this.queueMode,
        invidiousInstance: invidiousInstance ?? this.invidiousInstance,
        invidiousSid: clearInvidiousSid ? null : (invidiousSid ?? this.invidiousSid),
        invidiousUsername: clearInvidiousUsername ? null : (invidiousUsername ?? this.invidiousUsername),
        videoMode: videoMode ?? this.videoMode,
      );
}
