import React from 'react';
import { StyleSheet, View, Dimensions, TouchableOpacity } from 'react-native';
import { Surface, Text, IconButton, useTheme } from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';
import { Image } from 'expo-image';

import { usePlayerStore } from '../store/usePlayerStore';

const { width } = Dimensions.get('window');

export default function ArchiveTunePlayer() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  
  const { queue, currentTrackIndex, isPlaying, positionMillis, durationMillis, next, previous, setIsPlaying, playIndex } = usePlayerStore();
  const currentTrack = currentTrackIndex >= 0 ? queue[currentTrackIndex] : null;
  const progress = durationMillis > 0 ? positionMillis / durationMillis : 0;
  
  const formatTime = (ms: number) => {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  const albumArtUrl = currentTrack?.artwork || 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=2564&auto=format&fit=crop';

  return (
    <View style={[styles.container, { paddingTop: insets.top + 10, paddingBottom: insets.bottom + 20, backgroundColor: theme.colors.background }]}>
      
      {/* Header */}
      <View style={styles.header}>
        <IconButton icon="chevron-down" size={32} onPress={() => router.back()} />
        <View style={{ flex: 1, alignItems: 'center' }}>
          <Text variant="labelSmall" style={{ color: theme.colors.onSurfaceVariant, fontWeight: '700', letterSpacing: 1 }}>PLAYING FROM LIBRARY (ANDROID)</Text>
        </View>
        <IconButton icon="dots-vertical" size={24} onPress={() => {}} />
      </View>

      {/* Album Art Showcase (Material Design 3 limits blur, uses flat solid elevations heavily) */}
      <View style={styles.artWrapper}>
          <Image source={{ uri: albumArtUrl }} style={styles.albumArtImage} contentFit="cover" transition={200} />
      </View>

      {/* Info constraints */}
      <View style={styles.bottomSection}>
        
        <View style={styles.infoContainer}>
            <View style={{ flex: 1 }}>
                <Text style={[styles.title, { color: theme.colors.onSurface }]} numberOfLines={1}>
                {currentTrack?.title || 'Not Playing'}
                </Text>
                <Text style={[styles.artist, { color: theme.colors.primary }]} numberOfLines={1}>
                {currentTrack?.artist || 'Unknown Artist'}
                </Text>
            </View>
            <IconButton icon="heart-outline" size={26} iconColor={theme.colors.onSurface} onPress={() => {}} />
        </View>

        {/* Progress */}
        <View style={styles.progressContainer}>
          <View style={styles.progressBarWrapper}>
            <View style={[styles.progressBarBase, { backgroundColor: theme.colors.surfaceVariant }]} />
            <View style={[styles.progressBarFill, { width: `${progress * 100}%`, backgroundColor: theme.colors.primary }]} />
            <View style={[styles.progressBarThumb, { left: `${progress * 100}%`, backgroundColor: theme.colors.primary }]} />
          </View>
          <View style={styles.timeRow}>
            <Text style={[styles.timeText, { color: theme.colors.onSurfaceVariant }]}>{formatTime(positionMillis)}</Text>
            <Text style={[styles.timeText, { color: theme.colors.onSurfaceVariant }]}>{formatTime(durationMillis)}</Text>
          </View>
        </View>

        {/* Controls - Elevated Card surface common in Android players */}
        <Surface style={[styles.controlsCard, { backgroundColor: theme.colors.elevation.level2 }]} elevation={2}>
          <IconButton icon="shuffle" size={24} iconColor={theme.colors.onSurfaceVariant} onPress={() => {}} />
          <IconButton icon="skip-previous" size={40} iconColor={theme.colors.onSurface} onPress={previous} />
          <TouchableOpacity 
            onPress={() => {
                if (currentTrackIndex === -1 && queue.length > 0) playIndex(0);
                else setIsPlaying(!isPlaying);
            }} 
            style={[styles.playFab, { backgroundColor: theme.colors.primaryContainer }]}
            activeOpacity={0.8}
          >
            <IconButton icon={isPlaying ? "pause" : "play"} size={40} iconColor={theme.colors.onPrimaryContainer} style={{margin: 0}} />
          </TouchableOpacity>
          <IconButton icon="skip-next" size={40} iconColor={theme.colors.onSurface} onPress={next} />
          <IconButton icon="repeat" size={24} iconColor={theme.colors.onSurfaceVariant} onPress={() => {}} />
        </Surface>
      </View>
      
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'space-between',
    paddingHorizontal: 0,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  artWrapper: {
    flex: 1,
    maxHeight: 400,
    maxWidth: 400,
    width: '100%',
    aspectRatio: 1,
    alignSelf: 'center',
    marginVertical: 'auto',
    paddingHorizontal: 24,
  },
  albumArtImage: {
    width: '100%',
    height: '100%',
    borderRadius: 24,
  },
  bottomSection: {
    width: '100%',
    maxWidth: 600,
    alignSelf: 'center',
    paddingHorizontal: 24,
  },
  infoContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    marginBottom: 4,
  },
  artist: {
    fontSize: 18,
    fontWeight: '600',
  },
  progressContainer: {
    marginBottom: 30,
  },
  progressBarWrapper: {
    height: 48,
    justifyContent: 'center',
    position: 'relative',
  },
  progressBarBase: {
    position: 'absolute',
    height: 8,
    width: '100%',
    borderRadius: 4,
  },
  progressBarFill: {
    position: 'absolute',
    height: 8,
    borderRadius: 4,
  },
  progressBarThumb: {
    position: 'absolute',
    width: 16,
    height: 16,
    borderRadius: 8,
    top: 16,
    transform: [{ translateX: -8 }],
  },
  timeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: -8,
  },
  timeText: {
    fontSize: 12,
    fontWeight: '600',
  },
  controlsCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 24,
  },
  playFab: {
    width: 72,
    height: 72,
    borderRadius: 24, // Squircle shape highly used in M3
    justifyContent: 'center',
    alignItems: 'center',
  }
});
