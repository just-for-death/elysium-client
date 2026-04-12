import React, { useEffect, useState, useCallback } from 'react';
import { View, StyleSheet, FlatList, ScrollView, TouchableOpacity, Alert, RefreshControl } from 'react-native';
import { Text, useTheme, IconButton, FAB, Chip, ActivityIndicator, Searchbar } from 'react-native-paper';
import { Image } from 'expo-image';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { usePlayerStore, Track } from '../../store/usePlayerStore';
import {
  getFavorites, getPlaylists, getArtists, getAlbums,
  createPlaylist, deletePlaylist, deleteFavorite,
  addFavorite,
  Playlist, Artist, Album,
} from '../../services/ElysiumApi';

type LibSection = 'favorites' | 'playlists' | 'artists' | 'albums';

export default function LibraryScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { serverIp, setQueue, playIndex, favorites, setFavorites, isFavorite } = usePlayerStore();

  const [section, setSection] = useState<LibSection>('favorites');
  const [playlists, setPlaylists] = useState<Playlist[]>([]);
  const [artists, setArtists] = useState<Artist[]>([]);
  const [albums, setAlbums] = useState<Album[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);

  const loadSection = useCallback(async (s: LibSection, silent = false) => {
    if (!serverIp) return;
    if (!silent) setLoading(true);
    try {
      if (s === 'favorites') {
        const data = await getFavorites(serverIp);
        setFavorites(data);
      } else if (s === 'playlists') {
        const data = await getPlaylists(serverIp);
        setPlaylists(data);
      } else if (s === 'artists') {
        const data = await getArtists(serverIp);
        setArtists(data);
      } else if (s === 'albums') {
        const data = await getAlbums(serverIp);
        setAlbums(data);
      }
    } catch (e) {
      // Silent failure on refresh
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [serverIp]);

  useEffect(() => { loadSection(section); }, [section, serverIp]);

  const onRefresh = () => { setRefreshing(true); loadSection(section, true); };

  const handlePlayFavorites = () => {
    if (!favorites.length) return;
    setQueue(favorites as any);
    playIndex(0);
  };

  const handleUnfavorite = async (track: Track) => {
    const id = track.videoId || track.id;
    try {
      await deleteFavorite(serverIp, id);
      setFavorites(favorites.filter(f => (f.videoId || f.id) !== id));
    } catch {}
  };

  const handleCreatePlaylist = () => {
    Alert.prompt('New Playlist', 'Enter a name for your playlist:', async (name) => {
      if (!name) return;
      try {
        const pl = await createPlaylist(serverIp, { title: name });
        setPlaylists(prev => [...prev, pl]);
      } catch {}
    });
  };

  const handleDeletePlaylist = (id: string) => {
    Alert.alert('Delete Playlist', 'Are you sure?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: async () => {
        try {
          await deletePlaylist(serverIp, id);
          setPlaylists(prev => prev.filter(p => p.id !== id));
        } catch {}
      }},
    ]);
  };

  const sectionTabs: { key: LibSection; label: string; icon: string }[] = [
    { key: 'favorites', label: 'Loved', icon: 'heart' },
    { key: 'playlists', label: 'Playlists', icon: 'playlist-play' },
    { key: 'artists', label: 'Artists', icon: 'music-circle' },
    { key: 'albums', label: 'Albums', icon: 'album' },
  ];

  return (
    <View style={[styles.container, { backgroundColor: '#000' }]}>
      {/* Header */}
      <View style={[styles.header, { paddingTop: insets.top + 20 }]}>
        <Text style={styles.title}>Library</Text>
      </View>

      {/* Section Tabs */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.tabs}>
        {sectionTabs.map(tab => (
          <Chip
            key={tab.key}
            icon={tab.icon}
            mode={section === tab.key ? 'flat' : 'outlined'}
            selected={section === tab.key}
            onPress={() => setSection(tab.key)}
            style={[styles.chip, section === tab.key && { backgroundColor: theme.colors.primary }]}
            textStyle={{ color: section === tab.key ? '#fff' : theme.colors.onSurfaceVariant, fontWeight: '600' }}
          >
            {tab.label}
          </Chip>
        ))}
      </ScrollView>

      {loading ? (
        <ActivityIndicator style={{ flex: 1 }} color={theme.colors.primary} />
      ) : (
        <>
          {/* ── Favorites ── */}
          {section === 'favorites' && (
            <>
              {favorites.length > 0 && (
                <TouchableOpacity style={[styles.playAllBtn, { backgroundColor: theme.colors.primaryContainer }]} onPress={handlePlayFavorites}>
                  <MaterialCommunityIcons name="play" size={20} color={theme.colors.onPrimaryContainer} />
                  <Text style={{ color: theme.colors.onPrimaryContainer, fontWeight: '700', marginLeft: 8 }}>Play All Loved Songs</Text>
                </TouchableOpacity>
              )}
              <FlatList
                data={favorites as Track[]}
                keyExtractor={(item) => item.videoId || item.id}
                showsVerticalScrollIndicator={false}
                contentContainerStyle={styles.list}
                refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.colors.primary} />}
                ListEmptyComponent={<EmptyState icon="heart-outline" message="No loved songs yet.\nHeart tracks while listening!" />}
                renderItem={({ item, index }) => (
                  <TrackRow
                    track={item as any}
                    onPress={() => { setQueue(favorites as any); playIndex(index); }}
                    rightAction={<IconButton icon="heart-remove" size={20} iconColor={theme.colors.error} onPress={() => handleUnfavorite(item)} />}
                    theme={theme}
                  />
                )}
              />
            </>
          )}

          {/* ── Playlists ── */}
          {section === 'playlists' && (
            <FlatList
              data={playlists}
              keyExtractor={(item) => item.id}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.list}
              refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.colors.primary} />}
              ListEmptyComponent={<EmptyState icon="playlist-plus" message="No playlists yet." />}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={[styles.playlistRow, { backgroundColor: theme.colors.elevation.level1 }]}
                  onPress={() => {
                    if (item.videos?.length) { setQueue(item.videos as any); playIndex(0); }
                  }}
                >
                  <View style={[styles.playlistArt, { backgroundColor: theme.colors.primaryContainer }]}>
                    <MaterialCommunityIcons name="playlist-play" size={28} color={theme.colors.primary} />
                  </View>
                  <View style={{ flex: 1, marginLeft: 14 }}>
                    <Text style={{ fontWeight: '700', fontSize: 15, color: theme.colors.onSurface }} numberOfLines={1}>{item.title}</Text>
                    <Text style={{ fontSize: 12, color: theme.colors.onSurfaceVariant, marginTop: 2 }}>{item.videos?.length || 0} tracks</Text>
                  </View>
                  <IconButton icon="delete-outline" size={20} iconColor={theme.colors.error} onPress={() => handleDeletePlaylist(item.id)} />
                </TouchableOpacity>
              )}
            />
          )}

          {/* ── Artists ── */}
          {section === 'artists' && (
            <FlatList
              data={artists}
              keyExtractor={(item) => item.artistId}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.list}
              refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.colors.primary} />}
              ListEmptyComponent={<EmptyState icon="music-circle-outline" message="No followed artists yet." />}
              renderItem={({ item }) => (
                <View style={[styles.playlistRow, { backgroundColor: theme.colors.elevation.level1 }]}>
                  <Image source={{ uri: item.artwork }} style={styles.artistAvatar} contentFit="cover" />
                  <Text style={{ flex: 1, fontWeight: '700', fontSize: 15, marginLeft: 14, color: theme.colors.onSurface }} numberOfLines={1}>{item.name}</Text>
                </View>
              )}
            />
          )}

          {/* ── Albums ── */}
          {section === 'albums' && (
            <FlatList
              data={albums}
              keyExtractor={(item) => item.id}
              numColumns={2}
              showsVerticalScrollIndicator={false}
              contentContainerStyle={styles.albumGrid}
              refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={theme.colors.primary} />}
              ListEmptyComponent={<EmptyState icon="album" message="No saved albums yet." />}
              renderItem={({ item }) => (
                <TouchableOpacity style={styles.albumCard} onPress={() => {
                  if (item.tracks?.length) { setQueue(item.tracks as any); playIndex(0); }
                }}>
                  <Image source={{ uri: item.artwork }} style={styles.albumArt} contentFit="cover" />
                  <Text style={{ fontWeight: '700', marginTop: 8, color: theme.colors.onSurface }} numberOfLines={1}>{item.title}</Text>
                  <Text style={{ fontSize: 12, color: theme.colors.onSurfaceVariant }} numberOfLines={1}>{item.artist}</Text>
                </TouchableOpacity>
              )}
            />
          )}
        </>
      )}

      {section === 'playlists' && (
        <FAB
          icon="plus"
          style={[styles.fab, { backgroundColor: theme.colors.primary, bottom: insets.bottom + 140 }]}
          onPress={handleCreatePlaylist}
          color="#fff"
        />
      )}
    </View>
  );
}

