import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/elysium_api.dart';
import '../models/models.dart';
import '../models/track.dart';

// ── Preferences keys ────────────────────────────────────────────────────────
const _kServerIp = 'server_ip';
const _kDefaultServer = 'http://localhost:7771';

// ── SharedPreferences provider ───────────────────────────────────────────────
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

// ── Server IP provider ────────────────────────────────────────────────────────
final serverIpProvider =
    StateNotifierProvider<ServerIpNotifier, String>((ref) {
  return ServerIpNotifier(ref);
});

class ServerIpNotifier extends StateNotifier<String> {
  ServerIpNotifier(Ref ref) : super(_kDefaultServer) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kServerIp) ?? _kDefaultServer;
  }

  Future<void> update(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerIp, url);
    state = url;
  }
}

// ── Settings provider ────────────────────────────────────────────────────────
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, ElysiumSettings?>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<ElysiumSettings?> {
  final Ref _ref;
  SettingsNotifier(this._ref) : super(null) {
    _init();
  }

  Future<void> _init() async {
    final serverIp = _ref.watch(serverIpProvider);
    if (serverIp.isEmpty) return;
    try {
      final s = await ElysiumApi(serverIp).getSettings();
      state = s;
    } catch (_) {}
  }

  Future<void> update(Map<String, dynamic> json) async {
    final serverIp = _ref.read(serverIpProvider);
    final api = ElysiumApi(serverIp, apiSecret: state?.apiSecret ?? '');
    try {
      final updated = await api.updateSettings(json);
      state = updated;
    } catch (_) {
      rethrow;
    }
  }

  void refresh() => _init();
}

// ── Player state ──────────────────────────────────────────────────────────────
enum ElysiumRepeatMode { off, all, one }

class PlayerState {
  final List<Track> queue;
  final int currentIndex;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool shuffled;
  final ElysiumRepeatMode repeatMode;
  final List<Track> favorites;
  final bool videoMode;

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffled = false,
    this.repeatMode = ElysiumRepeatMode.off,
    this.favorites = const [],
    this.videoMode = false,
  });

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length
          ? queue[currentIndex]
          : null;

  bool isFavorite(String id) =>
      favorites.any((f) => (f.videoId ?? f.id) == id);

  PlayerState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? shuffled,
    ElysiumRepeatMode? repeatMode,
    List<Track>? favorites,
    bool? videoMode,
  }) =>
      PlayerState(
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        shuffled: shuffled ?? this.shuffled,
        repeatMode: repeatMode ?? this.repeatMode,
        favorites: favorites ?? this.favorites,
        videoMode: videoMode ?? this.videoMode,
      );
}

