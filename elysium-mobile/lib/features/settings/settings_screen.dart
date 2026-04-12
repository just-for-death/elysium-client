import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/elysium_api.dart';
import '../../core/models/models.dart';
import '../../core/models/track.dart';
import '../../core/store/providers.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverIp = ref.watch(serverIpProvider);
    final settings = ref.watch(settingsProvider);
    final api = useMemoized(() => ElysiumApi(serverIp, apiSecret: settings?.apiSecret ?? ''), [serverIp, settings?.apiSecret]);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final serverCtrl = useTextEditingController(text: serverIp);
    final saving = useState(false);

    // Server-side settings controllers
    final lbTokenCtrl = useTextEditingController();
    final lbUserCtrl = useTextEditingController();
    final ollamaUrlCtrl = useTextEditingController();
    final ollamaModelCtrl = useTextEditingController();
    final invidiousInstanceCtrl = useTextEditingController();
    final lastFmKeyCtrl = useTextEditingController();
    final apiSecretCtrl = useTextEditingController();

    // Login controllers
    final invUserCtrl = useTextEditingController();
    final invPassCtrl = useTextEditingController();

    // Playlist sync state
    final invPlaylists = useState<List<dynamic>?>(null);
    final lbPlaylists = useState<List<dynamic>?>(null);
    final plLoading = useState(false);
    final lbLoading = useState(false);

    // Sync controllers with remote state
    useEffect(() {
      if (settings != null) {
        lbTokenCtrl.text = settings.listenBrainzToken;
        lbUserCtrl.text = settings.listenBrainzUsername ?? '';
        ollamaUrlCtrl.text = settings.ollamaUrl;
        ollamaModelCtrl.text = settings.ollamaModel;
        invidiousInstanceCtrl.text = settings.invidiousInstance;
        lastFmKeyCtrl.text = settings.lastFmApiKey;
        apiSecretCtrl.text = settings.apiSecret;
      }
      return null;
    }, [settings]);

    Future<void> loadInvidiousPlaylists() async {
      if (settings?.invidiousUsername == null) return;
      plLoading.value = true;
      try {
        final data = await api.getInvidiousPlaylists(
          instanceUrl: settings!.invidiousInstance,
          sid: settings.invidiousSid,
        );
        invPlaylists.value = data;
      } catch (_) {
        invPlaylists.value = [];
      } finally {
        plLoading.value = false;
      }
    }

    Future<void> loadListenBrainzPlaylists() async {
      if (settings?.listenBrainzUsername == null) return;
      lbLoading.value = true;
      try {
        final data = await api.getListenBrainzPlaylists();
        lbPlaylists.value = data;
      } catch (_) {
        lbPlaylists.value = [];
      } finally {
        lbLoading.value = false;
      }
    }

    useEffect(() {
      if (settings != null) {
        loadInvidiousPlaylists();
        loadListenBrainzPlaylists();
      }
      return null;
    }, [settings?.invidiousSid, settings?.listenBrainzUsername]);

    Future<void> saveServerSettings() async {
      if (settings == null) return;
      saving.value = true;
      try {
        final instance = invidiousInstanceCtrl.text.trim();
        final sanitizedInstance = instance.isNotEmpty ? Uri.parse(instance).origin : '';

        await ref.read(settingsProvider.notifier).update({
          ...settings.toJson(),
          'listenBrainzToken': lbTokenCtrl.text.trim(),
          'listenBrainzUsername': lbUserCtrl.text.trim(),
          'ollamaUrl': ollamaUrlCtrl.text.trim(),
          'ollamaModel': ollamaModelCtrl.text.trim(),
          'invidiousInstance': sanitizedInstance,
          'lastFmApiKey': lastFmKeyCtrl.text.trim(),
          'apiSecret': apiSecretCtrl.text.trim(),
        });
        
        // Auto-validate LB if token changed
        if (lbTokenCtrl.text.trim().isNotEmpty && lbTokenCtrl.text.trim() != settings.listenBrainzToken) {
          try {
            final lb = await api.validateListenBrainzToken(lbTokenCtrl.text.trim());
            if (lb['username'] != null) {
              await ref.read(settingsProvider.notifier).update({'listenBrainzUsername': lb['username']});
            }
          } catch (_) {}
        }

        // Auto-validate Last.fm
        if (lastFmKeyCtrl.text.trim().isNotEmpty) {
          try {
            await api.validateLastFmKey(lastFmKeyCtrl.text.trim());
          } catch (_) {}
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All settings synced to server ✓')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e')),
          );
        }
      } finally {
        saving.value = false;
      }
    }

    void showListenBrainzPlaylistPreview(String mbid, String title) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => HookConsumer(
          builder: (context, ref, _) {
            final pvLoading = useState(true);
            final pvPlaylist = useState<Playlist?>(null);

            useEffect(() {
              api.getListenBrainzPlaylistDetail(mbid).then((p) {
                pvPlaylist.value = p;
                pvLoading.value = false;
              }).catchError((e) {
                pvLoading.value = false;
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              });
              return null;
            }, []);

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: pvLoading.value 
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: pvPlaylist.value?.videos.length ?? 0,
                            itemBuilder: (context, i) {
                              final t = pvPlaylist.value!.videos[i];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(color: Colors.white12, width: 44, height: 44, child: const Icon(Icons.music_note_rounded)),
                                ),
                                title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
                                subtitle: Text(t.artist, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                onTap: () => ref.read(playerProvider.notifier).playTrackNow(t),
                              );
                            },
                          ),
                    ),
                    if (!pvLoading.value && pvPlaylist.value != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.cloud_download_rounded),
                            label: const Text('Import to Elysium Library'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await api.importListenBrainzPlaylist(mbid);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playlist imported to library ✓')));
                                }
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    void showTrackMenu(Track track) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151515) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(track.artwork ?? '', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white12, child: const Icon(Icons.music_note_rounded))),
                ),
                title: Text(track.title, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(track.artist, style: const TextStyle(fontSize: 12, color: Colors.white54), maxLines: 1),
              ),
              const Divider(color: Colors.white10),
              ListTile(leading: const Icon(Icons.playlist_play_rounded), title: const Text('Play Next'), onTap: () { ref.read(playerProvider.notifier).playNext(track); Navigator.pop(ctx); }),
              ListTile(leading: const Icon(Icons.queue_music_rounded), title: const Text('Add to Queue'), onTap: () { ref.read(playerProvider.notifier).addToQueue(track); Navigator.pop(ctx); }),
              ListTile(leading: const Icon(Icons.playlist_add_rounded), title: const Text('Add to Playlist'), onTap: () { /* TODO: Local Playlist selection */ Navigator.pop(ctx); }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    }

    void showPlaylistPreview(String id, String title) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => HookConsumer(
          builder: (context, ref, _) {
            final pvLoading = useState(true);
            final pvPlaylist = useState<Playlist?>(null);

            useEffect(() {
              api.getInvidiousPlaylistDetail(id, 
                instanceUrl: settings.value!.invidiousInstance, 
                sid: settings.value?.invidiousSid
              ).then((p) {
                pvPlaylist.value = p;
                pvLoading.value = false;
              }).catchError((e) {
                pvLoading.value = false;
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              });
              return null;
            }, []);

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (!pvLoading.value && pvPlaylist.value != null) ...[
                            IconButton(
                              icon: const Icon(Icons.play_circle_fill_rounded, size: 32, color: Colors.white),
                              onPressed: () => ref.read(playerProvider.notifier).playAll(pvPlaylist.value!.videos),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_to_photos_rounded),
                              onPressed: () => ref.read(playerProvider.notifier).addAllToQueue(pvPlaylist.value!.videos),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: pvLoading.value 
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: pvPlaylist.value?.videos.length ?? 0,
                            itemBuilder: (context, i) {
                              final t = pvPlaylist.value!.videos[i];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(t.artwork ?? '', width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white12, child: const Icon(Icons.music_note_rounded))),
                                ),
                                title: Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1),
                                subtitle: Text(t.artist, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                trailing: IconButton(icon: const Icon(Icons.more_vert_rounded, size: 20), onPressed: () => showTrackMenu(t)),
                                onTap: () => ref.read(playerProvider.notifier).playTrackNow(t),
                              );
                            },
                          ),
                    ),
                    if (!pvLoading.value && pvPlaylist.value != null)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Sync Entire Playlist to Library'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                await api.syncInvidiousPlaylist(id, instanceUrl: settings.value!.invidiousInstance, sid: settings.value?.invidiousSid);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing to Library...')));
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }
        ),
      );
    }

    Future<void> loginToInvidious() async {
      if (settings == null) return;
      final instance = invidiousInstanceCtrl.text.trim();
      if (instance.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an Invidious Instance URL first')),
        );
        return;
      }
      
      final sanitizedInstance = Uri.parse(instance).origin;
      invidiousInstanceCtrl.text = sanitizedInstance;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          title: const Text('Log in to Invidious'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StyledTextField(controller: invUserCtrl, hint: 'Username', isDark: isDark, cs: cs),
              const SizedBox(height: 12),
              _StyledTextField(controller: invPassCtrl, hint: 'Password', isDark: isDark, cs: cs, obscure: true),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = invUserCtrl.text;
                final pass = invPassCtrl.text;
                Navigator.pop(ctx);
                saving.value = true;
                try {
                  final res = await api.invidiousLogin(instance, user, pass);
                  if (res['sid'] != null) {
                    await ref.read(settingsProvider.notifier).update({
                      'invidiousSid': res['sid'],
                      'invidiousUsername': user,
                      'invidiousInstance': sanitizedInstance,
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
                  }
                } finally {
                  saving.value = false;
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    return PremiumBackground(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Universal platform configuration',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (settings != null) ...[
              // ── SECURITY & CONNECTION ──────────────────────────────────
              _SectionHeader(label: 'Security & Connectivity', icon: Icons.security_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: Colors.tealAccent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('ELSYIUM SERVER IP', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(
                        controller: serverCtrl, 
                        hint: 'e.g. 192.168.1.10:3000', 
                        isDark: isDark, 
                        cs: cs,
                        onChanged: (v) => ref.read(serverIpProvider.notifier).state = v.trim(),
                      ),
                      const SizedBox(height: 16),
                      _SettingsLabel('API SECRET', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(
                        controller: apiSecretCtrl, 
                        hint: 'Required if your server is protected', 
                        isDark: isDark, 
                        cs: cs, 
                        obscure: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This must match the API_SECRET on your server.',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ),

              // ── AUTO QUEUE ───────────────────────────────────────────────
              _SectionHeader(label: 'Smart Queue', icon: Icons.auto_awesome_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: cs.primary,
                  child: Column(
                    children: [
                      _SwitchTile(
                        label: 'Auto Queue',
                        subtitle: 'Automatically queue the next track when one is about to end',
                        value: settings.ollamaEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).update({'ollamaEnabled': v});
                        },
                      ),
                      if (settings.ollamaEnabled) ...[
                        const SizedBox(height: 16),
                        _SettingsLabel('QUEUE MODE', cs),
                        const SizedBox(height: 8),
                        _QueueModeSelector(
                          currentMode: settings.queueMode,
                          isDark: isDark,
                          cs: cs,
                          onChanged: (mode) {
                            ref.read(settingsProvider.notifier).update({'queueMode': mode});
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── OLLAMA ENGINE ───────────────────────────────────────────
              if (settings.value!.queueMode == 'my_taste') ...[
                _SectionHeader(label: 'AI Engine', icon: Icons.memory_rounded, isDark: isDark, cs: cs),
                SliverToBoxAdapter(
                  child: _SettingsCard(
                    isDark: isDark,
                    cs: cs,
                    accent: Colors.blueAccent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SettingsLabel('OLLAMA URL', cs),
                        const SizedBox(height: 8),
                        _StyledTextField(controller: ollamaUrlCtrl, hint: 'http://localhost:11434', isDark: isDark, cs: cs),
                        const SizedBox(height: 14),
                        _SettingsLabel('MODEL', cs),
                        const SizedBox(height: 8),
                        _StyledTextField(controller: ollamaModelCtrl, hint: 'llama3', isDark: isDark, cs: cs),
                      ],
                    ),
                  ),
                ),
              ],

              // ── LAST.FM ───────────────────────────────────────────────────
              _SectionHeader(label: 'Scrobbling Plugin', icon: Icons.sensors_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: const Color(0xFFD41113), // Last.fm Red
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _SettingsLabel('API KEY (OPTIONAL FALLBACK)', cs)),
                          if (settings.value!.lastFmApiKey.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                              child: const Text('STATUS: CONNECTED', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _StyledTextField(controller: lastFmKeyCtrl, hint: 'Paste your Last.fm API key', isDark: isDark, cs: cs, obscure: true),
                      const SizedBox(height: 4),
                      Text(
                        'Required for "Similar" mode. Get one at last.fm/api',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ),

              // ── INVIDIOUS ───────────────────────────────────────────────────
              _SectionHeader(label: 'Video Account', icon: Icons.video_library_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: Colors.red,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('INSTANCE URL', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(controller: invidiousInstanceCtrl, hint: 'https://invidious.io', isDark: isDark, cs: cs),
                      const SizedBox(height: 12),
                      _InvidiousStatusCard(
                        isLoggedIn: settings.value!.invidiousUsername != null,
                        username: settings.value!.invidiousUsername,
                        instanceUrl: settings.value!.invidiousInstance,
                        isDark: isDark,
                        cs: cs,
                        onLogin: loginToInvidious,
                      ),
                      if (settings.value!.invidiousUsername != null) ...[
                        const SizedBox(height: 20),
                        _SettingsLabel('YOUTUBE PLAYLISTS', cs),
                        const SizedBox(height: 8),
                        if (plLoading.value)
                          const Center(child: Padding(padding: EdgeInsets.all(12.0), child: LinearProgressIndicator()))
                        else if (invPlaylists.value == null || invPlaylists.value!.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No playlists found', style: TextStyle(color: Colors.white24, fontSize: 13))))
                        else
                          ...invPlaylists.value!.map((pl) => _PlaylistSyncTile(
                            title: pl['title'] ?? 'Playlist',
                            count: pl['videoCount'] ?? 0,
                            isDark: isDark,
                            cs: cs,
                            onSync: () async {
                              final sc = ScaffoldMessenger.of(context);
                              try {
                                await api.syncInvidiousPlaylist(pl['playlistId'], instanceUrl: settings.value!.invidiousInstance, sid: settings.value?.invidiousSid);
                                sc.showSnackBar(const SnackBar(content: Text('Playlist synced to Library ✓')));
                              } catch (e) {
                                sc.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                              }
                            },
                            onTap: () => showPlaylistPreview(pl['playlistId'], pl['title'] ?? 'Playlist'),
                          )),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: TextButton.icon(icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh List'), onPressed: loadInvidiousPlaylists)),
                      ],
                    ],
                  ),
                ),
              ),

              // ── SCROBBLING ─────────────────────────────────────
              _SectionHeader(label: 'Music Social', icon: Icons.album_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: const Color(0xFFEB743B), // ListenBrainz Orange
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('LISTENBRAINZ TOKEN', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(controller: lbTokenCtrl, hint: 'Paste token here', isDark: isDark, cs: cs, obscure: true),
                      const SizedBox(height: 14),
                      _SettingsLabel('USERNAME (AUTO-DETECTED)', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(controller: lbUserCtrl, hint: 'your_username', isDark: isDark, cs: cs),

                      if (settings.value!.listenBrainzUsername != null && settings.value!.listenBrainzUsername!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _SettingsLabel('LISTENBRAINZ TOOLS', cs),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ToolButton(
                                label: 'Sync to LB',
                                icon: Icons.cloud_upload_rounded,
                                isDark: isDark,
                                cs: cs,
                                onTap: () async {
                                  final sc = ScaffoldMessenger.of(context);
                                  sc.showSnackBar(const SnackBar(content: Text('Fetching local playlists...')));
                                  try {
                                    final localPl = await api.getPlaylists();
                                    if (localPl.isEmpty) {
                                      sc.showSnackBar(const SnackBar(content: Text('No local playlists to sync')));
                                      return;
                                    }
                                    sc.showSnackBar(SnackBar(content: Text('Starting sync of ${localPl.length} playlists...')));
                                    int success = 0;
                                    for (final p in localPl) {
                                      try {
                                        await api.syncPlaylistToListenBrainz(p.id);
                                        success++;
                                      } catch (_) {}
                                    }
                                    sc.showSnackBar(SnackBar(content: Text('Synced $success playlists to ListenBrainz ✓')));
                                  } catch (e) {
                                    sc.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ToolButton(
                                label: 'Bulk Scrobble',
                                icon: Icons.history_edu_rounded,
                                isDark: isDark,
                                cs: cs,
                                onTap: () async {
                                  final sc = ScaffoldMessenger.of(context);
                                  sc.showSnackBar(const SnackBar(content: Text('Fetching history...')));
                                  try {
                                    final history = await api.getHistory();
                                    if (history.isEmpty) {
                                      sc.showSnackBar(const SnackBar(content: Text('History is empty')));
                                      return;
                                    }
                                    sc.showSnackBar(const SnackBar(content: Text('Importing history to ListenBrainz...')));
                                    await api.bulkScrobble(history);
                                    sc.showSnackBar(const SnackBar(content: Text('History scrobbled successfully ✓')));
                                  } catch (e) {
                                    sc.showSnackBar(SnackBar(content: Text('Bulk scrobble failed: $e')));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _SettingsLabel('LISTENBRAINZ PLAYLISTS', cs),
                        const SizedBox(height: 8),
                        if (lbLoading.value)
                          const Center(child: Padding(padding: EdgeInsets.all(12.0), child: LinearProgressIndicator()))
                        else if (lbPlaylists.value == null || lbPlaylists.value!.isEmpty)
                          const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No LB playlists found', style: TextStyle(color: Colors.white24, fontSize: 13))))
                        else
                          ...lbPlaylists.value!.map((pl) => _PlaylistSyncTile(
                            title: pl['title'] ?? 'Playlist',
                            count: pl['track_count'] ?? 0,
                            isDark: isDark,
                            cs: cs,
                            onSync: () async {
                               final sc = ScaffoldMessenger.of(context);
                               sc.showSnackBar(const SnackBar(content: Text('Syncing to Library...')));
                               try {
                                 await api.importListenBrainzPlaylist(pl['playlist_mbid']);
                                 sc.showSnackBar(const SnackBar(content: Text('Synced to Library ✓')));
                               } catch (e) {
                                 sc.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                               }
                            },
                            onTap: () => showListenBrainzPlaylistPreview(pl['playlist_mbid'], pl['title'] ?? 'Playlist'), 
                          )),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, child: TextButton.icon(icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh LB List'), onPressed: loadListenBrainzPlaylists)),
                      ],
                    ],
                  ),
                ),
              ),

              // ── PLAYER ───────────────────────────────────────────────────
              _SectionHeader(label: 'Experience', icon: Icons.tune_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    children: [
                      _SwitchTile(
                        label: 'High Quality Audio',
                        subtitle: 'Stream higher bitrate when available',
                        value: settings.highQuality,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).update({'highQuality': v});
                        },
                      ),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                      _SwitchTile(
                        label: 'Cache Audio',
                        subtitle: 'Save tracks for offline listening',
                        value: settings.cacheEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).update({'cacheEnabled': v});
                        },
                      ),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
                      _SwitchTile(
                        label: 'Video Mode',
                        subtitle: 'Prefer high-quality video playback',
                        value: settings.videoMode,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          ref.read(settingsProvider.notifier).update({'videoMode': v});
                          ref.read(playerProvider.notifier).fetchSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── SYSTEM ───────────────────────────────────────────────────
              _SectionHeader(label: 'Connection', icon: Icons.dns_rounded, isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  accent: cs.secondary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('SERVER URL', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(controller: serverCtrl, hint: 'http://192.168.x.x:7771', isDark: isDark, cs: cs),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.sync_rounded),
                          label: const Text('Reconnect'),
                          style: ElevatedButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () {
                            final url = serverCtrl.text.trim();
                            if (url.isNotEmpty) ref.read(serverIpProvider.notifier).update(url);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 60),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 8,
                      shadowColor: cs.primary.withValues(alpha: 0.2),
                    ),
                    onPressed: saving.value ? null : saveServerSettings,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (saving.value)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        else
                           Icon(Icons.bolt_rounded, size: 20, color: isDark ? Colors.black : Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          saving.value ? 'SYNCING CONFIG...' : 'APPLY CLOUD SETTINGS',
                          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      if (loading.value) 
                        CircularProgressIndicator(color: cs.primary)
                      else if (errorMsg.value != null) ...[
                        Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                        const SizedBox(height: 16),
                        Text(
                          errorMsg.value!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => loadSettings(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.errorContainer,
                            foregroundColor: cs.onErrorContainer,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text('Unable to connect to server.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                      ],
                      const SizedBox(height: 32),
                      _SettingsCard(
                        isDark: isDark,
                        cs: cs,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SettingsLabel('SERVER URL', cs),
                            const SizedBox(height: 8),
                            _StyledTextField(controller: serverCtrl, hint: 'http://192.168.x.x:7771', isDark: isDark, cs: cs),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.sync_rounded),
                                label: const Text('Connect'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cs.primary, 
                                  foregroundColor: cs.onPrimary, 
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                                  padding: const EdgeInsets.symmetric(vertical: 14)
                                ),
                                onPressed: () {
                                  final url = serverCtrl.text.trim();
                                  if (url.isNotEmpty) ref.read(serverIpProvider.notifier).update(url);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

class _QueueModeSelector extends StatelessWidget {
  const _QueueModeSelector({
    required this.currentMode,
    required this.isDark,
    required this.cs,
    required this.onChanged,
  });

  final String currentMode;
  final bool isDark;
  final ColorScheme cs;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModeButton(
          id: 'discover',
          title: 'Discover',
          subtitle: 'Random new music from iTunes & ListenBrainz',
          icon: Icons.explore_rounded,
          isActive: currentMode == 'discover' || currentMode == 'off',
          onTap: () => onChanged('discover'),
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(height: 8),
        _ModeButton(
          id: 'similar',
          title: 'Similar',
          subtitle: 'Same artist - same vibe via Last.fm',
          icon: Icons.linear_scale_rounded,
          isActive: currentMode == 'similar',
          onTap: () => onChanged('similar'),
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(height: 8),
        _ModeButton(
          id: 'my_taste',
          title: 'My Taste',
          subtitle: 'Personalised AI powered suggestions',
          icon: Icons.auto_awesome_rounded,
          isActive: currentMode == 'my_taste',
          onTap: () => onChanged('my_taste'),
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.isDark,
    required this.cs,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? cs.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? cs.primary : (isDark ? Colors.white10 : Colors.black12),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? cs.primary : cs.onSurfaceVariant, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: isActive ? cs.primary : cs.onSurface, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InvidiousStatusCard extends StatelessWidget {
  const _InvidiousStatusCard({
    required this.isLoggedIn,
    this.username,
    this.instanceUrl,
    required this.isDark,
    required this.cs,
    required this.onLogin,
  });

  final bool isLoggedIn;
  final String? username;
  final String? instanceUrl;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLoggedIn ? Colors.red.withValues(alpha: 0.05) : (isDark ? Colors.white.withValues(alpha: 0.02) : cs.surfaceContainerHigh),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoggedIn ? Colors.red.withValues(alpha: 0.2) : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLoggedIn ? Colors.red : cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLoggedIn ? Icons.account_circle_rounded : Icons.account_circle_outlined,
              size: 24,
              color: isLoggedIn ? Colors.white : cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? '@$username' : 'Guest Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : cs.onSurface,
                    fontSize: 16,
                  ),
                ),
                Text(
                  isLoggedIn ? (instanceUrl?.isNotEmpty == true ? instanceUrl! : 'No Instance Saved') : 'Log in to sync playlists',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLoggedIn ? Colors.red : cs.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isLoggedIn ? 'Switch' : 'Login'),
          ),
        ],
      ),
    );
  }
}

class _PlaylistSyncTile extends StatelessWidget {
  const _PlaylistSyncTile({
    required this.title,
    required this.count,
    required this.isDark,
    required this.cs,
    required this.onSync,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onSync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        title: Text(title, style: TextStyle(color: isDark ? Colors.white : cs.onSurface, fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text('$count tracks', style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
        trailing: IconButton(
          icon: Icon(Icons.sync_rounded, size: 20, color: cs.primary),
          onPressed: onSync,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon, required this.isDark, required this.cs});
  final String label;
  final IconData icon;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isDark ? cs.primary : cs.primary),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isDark ? Colors.white.withValues(alpha: 0.5) : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, required this.isDark, required this.cs, this.accent});
  final Widget child;
  final bool isDark;
  final ColorScheme cs;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent?.withValues(alpha: 0.3) ?? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (accent != null) 
                Container(
                  width: 40, height: 3, 
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.label, this.cs);
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant));
  }
}

class _StyledTextField extends StatelessWidget {
  const _StyledTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.cs,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ColorScheme cs;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isDark) BoxShadow(color: cs.primary.withValues(alpha: 0.05), blurRadius: 4, spreadRadius: -2),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: isDark ? Colors.white : cs.onSurface, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          filled: true,
          fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: isDark ? Colors.white10 : cs.outlineVariant.withValues(alpha: 0.5), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.cs,
    required this.isDark,
    required this.onChanged,
  });
  final String label;
  final String subtitle;
  final bool value;
  final ColorScheme cs;
  final bool isDark;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : cs.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: cs.primary),
      ],
    );
  }
}
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.cs,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: isDark ? Colors.white : cs.primary),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
