import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import AsyncStorage from '@react-native-async-storage/async-storage';

export interface Track {
  id: string;
  url: string;
  title: string;
  artist: string;
  artwork?: string;
  duration?: number;
  album?: string;
  videoId?: string;
}

export type RepeatMode = 'off' | 'all' | 'one';

interface PlayerState {
  serverIp: string;
  setServerIp: (ip: string) => void;

  queue: Track[];
  currentTrackIndex: number;
  isPlaying: boolean;
  positionMillis: number;
  durationMillis: number;

  repeatMode: RepeatMode;
  shuffled: boolean;
  setRepeatMode: (mode: RepeatMode) => void;
  toggleShuffle: () => void;

  // Actions
  setQueue: (tracks: Track[]) => void;
  playIndex: (index: number) => void;
  setIsPlaying: (isPlaying: boolean) => void;
  setProgress: (positionMillis: number, durationMillis: number) => void;
  next: () => void;
  previous: () => void;

  // Favorites (in-memory cache synced from server)
  favorites: Track[];
  setFavorites: (favs: Track[]) => void;
  isFavorite: (id: string) => boolean;
}

export const usePlayerStore = create<PlayerState>()(
  persist(
    (set, get) => ({
      serverIp: 'http://192.168.1.100:3000',
      setServerIp: (ip) => set({ serverIp: ip }),

      queue: [],
      currentTrackIndex: -1,
      isPlaying: false,
      positionMillis: 0,
      durationMillis: 0,

      repeatMode: 'off',
      shuffled: false,
      setRepeatMode: (mode) => set({ repeatMode: mode }),
      toggleShuffle: () => set((s) => ({ shuffled: !s.shuffled })),

      setQueue: (tracks) => set({ queue: tracks }),

      playIndex: (index) =>
        set((state) => {
          if (index >= 0 && index < state.queue.length) {
            return { currentTrackIndex: index, isPlaying: true, positionMillis: 0 };
          }
          return state;
        }),

      setIsPlaying: (isPlaying) => set({ isPlaying }),

      setProgress: (positionMillis, durationMillis) => set({ positionMillis, durationMillis }),

      next: () =>
        set((state) => {
          if (state.queue.length === 0) return state;
          let nextIndex: number;
          if (state.repeatMode === 'one') {
            nextIndex = state.currentTrackIndex;
          } else {
            nextIndex = state.currentTrackIndex + 1;
            if (nextIndex >= state.queue.length) {
              if (state.repeatMode === 'all') nextIndex = 0;
              else return { ...state, isPlaying: false };
            }
          }
          return { currentTrackIndex: nextIndex, isPlaying: true, positionMillis: 0 };
        }),

      previous: () =>
        set((state) => {
          if (state.queue.length === 0) return state;
          // If more than 3 seconds in, restart; else go to previous track
          if (state.positionMillis > 3000) {
            return { positionMillis: 0 }; // AudioService will seek on this
          }
          let prevIndex = state.currentTrackIndex - 1;
          if (prevIndex < 0) prevIndex = state.queue.length - 1;
          return { currentTrackIndex: prevIndex, isPlaying: true, positionMillis: 0 };
        }),

      favorites: [],
      setFavorites: (favs) => set({ favorites: favs }),
      isFavorite: (id) => {
        const favs = get().favorites;
        return favs.some((f) => f.id === id || f.videoId === id);
      },
    }),
    {
      name: 'elysium-player-storage',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({
        serverIp: state.serverIp,
        queue: state.queue,
        currentTrackIndex: state.currentTrackIndex,
        repeatMode: state.repeatMode,
        shuffled: state.shuffled,
      }),
    }
  )
);
