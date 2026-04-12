import { AudioPlayer, setAudioModeAsync } from 'expo-audio';
import { usePlayerStore } from '../store/usePlayerStore';
import { scrobble } from './ElysiumApi';

class AudioService {
  private player: AudioPlayer | null = null;
  private currentTrackId: string | null = null;
  private loadedIndex = -1;
  private finishListener: (() => void) | null = null;

  async configure() {
    await setAudioModeAsync({
      staysActiveInBackground: true,
      playsInSilentModeIOS: true,
    });
  }

  async syncFromStore() {
    const { queue, currentTrackIndex, isPlaying } = usePlayerStore.getState();
    const track = queue[currentTrackIndex];

    if (!track) {
      this.stop();
      return;
    }

    const trackId = track.id || track.videoId || '';

    if (this.loadedIndex !== currentTrackIndex || this.currentTrackId !== trackId) {
      await this.loadTrack(track, trackId, currentTrackIndex);
    } else if (this.player) {
      if (isPlaying && !this.player.playing) this.player.play();
      else if (!isPlaying && this.player.playing) this.player.pause();
    }
  }

  private async loadTrack(track: any, trackId: string, index: number) {
    this.stop(false);

    const url = track.url || (await this.resolveUrl(track));
    if (!url) return;

    try {
      this.player = new AudioPlayer({ uri: url });

      // Listen for playback status updates for progress
      this.player.addListener('playbackStatusUpdate', (status: any) => {
        if (status?.currentTime !== undefined) {
          const posMs = Math.round(status.currentTime * 1000);
          const durMs = Math.round((status.duration || 0) * 1000);
          usePlayerStore.getState().setProgress(posMs, durMs);
        }
        if (status?.didJustFinish) {
          this.handleTrackFinished();
        }
      });

      this.currentTrackId = trackId;
      this.loadedIndex = index;
      this.player.play();
    } catch (e) {
      console.warn('AudioService: Failed to load track', e);
    }
  }

  private resolveUrl = async (track: any): Promise<string | null> => {
    const { serverIp } = usePlayerStore.getState();
    const query = `${track.title} ${track.artist}`;
    try {
      const resp = await fetch(
        `${serverIp}/api/invidious/search?q=${encodeURIComponent(query)}&type=video&page=1`
      );
      if (!resp.ok) return null;
      const results: any[] = await resp.json();
      const videoId = results[0]?.videoId;
      if (!videoId) return null;

      const streamResp = await fetch(`${serverIp}/api/invidious/videos/${videoId}`);
      if (!streamResp.ok) return null;
      const video = await streamResp.json();

      const settings = await fetch(`${serverIp}/api/v1/library/settings`).then(r => r.json()).catch(() => ({}));
      const highQuality = settings?.highQuality ?? false;

      const streams: any[] = video.adaptiveFormats || [];
      const audioStreams = streams
        .filter(s => s.type?.startsWith('audio'))
        .sort((a, b) => highQuality ? b.bitrate - a.bitrate : a.bitrate - b.bitrate);
      return audioStreams[0]?.url || null;
    } catch {
      return null;
    }
  };

  private handleTrackFinished() {
    const { queue, currentTrackIndex, serverIp } = usePlayerStore.getState();
    const track = queue[currentTrackIndex];

    if (track && serverIp) {
      scrobble(serverIp, { artist_name: track.artist, track_name: track.title }).catch(() => {});
    }

    usePlayerStore.getState().next();
  }

  stop(updateStore = true) {
    if (this.player) {
      try { this.player.pause(); } catch {}
      try { this.player.remove(); } catch {}
      this.player = null;
    }
    this.currentTrackId = null;
    this.loadedIndex = -1;
    if (updateStore) {
      usePlayerStore.getState().setIsPlaying(false);
    }
  }

  async seek(positionSeconds: number) {
    if (this.player) {
      this.player.seekTo(positionSeconds);
    }
  }
}

export const audioService = new AudioService();

// Subscribe to store changes
let prevIndex = -1;
let prevIsPlaying = false;

usePlayerStore.subscribe((state) => {
  const { currentTrackIndex, isPlaying } = state;
  if (currentTrackIndex !== prevIndex || isPlaying !== prevIsPlaying) {
    prevIndex = currentTrackIndex;
    prevIsPlaying = isPlaying;
    audioService.syncFromStore().catch(console.warn);
  }
});

// Initialize on import
audioService.configure().catch(console.warn);
