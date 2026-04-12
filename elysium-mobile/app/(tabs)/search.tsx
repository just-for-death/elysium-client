import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View, StyleSheet, FlatList, Keyboard, TextInput as RNTextInput,
  TouchableOpacity, ScrollView
} from 'react-native';
import { Text, useTheme, ActivityIndicator, Chip } from 'react-native-paper';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { usePlayerStore, Track } from '../../store/usePlayerStore';
import { itunesSearch, itunesTopSongs } from '../../services/ElysiumApi';

// Debounce helper
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const h = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(h);
  }, [value, delay]);
  return debounced;
}

type SearchResult = {
  id: string;
  title: string;
  artist: string;
  artwork?: string;
  previewUrl?: string;
};

const GENRES = ['Pop', 'Hip-Hop', 'R&B', 'Rock', 'Electronic', 'Jazz', 'Classical', 'K-Pop', 'Indie'];

function parseItunesTrack(t: any): SearchResult {
  return {
    id: String(t.trackId),
    title: t.trackName || '—',
    artist: t.artistName || '—',
    artwork: t.artworkUrl100?.replace('100x100bb', '400x400bb'),
    previewUrl: t.previewUrl,
  };
}

function parseItunesRss(entry: any): SearchResult {
  return {
    id: entry['id']?.['attributes']?.['im:id'] || String(Math.random()),
    title: entry['im:name']?.['label'] || '—',
    artist: entry['im:artist']?.['label'] || '—',
    artwork: entry['im:image']?.[2]?.['label'],
    previewUrl: undefined,
  };
}

