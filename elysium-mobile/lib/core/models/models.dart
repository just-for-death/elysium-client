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

class LinkedDevice {
  final String code;
  final String name;
  final String platform;
  final String pairedAt;
  final String lastSyncAt;

  const LinkedDevice({
    required this.code,
    required this.name,
    required this.platform,
    required this.pairedAt,
    required this.lastSyncAt,
  });

  factory LinkedDevice.fromJson(Map<String, dynamic> j) => LinkedDevice(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        platform: j['platform']?.toString() ?? 'other',
        pairedAt: j['pairedAt']?.toString() ?? '',
        lastSyncAt: j['lastSyncAt']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'platform': platform,
        'pairedAt': pairedAt,
        'lastSyncAt': lastSyncAt,
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
  // Missing settings from server
  final bool sponsorBlock;
  final List<String> sponsorBlockCategories;
  final bool analytics;
  final String? exportFileName;
  final String? exportLastDate;
  final String? gotifyUrl;
  final String? gotifyToken;
  final bool gotifyEnabled;
  final bool syncEnabled;
  final int syncInterval;
  final String? lastSyncAt;
  final List<LinkedDevice> linkedDevices;
  // ListenBrainz additional settings
  final bool listenBrainzEnabled;
  final bool listenBrainzPlayingNow;
  final int listenBrainzScrobblePercent;
  final int listenBrainzScrobbleMaxSeconds;
  // Invidious additional settings
  final String invidiousPlaylistPrivacy;
  final bool invidiousAutoPush;
  final Map<String, String> invidiousPlaylistMappings;

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
    this.sponsorBlock = false,
    this.sponsorBlockCategories = const [],
    this.analytics = false,
    this.exportFileName,
    this.exportLastDate,
    this.gotifyUrl,
    this.gotifyToken,
    this.gotifyEnabled = false,
    this.syncEnabled = false,
    this.syncInterval = 30,
    this.lastSyncAt,
    this.linkedDevices = const [],
    this.listenBrainzEnabled = false,
    this.listenBrainzPlayingNow = false,
    this.listenBrainzScrobblePercent = 50,
    this.listenBrainzScrobbleMaxSeconds = 240,
    this.invidiousPlaylistPrivacy = 'private',
    this.invidiousAutoPush = false,
    this.invidiousPlaylistMappings = const {},
  });

  factory ElysiumSettings.fromJson(Map<String, dynamic> j) {
    bool toBool(dynamic v, bool def) {
      if (v == null) return def;
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      if (v is int) return v == 1;
      return def;
    }

    List<String> toStringList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, String> toStringMap(dynamic v) {
      if (v == null) return {};
      if (v is Map) {
        return v.map((k, val) => MapEntry(k.toString(), val.toString()));
      }
      return {};
    }

    List<LinkedDevice> parseLinkedDevices(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v.map((d) => LinkedDevice.fromJson(d as Map<String, dynamic>)).toList();
      }
      return [];
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
      sponsorBlock: toBool(j['sponsorBlock'], false),
      sponsorBlockCategories: toStringList(j['sponsorBlockCategories']),
      analytics: toBool(j['analytics'], false),
      exportFileName: j['exportFileName']?.toString(),
      exportLastDate: j['exportLastDate']?.toString(),
      gotifyUrl: j['gotifyUrl']?.toString(),
      gotifyToken: j['gotifyToken']?.toString(),
      gotifyEnabled: toBool(j['gotifyEnabled'], false),
      syncEnabled: toBool(j['syncEnabled'], false),
      syncInterval: j['syncInterval'] is int ? j['syncInterval'] : 30,
      lastSyncAt: j['lastSyncAt']?.toString(),
      linkedDevices: parseLinkedDevices(j['linkedDevices']),
      listenBrainzEnabled: toBool(j['listenBrainzEnabled'], false),
      listenBrainzPlayingNow: toBool(j['listenBrainzPlayingNow'], false),
      listenBrainzScrobblePercent: j['listenBrainzScrobblePercent'] is int ? j['listenBrainzScrobblePercent'] : 50,
      listenBrainzScrobbleMaxSeconds: j['listenBrainzScrobbleMaxSeconds'] is int ? j['listenBrainzScrobbleMaxSeconds'] : 240,
      invidiousPlaylistPrivacy: j['invidiousPlaylistPrivacy']?.toString() ?? 'private',
      invidiousAutoPush: toBool(j['invidiousAutoPush'], false),
      invidiousPlaylistMappings: toStringMap(j['invidiousPlaylistMappings']),
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
        'sponsorBlock': sponsorBlock,
        'sponsorBlockCategories': sponsorBlockCategories,
        'analytics': analytics,
        if (exportFileName != null) 'exportFileName': exportFileName,
        if (exportLastDate != null) 'exportLastDate': exportLastDate,
        if (gotifyUrl != null) 'gotifyUrl': gotifyUrl,
        if (gotifyToken != null) 'gotifyToken': gotifyToken,
        'gotifyEnabled': gotifyEnabled,
        'syncEnabled': syncEnabled,
        'syncInterval': syncInterval,
        if (lastSyncAt != null) 'lastSyncAt': lastSyncAt,
        'linkedDevices': linkedDevices.map((d) => d.toJson()).toList(),
        'listenBrainzEnabled': listenBrainzEnabled,
        'listenBrainzPlayingNow': listenBrainzPlayingNow,
        'listenBrainzScrobblePercent': listenBrainzScrobblePercent,
        'listenBrainzScrobbleMaxSeconds': listenBrainzScrobbleMaxSeconds,
        'invidiousPlaylistPrivacy': invidiousPlaylistPrivacy,
        'invidiousAutoPush': invidiousAutoPush,
        'invidiousPlaylistMappings': invidiousPlaylistMappings,
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
    bool? sponsorBlock,
    List<String>? sponsorBlockCategories,
    bool? analytics,
    String? exportFileName,
    String? exportLastDate,
    String? gotifyUrl,
    String? gotifyToken,
    bool? gotifyEnabled,
    bool? syncEnabled,
    int? syncInterval,
    String? lastSyncAt,
    List<LinkedDevice>? linkedDevices,
    bool? listenBrainzEnabled,
    bool? listenBrainzPlayingNow,
    int? listenBrainzScrobblePercent,
    int? listenBrainzScrobbleMaxSeconds,
    String? invidiousPlaylistPrivacy,
    bool? invidiousAutoPush,
    Map<String, String>? invidiousPlaylistMappings,
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
        sponsorBlock: sponsorBlock ?? this.sponsorBlock,
        sponsorBlockCategories: sponsorBlockCategories ?? this.sponsorBlockCategories,
        analytics: analytics ?? this.analytics,
        exportFileName: exportFileName ?? this.exportFileName,
        exportLastDate: exportLastDate ?? this.exportLastDate,
        gotifyUrl: gotifyUrl ?? this.gotifyUrl,
        gotifyToken: gotifyToken ?? this.gotifyToken,
        gotifyEnabled: gotifyEnabled ?? this.gotifyEnabled,
        syncEnabled: syncEnabled ?? this.syncEnabled,
        syncInterval: syncInterval ?? this.syncInterval,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        linkedDevices: linkedDevices ?? this.linkedDevices,
        listenBrainzEnabled: listenBrainzEnabled ?? this.listenBrainzEnabled,
        listenBrainzPlayingNow: listenBrainzPlayingNow ?? this.listenBrainzPlayingNow,
        listenBrainzScrobblePercent: listenBrainzScrobblePercent ?? this.listenBrainzScrobblePercent,
        listenBrainzScrobbleMaxSeconds: listenBrainzScrobbleMaxSeconds ?? this.listenBrainzScrobbleMaxSeconds,
        invidiousPlaylistPrivacy: invidiousPlaylistPrivacy ?? this.invidiousPlaylistPrivacy,
        invidiousAutoPush: invidiousAutoPush ?? this.invidiousAutoPush,
        invidiousPlaylistMappings: invidiousPlaylistMappings ?? this.invidiousPlaylistMappings,
      );
}
