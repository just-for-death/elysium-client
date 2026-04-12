import React from 'react';
import { View, StyleSheet, TouchableOpacity } from 'react-native';
import { Text, useTheme, ProgressBar } from 'react-native-paper';
import { router } from 'expo-router';
import { Image } from 'expo-image';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { usePlayerStore } from '../store/usePlayerStore';

export default function MiniPlayer() {
  const theme = useTheme();
  const { queue, currentTrackIndex, isPlaying, playIndex, setIsPlaying, positionMillis, durationMillis, next } = usePlayerStore();

  const currentTrack = currentTrackIndex >= 0 ? queue[currentTrackIndex] : null;
  if (!currentTrack) return null;

  const progress = durationMillis > 0 ? positionMillis / durationMillis : 0;

  const togglePlayback = (e: any) => {
    e.stopPropagation();
    if (currentTrackIndex === -1 && queue.length > 0) playIndex(0);
    else setIsPlaying(!isPlaying);
  };

  return (
    <TouchableOpacity
      style={[styles.container, { backgroundColor: theme.colors.elevation.level3 }]}
      onPress={() => router.push('/player' as any)}
      activeOpacity={0.92}
    >
      <View style={styles.row}>
        {/* Artwork */}
        <Image
          source={{ uri: currentTrack.artwork || 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=200&auto=format&fit=crop' }}
          style={styles.artwork}
          contentFit="cover"
          transition={200}
        />

        {/* Track Info */}
        <View style={styles.info}>
          <Text style={[styles.title, { color: theme.colors.onSurface }]} numberOfLines={1}>{currentTrack.title}</Text>
          <Text style={[styles.artist, { color: theme.colors.onSurfaceVariant }]} numberOfLines={1}>{currentTrack.artist}</Text>
        </View>

        {/* Play/Pause */}
        <TouchableOpacity onPress={togglePlayback} style={styles.btn} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <MaterialCommunityIcons name={isPlaying ? 'pause' : 'play'} size={30} color={theme.colors.onSurface} />
        </TouchableOpacity>

        {/* Next */}
        <TouchableOpacity onPress={(e) => { e.stopPropagation(); next(); }} style={styles.btn} hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}>
          <MaterialCommunityIcons name="skip-next" size={28} color={theme.colors.onSurface} />
        </TouchableOpacity>
      </View>

      {/* Progress bar */}
      <ProgressBar progress={progress} color={theme.colors.primary} style={styles.progress} />
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    marginHorizontal: 8,
    marginBottom: 8,
    borderRadius: 12,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 8,
    gap: 8,
  },
  artwork: {
    width: 46,
    height: 46,
    borderRadius: 8,
    backgroundColor: '#333',
  },
  info: {
    flex: 1,
    justifyContent: 'center',
  },
  title: {
    fontSize: 14,
    fontWeight: '700',
  },
  artist: {
    fontSize: 12,
    marginTop: 2,
    opacity: 0.8,
  },
  btn: {
    padding: 2,
  },
  progress: {
    height: 2,
    backgroundColor: 'rgba(255,255,255,0.08)',
  },
});
