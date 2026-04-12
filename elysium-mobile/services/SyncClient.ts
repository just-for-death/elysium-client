import { usePlayerStore } from '../store/usePlayerStore';
import { audioService } from './AudioService';

class SyncClient {
  private ws: WebSocket | null = null;
  private deviceCode = 'MOB-' + Math.floor(Math.random() * 1000000); 
  private serverHost = 'http://localhost:3001'; 

  connect(host: string) {
    this.serverHost = host;
    const wsUrl = host.replace('http', 'ws') + '/api/live/ws';
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      this.ws?.send(JSON.stringify({ type: 'register', deviceCode: this.deviceCode }));
    };

    this.ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'remote:control') {
          const state = usePlayerStore.getState();
          if (msg.command === 'play') audioService.resume();
          if (msg.command === 'pause') audioService.pause();
          if (msg.command === 'next') state.next();
          if (msg.command === 'prev') state.previous();
        }
      } catch (err) {}
    };

    // Sub to store changes
    usePlayerStore.subscribe((state, prevState) => {
       // if track or playing changed, broadcast presence
       if (state.currentTrackIndex !== prevState.currentTrackIndex || state.isPlaying !== prevState.isPlaying) {
          const track = state.queue[state.currentTrackIndex];
          if (track) {
            this.broadcastPresence({
               videoId: track.id,
               title: track.title,
               author: track.artist,
               thumbnailUrl: track.artwork,
               paused: !state.isPlaying
            });
          } else {
             this.broadcastPresence(null);
          }
       }
    });
  }

  broadcastPresence(presence: any) {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        type: 'presence:update',
        deviceCode: this.deviceCode,
        linkedCodes: [], // Needs proper pairing logic from main app
        presence
      }));
    }
  }
}

export const syncClient = new SyncClient();
