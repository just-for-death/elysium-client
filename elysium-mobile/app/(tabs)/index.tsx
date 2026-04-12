import React, { useEffect, useState } from 'react';
import {
  View, StyleSheet, FlatList, ScrollView, TouchableOpacity, RefreshControl
} from 'react-native';
import { Text, useTheme, ActivityIndicator, Chip } from 'react-native-paper';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { usePlayerStore, Track } from '../../store/usePlayerStore';
import { itunesTopSongs, getHistory, addHistory } from '../../services/ElysiumApi';

type RssEntry = {
  id: string;
  title: string;
  artist: string;
  artwork?: string;
};

function parseRssEntries(entries: any[]): RssEntry[] {
  return entries.map((e) => ({
    id: e['id']?.['attributes']?.['im:id'] || String(Math.random()),
    title: e['im:name']?.['label'] || '—',
    artist: e['im:artist']?.['label'] || '—',
    artwork: e['im:image']?.[2]?.['label'],
  }));
}

const COUNTRIES = [
  { cc: 'us', label: '🇺🇸 US' },
  { cc: 'gb', label: '🇬🇧 UK' },
  { cc: 'jp', label: '🇯🇵 Japan' },
  { cc: 'kr', label: '🇰🇷 Korea' },
  { cc: 'in', label: '🇮🇳 India' },
  { cc: 'de', label: '🇩🇪 Germany' },
];

export default function HomeScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { serverIp, setQueue, playIndex } = usePlayerStore();

  const [country, setCountry] = useState('us');
  const [trending, setTrending] = useState<RssEntry[]>([]);
  const [history, setHistoryData] = useState<Track[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const load = async (silent = false) => {
    if (!serverIp) return;
    if (!silent) setLoading(true);
    try {
      const [rssData, histData] = await Promise.allSettled([
        itunesTopSongs(serverIp, country, 20),
        getHistory(serverIp),
      ]);
      if (rssData.status === 'fulfilled') {
        setTrending(parseRssEntries(rssData.value?.feed?.entry || []));
      }
      if (histData.status === 'fulfilled') {
        setHistoryData(histData.value.slice(0, 10) as Track[]);
      }
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => { load(); }, [serverIp, country]);

  const onRefresh = () => { setRefreshing(true); load(true); };

  const playTrending = (idx: number) => {
    const tracks: Track[] = trending.map(t => ({
      id: t.id, url: '', title: t.title, artist: t.artist, artwork: t.artwork
    }));
    setQueue(tracks);
    playIndex(idx);
    // Log to history
    if (serverIp) addHistory(serverIp, tracks[idx] as any).catch(() => {});
  };

  const playHistoryTrack = (item: Track, idx: number) => {
    setQueue(history.slice(idx) as any);
    playIndex(0);
  };

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: '#000' }]}
      contentContainerStyle={[styles.content, { paddingBottom: 140 }]}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.colors.primary} />}
      showsVerticalScrollIndicator={false}
    >
      {/* Header */}
      <View style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <Text style={styles.title}>Elysium</Text>
        <Text style={styles.subtitle}>Your music, your server</Text>
      </View>

      {/* Country Picker */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.countryRow}>
        {COUNTRIES.map(c => (
          <Chip
            key={c.cc}
            mode={country === c.cc ? 'flat' : 'outlined'}
            selected={country === c.cc}
            onPress={() => setCountry(c.cc)}
            style={[styles.chip, country === c.cc && { backgroundColor: theme.colors.primary }]}
            textStyle={{ color: country === c.cc ? '#fff' : theme.colors.onSurfaceVariant, fontWeight: '600', fontSize: 12 }}
          >
            {c.label}
          </Chip>
        ))}
      </ScrollView>

      {/* Trending */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>🔥 Trending</Text>
        {loading ? (
          <ActivityIndicator color={theme.colors.primary} style={{ marginTop: 20 }} />
        ) : trending.length === 0 ? (
          <Text style={styles.emptyMsg}>Could not load trending. Is the server running?</Text>
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.trendingRow}>
            {trending.map((item, idx) => (
              <TouchableOpacity key={item.id} onPress={() => playTrending(idx)} style={styles.trendCard}>
                <Image source={{ uri: item.artwork }} style={styles.trendArt} contentFit="cover" transition={300} />
                <Text style={styles.trendTitle} numberOfLines={2}>{item.title}</Text>
                <Text style={styles.trendArtist} numberOfLines={1}>{item.artist}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>
        )}
      </View>

      {/* Recent History */}
      {history.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>🕐 Recently Played</Text>
          {history.map((item, idx) => (
            <TouchableOpacity
              key={`${item.id}-${idx}`}
              style={[styles.historyRow, { backgroundColor: theme.colors.elevation.level1 }]}
              onPress={() => playHistoryTrack(item, idx)}
            >
              <Image source={{ uri: item.artwork }} style={styles.historyArt} contentFit="cover" />
              <View style={{ flex: 1, marginLeft: 12 }}>
                <Text numberOfLines={1} style={[styles.historyTitle, { color: theme.colors.onSurface }]}>{item.title}</Text>
                <Text numberOfLines={1} style={[styles.historyArtist, { color: theme.colors.onSurfaceVariant }]}>{item.artist}</Text>
              </View>
              <MaterialCommunityIcons name="play-circle-outline" size={28} color={theme.colors.primary} />
            </TouchableOpacity>
          ))}
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { paddingBottom: 48 },
  header: { paddingHorizontal: 20, marginBottom: 20 },
  title: { fontSize: 36, fontWeight: '900', color: '#fff', letterSpacing: -1 },
  subtitle: { fontSize: 14, color: 'rgba(255,255,255,0.4)', fontWeight: '500', marginTop: 2 },
  countryRow: { paddingHorizontal: 16, marginBottom: 8, gap: 8 },
  chip: { height: 34 },
  section: { marginTop: 24, paddingHorizontal: 20 },
  sectionTitle: { fontSize: 18, fontWeight: '800', color: '#fff', marginBottom: 16, letterSpacing: -0.2 },
  trendingRow: { gap: 12, paddingBottom: 8 },
  trendCard: { width: 140 },
  trendArt: { width: 140, height: 140, borderRadius: 14, backgroundColor: '#222' },
  trendTitle: { color: '#fff', fontWeight: '700', fontSize: 13, marginTop: 8, lineHeight: 18 },
  trendArtist: { color: 'rgba(255,255,255,0.5)', fontSize: 12, marginTop: 2 },
  historyRow: { flexDirection: 'row', alignItems: 'center', borderRadius: 12, paddingHorizontal: 12, paddingVertical: 10, marginBottom: 8 },
  historyArt: { width: 48, height: 48, borderRadius: 8, backgroundColor: '#333' },
  historyTitle: { fontWeight: '700', fontSize: 14 },
  historyArtist: { fontSize: 12, marginTop: 2 },
  emptyMsg: { color: 'rgba(255,255,255,0.3)', fontSize: 14, fontStyle: 'italic' },
});