// ── Player Notifier ───────────────────────────────────────────────────────────
final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(ref);
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  late final Player _player;
  final Ref _ref;
  int _playVersion = 0;

  PlayerNotifier(this._ref) : super(const PlayerState()) {
    _player = Player();
    _listenToPlayer();
  }

  ElysiumApi get _api {
    final serverIp = _ref.read(serverIpProvider);
    final settings = _ref.read(settingsProvider);
    return ElysiumApi(serverIp, apiSecret: settings?.apiSecret ?? '');
  }

  Player get player => _player;

  void _listenToPlayer() {
    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _player.stream.position.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.stream.duration.listen((dur) {
      state = state.copyWith(duration: dur);
    });
    _player.stream.completed.listen((completed) {
      if (completed) {
        _onTrackComplete();
      }
    });
  }

  void _onTrackComplete() {
    switch (state.repeatMode) {
      case ElysiumRepeatMode.one:
        _player.seek(Duration.zero);
        _player.play();
      case ElysiumRepeatMode.all:
        final next = (state.currentIndex + 1) % state.queue.length;
        playIndex(next);
      case ElysiumRepeatMode.off:
        if (state.currentIndex < state.queue.length - 1) {
          playIndex(state.currentIndex + 1);
        }
    }
  }
  Future<void> fetchSettings() async {
    await _ref.read(settingsProvider.notifier)._init();
    final s = _ref.read(settingsProvider);
    if (s != null) {
      state = state.copyWith(videoMode: s.videoMode);
    }
  }

  Future<void> toggleVideoMode() async {
    final newMode = !state.videoMode;
    state = state.copyWith(videoMode: newMode);
    await _ref.read(settingsProvider.notifier).update({'videoMode': newMode});
    // If playing, re-resolve for new format
    if (state.currentIndex != -1) {
      await playIndex(state.currentIndex);
    }
  }

  void playTrackNow(Track track) {
    state = state.copyWith(queue: [track], currentIndex: 0);
    playIndex(0);
  }

  void playNext(Track track) {
    if (state.queue.isEmpty) {
      playTrackNow(track);
      return;
    }
    final newQueue = List<Track>.from(state.queue);
    newQueue.insert(state.currentIndex + 1, track);
    state = state.copyWith(queue: newQueue);
  }

  void addToQueue(Track track) {
    state = state.copyWith(queue: [...state.queue, track]);
    if (state.currentIndex == -1) {
      playIndex(0);
    }
  }

  void addAllToQueue(List<Track> tracks) {
    final wasEmpty = state.queue.isEmpty;
    state = state.copyWith(queue: [...state.queue, ...tracks]);
    if (wasEmpty) {
      playIndex(0);
    }
  }

  void playAll(List<Track> tracks) {
    state = state.copyWith(queue: tracks, currentIndex: 0);
    playIndex(0);
  }

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    
    final version = ++_playVersion;
    state = state.copyWith(currentIndex: index);
    final track = state.queue[index];

    try {
      String? playUrl = track.url;
      final settings = _ref.read(settingsProvider) ?? await _api.getSettings();
      if (version != _playVersion) return;

      state = state.copyWith(videoMode: settings.videoMode);
      final api = _api; // Uses current settings/secret

      final instance = settings.invidiousInstance.isNotEmpty 
          ? settings.invidiousInstance 
          : 'https://yt.ikiagi.loseyourip.com';

      // ── Stream Resolution Logic ───────────────────────────────────────────
      if (track.videoId != null) {
        final details = await api.getVideoDetails(track.videoId!,
            instanceUrl: instance, sid: settings.invidiousSid);
        if (version != _playVersion) return;

        final formats = (details['adaptiveFormats'] as List<dynamic>? ?? []);
        dynamic bestFormat;
        
        if (state.videoMode) {
          bestFormat = formats.firstWhere(
            (f) => (f['type']?.toString().contains('video/') ?? false) && f['videoOnly'] != true,
            orElse: () => formats.firstWhere(
              (f) => f['type']?.toString().contains('video/') ?? false,
              orElse: () => formats.isNotEmpty ? formats.first : null,
            ),
          );
        } else {
          bestFormat = formats.firstWhere(
            (f) => f['type']?.toString().startsWith('audio/') ?? false,
            orElse: () => formats.isNotEmpty ? formats.first : null,
          );
        }
        
        if (bestFormat != null && bestFormat['url'] != null) {
          playUrl = bestFormat['url'];
        }
      } else if (playUrl != null && (playUrl.contains('apple.com') || playUrl.contains('itunes'))) {
        final results = await api.invidiousSearch('${track.artist} ${track.title} official audio',
            instanceUrl: instance);
        if (version != _playVersion) return;

        if (results.isNotEmpty) {
          final match = results.first;
          final details = await api.getVideoDetails(match.id,
              instanceUrl: instance, sid: settings.invidiousSid);
          if (version != _playVersion) return;

          final formats = (details['adaptiveFormats'] as List<dynamic>? ?? []);
          final bestFormat = formats.firstWhere(
            (f) => f['type']?.toString().startsWith('audio/') ?? false,
            orElse: () => formats.isNotEmpty ? formats.first : null,
          );
          
          if (bestFormat != null && bestFormat['url'] != null) {
            playUrl = bestFormat['url'];
          }
        }
      }

      if (playUrl != null && playUrl.isNotEmpty && version == _playVersion) {
        await _player.open(Media(playUrl));
      }
    } catch (e) {
      if (version != _playVersion) return;
      print('Playback error: $e');
      if (track.url != null) {
        await _player.open(Media(track.url!));
      }
    }
  }

  Future<void> next() async {
    final q = state.queue;
    if (q.isEmpty) return;
    if (state.shuffled) {
      final next = (List.generate(q.length, (i) => i)
            ..remove(state.currentIndex)
            ..shuffle())
          .first;
      await playIndex(next);
    } else {
      final next = (state.currentIndex + 1) % q.length;
      await playIndex(next);
    }
  }

  Future<void> previous() async {
    if (state.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final prev = (state.currentIndex - 1 + state.queue.length) %
        state.queue.length.clamp(1, state.queue.length);
    await playIndex(prev);
  }

  Future<void> togglePlayPause() async {
    await _player.playOrPause();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void setQueue(List<Track> tracks) {
    state = state.copyWith(queue: tracks, currentIndex: -1);
  }

  void toggleShuffle() {
    final next = !state.shuffled;
    state = state.copyWith(shuffled: next);
  }

  void cycleRepeat() {
    final next = ElysiumRepeatMode.values[
        (state.repeatMode.index + 1) % ElysiumRepeatMode.values.length];
    state = state.copyWith(repeatMode: next);
  }

  void setFavorites(List<Track> favs) {
    state = state.copyWith(favorites: favs);
  }

  void addFavorite(Track track) {
    if (!state.isFavorite(track.effectiveId)) {
      state = state.copyWith(favorites: [...state.favorites, track]);
    }
  }

  void removeFavorite(String id) {
    state = state.copyWith(
      favorites: state.favorites
          .where((f) => (f.videoId ?? f.id) != id)
          .toList(),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
