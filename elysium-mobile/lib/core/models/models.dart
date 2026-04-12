import 'track.dart';

class Playlist {
  final String id;
  final String title;
  final List<Track> videos;

  const Playlist({required this.id, required this.title, this.videos = const []});

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? '—',
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
        title: j['title'] ?? '—',
        artist: j['artist'] ?? '—',
        artwork: j['artwork'],
        year: j['year'] as int?,
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
  final String listenBrainzToken;
  final String listenBrainzUsername;
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
    this.ollamaModel = '',
    this.listenBrainzToken = '',
    this.listenBrainzUsername = '',
    this.highQuality = false,
    this.cacheEnabled = true,
    this.queueMode = 'normal',
    this.invidiousInstance = '',
    this.invidiousSid,
    this.invidiousUsername,
    this.videoMode = false,
  });

  factory ElysiumSettings.fromJson(Map<String, dynamic> j) => ElysiumSettings(
        ollamaEnabled: j['ollamaEnabled'] as bool? ?? false,
        ollamaUrl: j['ollamaUrl'] as String? ?? '',
        ollamaModel: j['ollamaModel'] as String? ?? '',
        listenBrainzToken: j['listenBrainzToken'] as String? ?? '',
        listenBrainzUsername: j['listenBrainzUsername'] as String? ?? '',
        highQuality: j['highQuality'] as bool? ?? false,
        cacheEnabled: j['cacheEnabled'] as bool? ?? true,
        queueMode: j['queueMode'] as String? ?? 'normal',
        invidiousInstance: j['invidiousInstance'] as String? ?? '',
        invidiousSid: j['invidiousSid'] as String?,
        invidiousUsername: j['invidiousUsername'] as String?,
        videoMode: j['videoMode'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'ollamaEnabled': ollamaEnabled,
        'ollamaUrl': ollamaUrl,
        'ollamaModel': ollamaModel,
        'listenBrainzToken': listenBrainzToken,
        'listenBrainzUsername': listenBrainzUsername,
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
    String? listenBrainzToken,
    String? listenBrainzUsername,
    bool? highQuality,
    bool? cacheEnabled,
    String? queueMode,
    String? invidiousInstance,
    String? invidiousUsername,
    bool? videoMode,
  }) =>
      ElysiumSettings(
        ollamaEnabled: ollamaEnabled ?? this.ollamaEnabled,
        ollamaUrl: ollamaUrl ?? this.ollamaUrl,
        ollamaModel: ollamaModel ?? this.ollamaModel,
        listenBrainzToken: listenBrainzToken ?? this.listenBrainzToken,
        listenBrainzUsername: listenBrainzUsername ?? this.listenBrainzUsername,
        highQuality: highQuality ?? this.highQuality,
        cacheEnabled: cacheEnabled ?? this.cacheEnabled,
        queueMode: queueMode ?? this.queueMode,
        invidiousInstance: invidiousInstance ?? this.invidiousInstance,
        invidiousSid: invidiousSid ?? this.invidiousSid,
        invidiousUsername: invidiousUsername ?? this.invidiousUsername,
        videoMode: videoMode ?? this.videoMode,
      );
}
