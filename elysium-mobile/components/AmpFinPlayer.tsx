import React from 'react';
import { StyleSheet, View, ImageBackground, Platform, Dimensions, TouchableOpacity } from 'react-native';
import { Surface, Text, IconButton, ProgressBar, useTheme } from 'react-native-paper';
import { BlurView } from 'expo-blur';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { router } from 'expo-router';

import { usePlayerStore } from '../store/usePlayerStore';

const { width } = Dimensions.get('window');

export default function AmpFinPlayer() {
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
    <ImageBackground 
      source={{ uri: albumArtUrl }}
      style={styles.background}
      blurRadius={Platform.OS === 'android' ? 60 : 0} 
    >
      <BlurView 
        style={styles.glassContainer} 
        tint={theme.dark ? 'dark' : 'regular'} 
        intensity={Platform.OS === 'ios' ? 95 : 120}
        experimentalBlurMethod="dimezisBlurView"
      >
        <View style={[styles.content, { paddingTop: insets.top + 10, paddingBottom: insets.bottom + 20 }]}>
          
          {/* Header */}
          <View style={styles.header}>
            <IconButton icon="chevron-down" size={30} iconColor={theme.colors.onSurface} onPress={() => { router.back(); }} />
            <Text style={[styles.headerTitle, { color: theme.colors.onSurface }]}>Elysium (iOS UI)</Text>
            <IconButton icon="dots-horizontal" size={24} iconColor={theme.colors.onSurface} onPress={() => {}} />
          </View>

          {/* Album Art Showcase (AmpFin Style - Massive and bold) */}
          <Surface style={styles.albumArtContainer} elevation={5}>
            <ImageBackground source={{ uri: albumArtUrl }} style={styles.albumArt} imageStyle={styles.albumArtImage} />
          </Surface>

          {/* Bottom Control Section */}
          <View style={styles.bottomSection}>
            
            {/* Song Info */}
            <View style={styles.infoContainer}>
              <View style={{ flex: 1 }}>
                <Text style={[styles.title, { color: theme.colors.onSurface }]} numberOfLines={1}>
                  {currentTrack?.title || 'Not Playing'}
                </Text>
                <Text style={[styles.artist, { color: theme.colors.onSurfaceVariant }]} numberOfLines={1}>
                  {currentTrack?.artist || 'Unknown Artist'}
                </Text>
              </View>
              <IconButton icon="heart-outline" size={28} iconColor={theme.colors.onSurface} onPress={() => {}} />
            </View>

            {/* Progress */}
            <View style={styles.progressContainer}>
              <ProgressBar progress={progress} color={theme.colors.onSurface} style={styles.progressBar} />
              <View style={styles.timeRow}>
                <Text style={[styles.timeText, { color: theme.colors.onSurfaceVariant }]}>{formatTime(positionMillis)}</Text>
                <Text style={[styles.timeText, { color: theme.colors.onSurfaceVariant }]}>-{formatTime(durationMillis - positionMillis)}</Text>
              </View>
            </View>

            {/* Controls */}
            <View style={styles.controlsContainer}>
              <IconButton icon="shuffle" size={26} iconColor={theme.colors.onSurfaceVariant} onPress={() => {}} />
              
              <IconButton icon="skip-previous" size={48} iconColor={theme.colors.onSurface} onPress={previous} />
              
              <TouchableOpacity
                onPress={() => {
                  if (currentTrackIndex === -1 && queue.length > 0) playIndex(0);
                  else setIsPlaying(!isPlaying);
                }}
                style={[styles.playButton, { backgroundColor: theme.colors.onSurface }]}
              >
                <IconButton 
                  icon={isPlaying ? "pause" : "play"} 
                  size={42} 
                  iconColor={theme.colors.surface} 
                  style={{ margin: 0 }}
                />
              </TouchableOpacity>
              
              <IconButton icon="skip-next" size={48} iconColor={theme.colors.onSurface} onPress={next} />
              
              <IconButton icon="repeat" size={26} iconColor={theme.colors.onSurfaceVariant} onPress={() => {}} />
            </View>
          </View>
          
        </View>
      </BlurView>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  background: {
    flex: 1,
    backgroundColor: '#050505',
  },
  glassContainer: {
    flex: 1,
  },
  content: {
    flex: 1,
    justifyContent: 'space-between',
    maxWidth: 800,
    width: '100%',
    alignSelf: 'center',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  headerTitle: {
    fontSize: 14,
    fontWeight: '700',
    letterSpacing: 1,
    textTransform: 'uppercase',
    opacity: 0.8,
  },
  albumArtContainer: {
    width: '100%',
    maxWidth: 420,
    maxHeight: 420,
    aspectRatio: 1,
    borderRadius: 16,
    alignSelf: 'center',
    backgroundColor: 'transparent',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 20 },
    shadowOpacity: 0.35,
    shadowRadius: 25,
    marginVertical: 'auto',
  },
  albumArt: {
    width: '100%',
    height: '100%',
  },
  albumArtImage: {
    borderRadius: 16,
  },
  bottomSection: {
    paddingHorizontal: 0,
    width: '100%',
    maxWidth: 600,
    alignSelf: 'center',
    marginBottom: Platform.OS === 'web' ? 40 : 10,
  },
  infoContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 30,
    paddingHorizontal: 30,
  },
  title: {
    fontSize: 26,
    fontWeight: '800',
    marginBottom: 4,
  },
  artist: {
    fontSize: 18,
    fontWeight: '500',
    opacity: 0.8,
  },
  progressContainer: {
    marginBottom: 35,
    paddingHorizontal: 30,
  },
  progressBar: {
    height: 6,
    borderRadius: 3,
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
  timeRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 10,
  },
  timeText: {
    fontSize: 12,
    fontWeight: '600',
    opacity: 0.8,
  },
  controlsContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 30,
  },
  playButton: {
    width: 76,
    height: 76,
    borderRadius: 38,
    justifyContent: 'center',
    alignItems: 'center',
  },
});