export default function SearchScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { serverIp, setQueue, playIndex } = usePlayerStore();

  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [trending, setTrending] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedGenre, setSelectedGenre] = useState<string | null>(null);

  const debouncedQuery = useDebounce(query, 450);
  const inputRef = useRef<RNTextInput>(null);

  // Load trending top songs on mount
  useEffect(() => {
    if (!serverIp) return;
    itunesTopSongs(serverIp, 'us', 20)
      .then((data) => {
        const entries = data?.feed?.entry || [];
        setTrending(entries.map(parseItunesRss));
      })
      .catch(() => {});
  }, [serverIp]);

  // Auto search on debounced query
  useEffect(() => {
    if (!debouncedQuery.trim()) { setResults([]); return; }
    if (!serverIp) return;
    setLoading(true);
    itunesSearch(serverIp, debouncedQuery)
      .then((data) => setResults((data.results || []).map(parseItunesTrack)))
      .catch(() => setResults([]))
      .finally(() => setLoading(false));
  }, [debouncedQuery, serverIp]);

  // Genre search
  const searchGenre = useCallback(async (genre: string) => {
    setSelectedGenre(genre);
    setQuery('');
    if (!serverIp) return;
    setLoading(true);
    try {
      const data = await itunesSearch(serverIp, `${genre} music`, 30);
      setResults((data.results || []).map(parseItunesTrack));
    } finally {
      setLoading(false);
    }
  }, [serverIp]);

  const playResult = (item: SearchResult, idx: number, from: SearchResult[]) => {
    const tracks: Track[] = from.map(r => ({
      id: r.id,
      url: r.previewUrl || '',
      title: r.title,
      artist: r.artist,
      artwork: r.artwork,
    }));
    setQueue(tracks);
    playIndex(idx);
  };

  const isSearching = debouncedQuery.trim().length > 0 || selectedGenre !== null;

  return (
    <View style={[styles.container, { backgroundColor: '#000' }]}>
      <View style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <Text style={styles.title}>Search</Text>

        {/* Custom search input */}
        <View style={[styles.searchBox, { backgroundColor: theme.colors.elevation.level2 }]}>
          <MaterialCommunityIcons name="magnify" size={20} color={theme.colors.onSurfaceVariant} />
          <RNTextInput
            ref={inputRef}
            value={query}
            onChangeText={(t) => { setQuery(t); setSelectedGenre(null); }}
            placeholder="Songs, artists, albums..."
            placeholderTextColor={theme.colors.onSurfaceVariant}
            style={[styles.searchInput, { color: theme.colors.onSurface }]}
            returnKeyType="search"
            onSubmitEditing={Keyboard.dismiss}
          />
          {query.length > 0 && (
            <TouchableOpacity onPress={() => { setQuery(''); setResults([]); }}>
              <MaterialCommunityIcons name="close-circle" size={18} color={theme.colors.onSurfaceVariant} />
            </TouchableOpacity>
          )}
        </View>
      </View>

      {!isSearching && (
        <>
          {/* Genre pills */}
          <Text style={styles.sectionLabel}>Browse by Genre</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.genreRow}>
            {GENRES.map(g => (
              <TouchableOpacity
                key={g}
                style={[styles.genreChip, { backgroundColor: theme.colors.primaryContainer }]}
                onPress={() => searchGenre(g)}
              >
                <Text style={{ color: theme.colors.onPrimaryContainer, fontWeight: '700' }}>{g}</Text>
              </TouchableOpacity>
            ))}
          </ScrollView>

          <Text style={styles.sectionLabel}>Trending Now</Text>
        </>
      )}

      {loading ? (
        <ActivityIndicator style={{ marginTop: 40 }} color={theme.colors.primary} />
      ) : (
        <FlatList
          data={isSearching ? results : trending}
          keyExtractor={(item) => item.id}
          contentContainerStyle={styles.listContent}
          showsVerticalScrollIndicator={false}
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={
            isSearching && !loading ? (
              <View style={styles.emptyState}>
                <MaterialCommunityIcons name="music-note-off" size={52} color="rgba(255,255,255,0.2)" />
                <Text style={styles.emptyText}>No results found</Text>
              </View>
            ) : null
          }
          renderItem={({ item, index }) => {
            const source = isSearching ? results : trending;
            return (
              <TouchableOpacity
                style={styles.track}
                onPress={() => playResult(item, index, source)}
                activeOpacity={0.7}
              >
                <Image source={{ uri: item.artwork }} style={styles.artwork} contentFit="cover" transition={200} />
                <View style={styles.trackInfo}>
                  <Text numberOfLines={1} style={[styles.trackTitle, { color: theme.colors.onSurface }]}>{item.title}</Text>
                  <Text numberOfLines={1} style={[styles.trackArtist, { color: theme.colors.onSurfaceVariant }]}>{item.artist}</Text>
                </View>
                <MaterialCommunityIcons name="play-circle-outline" size={30} color={theme.colors.primary} />
              </TouchableOpacity>
            );
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { paddingHorizontal: 20, marginBottom: 16 },
  title: { fontSize: 34, fontWeight: '800', color: '#fff', letterSpacing: -0.5, marginBottom: 16 },
  searchBox: { flexDirection: 'row', alignItems: 'center', borderRadius: 14, paddingHorizontal: 12, height: 46, gap: 8 },
  searchInput: { flex: 1, fontSize: 15, paddingVertical: 0 },
  sectionLabel: { fontSize: 13, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1, color: 'rgba(255,255,255,0.5)', marginLeft: 20, marginBottom: 10 },
  genreRow: { paddingHorizontal: 16, marginBottom: 24, gap: 8 },
  genreChip: { paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20 },
  listContent: { paddingHorizontal: 16, paddingBottom: 140, gap: 4 },
  track: { flexDirection: 'row', alignItems: 'center', paddingVertical: 8 },
  artwork: { width: 52, height: 52, borderRadius: 8, backgroundColor: '#333' },
  trackInfo: { flex: 1, marginHorizontal: 12 },
  trackTitle: { fontSize: 14, fontWeight: '700' },
  trackArtist: { fontSize: 12, marginTop: 2 },
  emptyState: { alignItems: 'center', paddingTop: 80, gap: 12 },
  emptyText: { color: 'rgba(255,255,255,0.4)', fontSize: 15 },
});
