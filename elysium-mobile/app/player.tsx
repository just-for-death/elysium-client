import React, { useState, useEffect, useRef } from 'react';
import {
  View, StyleSheet, ImageBackground, Platform, Dimensions,
  TouchableOpacity, ScrollView, FlatList, Animated
} from 'react-native';
import { Text, IconButton, ProgressBar, useTheme } from 'react-native-paper';
import { BlurView } from 'expo-blur';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { usePlayerStore, Track } from '../store/usePlayerStore';
import { addFavorite, deleteFavorite, lyricsSearch, lyricsGet, generateAIQueue } from '../services/ElysiumApi';

const { width } = Dimensions.get('window');

type Tab = 'cover' | 'lyrics' | 'queue';
type LyricLine = { time: number; text: string };

function parseLRC(lrc: string): LyricLine[] {
  const lines = lrc.split('\n');
  const result: LyricLine[] = [];
  for (const line of lines) {
    const m = line.match(/\[(\d+):(\d+(?:\.\d+)?)\](.*)/);
    if (m) {
      const time = parseInt(m[1]) * 60 + parseFloat(m[2]);
      const text = m[3].trim();
      if (text) result.push({ time, text });
    }
  }
  return result.sort((a, b) => a.time - b.time);
}

export default function PlayerScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const {
    queue, currentTrackIndex, isPlaying, positionMillis, durationMillis,
    next, previous, setIsPlaying, playIndex, repeatMode, shuffled,
    setRepeatMode, toggleShuffle, serverIp, favorites, setFavorites, isFavorite
  } = usePlayerStore();

  const currentTrack: Track | null = currentTrackIndex >= 0 ? queue[currentTrackIndex] : null;
  const [tab, setTab] = useState<Tab>('cover');
  const [lyrics, setLyrics] = useState<LyricLine[]>([]);
  const [lyricsLoading, setLyricsLoading] = useState(false);
  const [lyricErrorMsg, setLyricErrorMsg] = useState('');
  const [activeLyricIdx, setActiveLyricIdx] = useState(0);
  const [aiGenerating, setAiGenerating] = useState(false);
  const lyricsRef = useRef<FlatList>(null);
  const artworkAnim = useRef(new Animated.Value(1)).current;

  const progress = durationMillis > 0 ? positionMillis / durationMillis : 0;
  const currentSec = positionMillis / 1000;
  const trackId = currentTrack?.id || currentTrack?.videoId || '';
  const fav = trackId ? isFavorite(trackId) : false;

  // Format time helper
  const fmt = (ms: number) => {
    const s = Math.floor(ms / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  };

  // Artwork pulse when track changes
  useEffect(() => {
    Animated.sequence([
      Animated.timing(artworkAnim, { toValue: 0.88, duration: 120, useNativeDriver: true }),
      Animated.spring(artworkAnim, { toValue: 1, useNativeDriver: true }),
    ]).start();
    setLyrics([]);
    setLyricErrorMsg('');
    setActiveLyricIdx(0);
  }, [trackId]);

  // Fetch lyrics when tab switches to lyrics
  useEffect(() => {
    if (tab !== 'lyrics' || !currentTrack || !serverIp) return;
    if (lyrics.length > 0) return;
    setLyricsLoading(true);
    const q = `${currentTrack.title} ${currentTrack.artist}`;
    lyricsSearch(serverIp, q)
      .then(async (data) => {
        const songs = data?.result?.songs;
        if (!songs?.length) throw new Error('No lyrics found');
        const id = songs[0].id;
        const lyricData = await lyricsGet(serverIp, String(id));
        const lrc = lyricData?.lrc?.lyric || '';
        const parsed = parseLRC(lrc);
        if (!parsed.length) throw new Error('Empty lyrics');
        setLyrics(parsed);
        setLyricErrorMsg('');
      })
      .catch((e) => setLyricErrorMsg(e.message || 'Lyrics not available'))
      .finally(() => setLyricsLoading(false));
  }, [tab, trackId]);

  // Update active lyric line
  useEffect(() => {
    if (!lyrics.length) return;
    let idx = lyrics.findLastIndex(l => l.time <= currentSec);
    if (idx < 0) idx = 0;
    if (idx !== activeLyricIdx) {
      setActiveLyricIdx(idx);
      lyricsRef.current?.scrollToIndex({ index: Math.max(0, idx), animated: true, viewPosition: 0.4 });
    }
  }, [currentSec, lyrics]);

  // Favorite toggle
  const toggleFav = async () => {
    if (!currentTrack || !serverIp) return;
    const track = { ...currentTrack, videoId: trackId };
    if (fav) {
      await deleteFavorite(serverIp, trackId).catch(() => {});
      setFavorites(favorites.filter(f => (f.videoId || f.id) !== trackId));
    } else {
      await addFavorite(serverIp, track as any).catch(() => {});
      setFavorites([...favorites, track]);
    }
  };

  // AI Queue next
  const handleAI = async () => {
    if (!currentTrack || !serverIp || aiGenerating) return;
    setAiGenerating(true);
    try {
      const res = await generateAIQueue(serverIp, currentTrack as any);
      const aiTrack = { ...res.track, id: res.track.id || String(Date.now()), url: res.track.url || '' };
      const newQueue = [...queue];
      newQueue.splice(currentTrackIndex + 1, 0, aiTrack);
      usePlayerStore.getState().setQueue(newQueue);
    } catch {}
    finally { setAiGenerating(false); }
  };

  const repeatIcon = repeatMode === 'one' ? 'repeat-once' : 'repeat';
  const repeatActive = repeatMode !== 'off';

  const albumArtUrl = currentTrack?.artwork ||
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=400&auto=format&fit=crop';

  return (
    <ImageBackground source={{ uri: albumArtUrl }} style={styles.background} blurRadius={Platform.OS === 'android' ? 60 : 0}>
      <BlurView style={StyleSheet.absoluteFill} tint="dark" intensity={Platform.OS === 'ios' ? 90 : 120} experimentalBlurMethod="dimezisBlurView" />

      <View style={[styles.content, { paddingTop: insets.top + 8, paddingBottom: insets.bottom + 16 }]}>

        {/* ── Header ── */}
        <View style={styles.header}>
          <IconButton icon="chevron-down" size={28} iconColor="rgba(255,255,255,0.9)" onPress={() => router.back()} />
          <View style={{ flex: 1, alignItems: 'center' }}>
            <Text style={styles.headerLabel}>{currentTrack?.album || 'Now Playing'}</Text>
          </View>
          <IconButton
            icon={aiGenerating ? 'loading' : 'robot'}
            size={24}
            iconColor={aiGenerating ? theme.colors.primary : 'rgba(255,255,255,0.7)'}
            onPress={handleAI}
          />
        </View>

        {/* ── Tab Pills ── */}
        <View style={styles.tabRow}>
          {(['cover', 'lyrics', 'queue'] as Tab[]).map(t => (
            <TouchableOpacity
              key={t}
              onPress={() => setTab(t)}
              style={[styles.tabPill, tab === t && styles.tabPillActive]}
            >
              <Text style={[styles.tabText, tab === t && styles.tabTextActive]}>
                {t === 'cover' ? '♫ Cover' : t === 'lyrics' ? '☰ Lyrics' : '≡ Queue'}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        {/* ── Main Content Area ── */}
        <View style={{ flex: 1 }}>
          {tab === 'cover' && (
            <Animated.View style={[styles.artworkWrapper, { transform: [{ scale: artworkAnim }] }]}>
              <ImageBackground source={{ uri: albumArtUrl }} style={styles.artwork} imageStyle={{ borderRadius: 20 }} />
            </Animated.View>
          )}

          {tab === 'lyrics' && (
            <View style={{ flex: 1 }}>
              {lyricsLoading ? (
                <View style={styles.lyricCenter}>
                  <MaterialCommunityIcons name="music-note" size={40} color="rgba(255,255,255,0.3)" />
                  <Text style={styles.lyricHint}>Searching lyrics…</Text>
                </View>
              ) : lyricErrorMsg ? (
                <View style={styles.lyricCenter}>
                  <MaterialCommunityIcons name="music-note-off" size={40} color="rgba(255,255,255,0.3)" />
                  <Text style={styles.lyricHint}>{lyricErrorMsg}</Text>
                </View>
              ) : (
                <FlatList
                  ref={lyricsRef}
                  data={lyrics}
                  keyExtractor={(_, i) => String(i)}
                  showsVerticalScrollIndicator={false}
                  contentContainerStyle={styles.lyricsList}
                  onScrollToIndexFailed={() => {}}
                  renderItem={({ item, index }) => {
                    const active = index === activeLyricIdx;
                    const delta = Math.abs(index - activeLyricIdx);
                    return (
                      <Text
                        style={[
                          styles.lyricLine,
                          { opacity: active ? 1 : Math.max(0.15, 0.6 - delta * 0.12), fontSize: active ? 22 : 18 }
                        ]}
                      >
                        {item.text}
                      </Text>
                    );
                  }}
                />
              )}
            </View>
          )}

          {tab === 'queue' && (
            <FlatList
              data={queue}
              keyExtractor={(item) => item.id}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.queueList}
              renderItem={({ item, index }) => {
                const active = index === currentTrackIndex;
                return (
                  <TouchableOpacity onPress={() => playIndex(index)} style={[styles.queueItem, active && styles.queueItemActive]}>
                    {item.artwork ? (
                      <ImageBackground source={{ uri: item.artwork }} style={styles.queueArt} imageStyle={{ borderRadius: 8 }} />
                    ) : (
                      <View style={[styles.queueArt, { backgroundColor: theme.colors.primaryContainer, borderRadius: 8, justifyContent: 'center', alignItems: 'center' }]}>
                        <MaterialCommunityIcons name="music" size={20} color={theme.colors.primary} />
                      </View>
                    )}
                    <View style={{ flex: 1, marginLeft: 12 }}>
                      <Text numberOfLines={1} style={[styles.queueTitle, active && { color: theme.colors.primary }]}>{item.title}</Text>
                      <Text numberOfLines={1} style={styles.queueArtist}>{item.artist}</Text>
                    </View>
                    {active && <MaterialCommunityIcons name="equalizer" size={20} color={theme.colors.primary} />}
                  </TouchableOpacity>
                );
              }}
            />
          )}
        </View>

        {/* ── Track Info + Actions ── */}
        <View style={styles.infoRow}>
          <View style={{ flex: 1 }}>
            <Text style={styles.trackTitle} numberOfLines={1}>{currentTrack?.title || '—'}</Text>
            <Text style={styles.trackArtist} numberOfLines={1}>{currentTrack?.artist || 'Unknown Artist'}</Text>
          </View>
          <TouchableOpacity onPress={toggleFav} style={styles.favBtn}>
            <MaterialCommunityIcons
              name={fav ? 'heart' : 'heart-outline'}
              size={28}
              color={fav ? '#ff4d6d' : 'rgba(255,255,255,0.6)'}
            />
          </TouchableOpacity>
        </View>

        {/* ── Progress Bar ── */}
        <View style={styles.progressArea}>
          <ProgressBar progress={progress} color="#fff" style={styles.progressBar} />
          <View style={styles.timeRow}>
            <Text style={styles.timeText}>{fmt(positionMillis)}</Text>
            <Text style={styles.timeText}>-{fmt(Math.max(0, durationMillis - positionMillis))}</Text>
          </View>
        </View>

        {/* ── Controls ── */}
        <View style={styles.controls}>
          <TouchableOpacity onPress={toggleShuffle}>
            <MaterialCommunityIcons name="shuffle" size={24} color={shuffled ? '#a994ff' : 'rgba(255,255,255,0.5)'} />
          </TouchableOpacity>

          <TouchableOpacity onPress={previous}>
            <MaterialCommunityIcons name="skip-previous" size={44} color="#fff" />
          </TouchableOpacity>

          <TouchableOpacity
            onPress={() => {
              if (currentTrackIndex === -1 && queue.length > 0) playIndex(0);
              else setIsPlaying(!isPlaying);
            }}
            style={styles.playBtn}
          >
            <MaterialCommunityIcons name={isPlaying ? 'pause' : 'play'} size={38} color="#000" />
          </TouchableOpacity>

          <TouchableOpacity onPress={next}>
            <MaterialCommunityIcons name="skip-next" size={44} color="#fff" />
          </TouchableOpacity>

          <TouchableOpacity onPress={() => setRepeatMode(repeatMode === 'off' ? 'all' : repeatMode === 'all' ? 'one' : 'off')}>
            <MaterialCommunityIcons name={repeatIcon as any} size={24} color={repeatActive ? '#a994ff' : 'rgba(255,255,255,0.5)'} />
          </TouchableOpacity>
        </View>

      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: { flex: 1, backgroundColor: '#050505' },
  content: { flex: 1, paddingHorizontal: 24 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 8 },
  headerLabel: { color: 'rgba(255,255,255,0.6)', fontSize: 12, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1 },
  tabRow: { flexDirection: 'row', justifyContent: 'center', gap: 8, marginBottom: 16 },
  tabPill: { paddingHorizontal: 16, paddingVertical: 6, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)' },
  tabPillActive: { backgroundColor: 'rgba(255,255,255,0.25)' },
  tabText: { color: 'rgba(255,255,255,0.5)', fontSize: 13, fontWeight: '600' },
  tabTextActive: { color: '#fff' },
  artworkWrapper: { flex: 1, justifyContent: 'center', alignItems: 'center', paddingVertical: 8 },
  artwork: { width: width - 64, height: width - 64, borderRadius: 20, maxWidth: 420, maxHeight: 420 },
  lyricCenter: { flex: 1, justifyContent: 'center', alignItems: 'center', gap: 12 },
  lyricHint: { color: 'rgba(255,255,255,0.4)', fontSize: 15 },
  lyricsList: { paddingVertical: 40, paddingHorizontal: 8, paddingBottom: 40 },
  lyricLine: { color: '#fff', fontWeight: '700', textAlign: 'left', marginVertical: 10, lineHeight: 30 },
  queueList: { paddingBottom: 16 },
  queueItem: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8, borderRadius: 10 },
  queueItemActive: { backgroundColor: 'rgba(255,255,255,0.06)' },
  queueArt: { width: 44, height: 44 },
  queueTitle: { color: '#fff', fontWeight: '700', fontSize: 14 },
  queueArtist: { color: 'rgba(255,255,255,0.5)', fontSize: 12 },
  infoRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 },
  trackTitle: { color: '#fff', fontSize: 24, fontWeight: '800', letterSpacing: -0.3 },
  trackArtist: { color: 'rgba(255,255,255,0.6)', fontSize: 16, fontWeight: '500', marginTop: 4 },
  favBtn: { padding: 6 },
  progressArea: { marginBottom: 24 },
  progressBar: { height: 4, borderRadius: 2, backgroundColor: 'rgba(255,255,255,0.2)' },
  timeRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 },
  timeText: { color: 'rgba(255,255,255,0.5)', fontSize: 12, fontWeight: '600' },
  controls: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 },
  playBtn: { width: 72, height: 72, borderRadius: 36, backgroundColor: '#fff', justifyContent: 'center', alignItems: 'center' },
});
