import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffled = false,
    this.repeatMode = ElysiumRepeatMode.off,
    this.favorites = const [],
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
      );
}

// ── Player Notifier ───────────────────────────────────────────────────────────
final playerProvider =
    StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

class PlayerNotifier extends StateNotifier<PlayerState> {
  late final AudioPlayer _player;

  PlayerNotifier() : super(const PlayerState()) {
    _player = AudioPlayer();
    _listenToPlayer();
  }

  AudioPlayer get audioPlayer => _player;

  void _listenToPlayer() {
    _player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
    _player.durationStream.listen((dur) {
      if (dur != null) state = state.copyWith(duration: dur);
    });
    _player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
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

  Future<void> playIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(currentIndex: index);
    final track = state.queue[index];
    final url = track.url;
    if (url != null && url.isNotEmpty) {
      try {
        await _player.setUrl(url);
        await _player.play();
      } catch (_) {}
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
    if (state.isPlaying) {
      await _player.pause();
    } else {
      if (state.currentIndex == -1 && state.queue.isNotEmpty) {
        await playIndex(0);
      } else {
        await _player.play();
      }
    }
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  void setQueue(List<Track> tracks) {
    state = state.copyWith(queue: tracks, currentIndex: -1);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffled: !state.shuffled);
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