function TrackRow({ track, onPress, rightAction, theme }: any) {
  return (
    <TouchableOpacity style={[styles.trackRow, { backgroundColor: theme.colors.elevation.level1 }]} onPress={onPress}>
      <Image source={{ uri: track.artwork }} style={styles.trackArt} contentFit="cover" />
      <View style={{ flex: 1, marginLeft: 12 }}>
        <Text numberOfLines={1} style={{ fontWeight: '700', fontSize: 14, color: theme.colors.onSurface }}>{track.title}</Text>
        <Text numberOfLines={1} style={{ fontSize: 12, color: theme.colors.onSurfaceVariant, marginTop: 2 }}>{track.artist}</Text>
      </View>
      {rightAction}
    </TouchableOpacity>
  );
}

function EmptyState({ icon, message }: { icon: string; message: string }) {
  return (
    <View style={styles.emptyState}>
      <MaterialCommunityIcons name={icon as any} size={56} color="rgba(255,255,255,0.2)" />
      <Text style={styles.emptyText}>{message}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  header: { paddingHorizontal: 20, marginBottom: 12 },
  title: { fontSize: 34, fontWeight: '800', color: '#fff', letterSpacing: -0.5 },
  tabs: { paddingHorizontal: 16, paddingBottom: 12, gap: 8 },
  chip: { height: 36 },
  list: { paddingHorizontal: 16, paddingBottom: 140, gap: 8 },
  albumGrid: { paddingHorizontal: 8, paddingBottom: 140, gap: 4 },
  playAllBtn: { marginHorizontal: 16, marginBottom: 12, borderRadius: 12, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 12 },
  playlistRow: { flexDirection: 'row', alignItems: 'center', borderRadius: 12, paddingHorizontal: 12, paddingVertical: 10, marginBottom: 8 },
  playlistArt: { width: 52, height: 52, borderRadius: 10, justifyContent: 'center', alignItems: 'center' },
  artistAvatar: { width: 52, height: 52, borderRadius: 26 },
  albumCard: { flex: 1, margin: 8 },
  albumArt: { width: '100%', aspectRatio: 1, borderRadius: 12, backgroundColor: '#333' },
  trackRow: { flexDirection: 'row', alignItems: 'center', borderRadius: 12, paddingLeft: 12, paddingRight: 4, paddingVertical: 8 },
  trackArt: { width: 48, height: 48, borderRadius: 8, backgroundColor: '#333' },
  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingTop: 80, gap: 12 },
  emptyText: { color: 'rgba(255,255,255,0.4)', textAlign: 'center', fontSize: 15 },
  fab: { position: 'absolute', right: 20 },
});
