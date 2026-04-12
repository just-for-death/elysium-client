/**
 * ElysiumApi.ts
 * Typed client for all Elysium server REST APIs.
 * All methods take a serverIp string (e.g. "http://192.168.x.x:3000").
 */

export interface Track {
  id?: string;
  videoId?: string;
  title: string;
  artist: string;
  artwork?: string;
  url?: string;
  duration?: number;
  album?: string;
}

export interface Playlist {
  id: string;
  title: string;
  videos: Track[];
}

export interface Album {
  id: string;
  title: string;
  artist: string;
  artwork?: string;
  year?: number;
  tracks?: Track[];
}

export interface Artist {
  artistId: string;
  name: string;
  artwork?: string;
}

export interface Settings {
  ollamaEnabled: boolean;
  ollamaUrl: string;
  ollamaModel: string;
  listenBrainzToken: string;
  listenBrainzUsername: string;
  highQuality: boolean;
  cacheEnabled: boolean;
  queueMode: string;
  invidiousSid?: string;
  invidiousUsername?: string;
}

export type ScrobblePayload = {
  artist_name: string;
  track_name: string;
  release_name?: string;
};

const lib = (ip: string) => `${ip}/api/v1/library`;

async function api<T>(url: string, opts?: RequestInit): Promise<T> {
  const res = await fetch(url, { headers: { 'Content-Type': 'application/json' }, ...opts });
  if (!res.ok) throw new Error(`API ${res.status}: ${url}`);
  return res.json();
}

// ── Settings ──────────────────────────────────────────────────────────────────
export const getSettings = (ip: string) => api<Settings>(`${lib(ip)}/settings`);
export const updateSettings = (ip: string, data: Partial<Settings>) =>
  api<Settings>(`${lib(ip)}/settings`, { method: 'PUT', body: JSON.stringify(data) });

// ── History ───────────────────────────────────────────────────────────────────
export const getHistory = (ip: string) => api<Track[]>(`${lib(ip)}/history`);
export const addHistory = (ip: string, track: Track) =>
  api<Track[]>(`${lib(ip)}/history`, { method: 'POST', body: JSON.stringify(track) });
export const deleteHistoryItem = (ip: string, id: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/history/${id}`, { method: 'DELETE' });
export const clearHistory = (ip: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/history`, { method: 'DELETE' });

// ── Favorites ─────────────────────────────────────────────────────────────────
export const getFavorites = (ip: string) => api<Track[]>(`${lib(ip)}/favorites`);
export const addFavorite = (ip: string, track: Track) =>
  api<Track[]>(`${lib(ip)}/favorites`, { method: 'POST', body: JSON.stringify(track) });
export const deleteFavorite = (ip: string, id: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/favorites/${id}`, { method: 'DELETE' });

// ── Playlists ─────────────────────────────────────────────────────────────────
export const getPlaylists = (ip: string) => api<Playlist[]>(`${lib(ip)}/playlists`);
export const getPlaylist = (ip: string, id: string) => api<Playlist>(`${lib(ip)}/playlists/${id}`);
export const createPlaylist = (ip: string, data: { title: string }) =>
  api<Playlist>(`${lib(ip)}/playlists`, { method: 'POST', body: JSON.stringify(data) });
export const updatePlaylist = (ip: string, id: string, data: Partial<Playlist>) =>
  api<Playlist>(`${lib(ip)}/playlists/${id}`, { method: 'PUT', body: JSON.stringify(data) });
export const deletePlaylist = (ip: string, id: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/playlists/${id}`, { method: 'DELETE' });

// ── Artists ───────────────────────────────────────────────────────────────────
export const getArtists = (ip: string) => api<Artist[]>(`${lib(ip)}/artists`);
export const addArtist = (ip: string, artist: Artist) =>
  api<Artist[]>(`${lib(ip)}/artists`, { method: 'POST', body: JSON.stringify(artist) });
export const deleteArtist = (ip: string, id: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/artists/${id}`, { method: 'DELETE' });

// ── Albums ────────────────────────────────────────────────────────────────────
export const getAlbums = (ip: string) => api<Album[]>(`${lib(ip)}/albums`);
export const addAlbum = (ip: string, album: Omit<Album, 'id'>) =>
  api<Album>(`${lib(ip)}/albums`, { method: 'POST', body: JSON.stringify(album) });
export const deleteAlbum = (ip: string, id: string) =>
  api<{ ok: boolean }>(`${lib(ip)}/albums/${id}`, { method: 'DELETE' });

// ── AI Queue ──────────────────────────────────────────────────────────────────
export const generateAIQueue = (ip: string, currentSong: Track) =>
  api<{ ok: boolean; track: Track & { reason: string } }>(
    `${lib(ip)}/recommendations/queue`,
    { method: 'POST', body: JSON.stringify({ currentSong }) }
  );

// ── Scrobble ──────────────────────────────────────────────────────────────────
export const scrobble = (ip: string, payload: ScrobblePayload) =>
  api<{ ok: boolean }>(`${ip}/api/v1/scrobble`, {
    method: 'POST',
    body: JSON.stringify({ track_metadata: payload }),
  });

// ── iTunes Proxy ──────────────────────────────────────────────────────────────
export const itunesSearch = (ip: string, term: string, limit = 30) =>
  api<{ results: any[] }>(`${ip}/api/itunes-proxy/search?term=${encodeURIComponent(term)}&entity=song&limit=${limit}`);

export const itunesTopSongs = (ip: string, cc = 'us', limit = 30) =>
  api<any>(`${ip}/api/itunes-proxy/rss/${cc}/topsongs?limit=${limit}`);

// ── Lyrics Proxy (NetEase) ────────────────────────────────────────────────────
export const lyricsSearch = (ip: string, query: string) =>
  api<any>(`${ip}/api/lyrics-proxy/netease/search?s=${encodeURIComponent(query)}&limit=5`);

export const lyricsGet = (ip: string, id: string) =>
  api<any>(`${ip}/api/lyrics-proxy/netease/lyric?id=${id}`);

// ── ListenBrainz Proxy ────────────────────────────────────────────────────────
export const lbRecommendations = (ip: string, username: string, token: string, count = 25) =>
  fetch(`${ip}/api/lb-proxy/recommendations/cf/recording/for_user/${username}?count=${count}`, {
    headers: { 'x-lb-token': token },
  }).then(r => r.json());
