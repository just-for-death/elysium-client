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
    final api = useMemoized(() => ElysiumApi(serverIp), [serverIp]);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final serverCtrl = useTextEditingController(text: serverIp);
    final settings = useState<ElysiumSettings?>(null);
    final loading = useState(true);
    final saving = useState(false);

    // Server-side settings controllers
    final lbTokenCtrl = useTextEditingController();
    final lbUserCtrl = useTextEditingController();
    final ollamaUrlCtrl = useTextEditingController();
    final ollamaModelCtrl = useTextEditingController();
    final invidiousInstanceCtrl = useTextEditingController();
    final lastFmKeyCtrl = useTextEditingController();

    // Login controllers
    final invUserCtrl = useTextEditingController();
    final invPassCtrl = useTextEditingController();

    // Playlist sync state
    final invPlaylists = useState<List<dynamic>?>(null);
    final plLoading = useState(false);

    final errorMsg = useState<String?>(null);

    Future<void> loadSettings() async {
      if (serverIp.isEmpty) return;
      loading.value = true;
      errorMsg.value = null;
      try {
        final s = await api.getSettings();
        settings.value = s;
        lbTokenCtrl.text = s.listenBrainzToken;
        lbUserCtrl.text = s.listenBrainzUsername;
        ollamaUrlCtrl.text = s.ollamaUrl;
        ollamaModelCtrl.text = s.ollamaModel;
        invidiousInstanceCtrl.text = s.invidiousInstance;
        lastFmKeyCtrl.text = s.lastFmApiKey;
      } catch (e) {
        settings.value = null;
        errorMsg.value = e.toString().replaceFirst('Exception: ', '');
      } finally {
        loading.value = false;
      }
    }

    Future<void> loadInvidiousPlaylists() async {
      if (serverIp.isEmpty) return;
      if (settings.value?.invidiousUsername == null || 
          settings.value?.invidiousInstance.isEmpty == true) {
        invPlaylists.value = null;
        return;
      }
      plLoading.value = true;
      try {
        final pl = await api.getInvidiousPlaylists(
          instanceUrl: settings.value!.invidiousInstance,
          sid: settings.value?.invidiousSid,
        );
        invPlaylists.value = pl;
      } catch (e) {
        invPlaylists.value = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not fetch playlists: $e')),
          );
        }
      } finally {
        plLoading.value = false;
      }
    }

    useEffect(() {
      loadSettings().then((_) => loadInvidiousPlaylists());
      return null;
    }, [serverIp]);

    Future<void> saveServerSettings() async {
      if (settings.value == null) return;
      saving.value = true;
      try {
        final instance = invidiousInstanceCtrl.text.trim();
        final sanitizedInstance = instance.isNotEmpty ? Uri.parse(instance).origin : '';

        final updated = await api.updateSettings({
          ...settings.value!.toJson(),
          'listenBrainzToken': lbTokenCtrl.text.trim(),
          'listenBrainzUsername': lbUserCtrl.text.trim(),
          'ollamaUrl': ollamaUrlCtrl.text.trim(),
          'ollamaModel': ollamaModelCtrl.text.trim(),
          'invidiousInstance': sanitizedInstance,
          'lastFmApiKey': lastFmKeyCtrl.text.trim(),
        });
        invidiousInstanceCtrl.text = sanitizedInstance;
        settings.value = updated;
        
        // Auto-validate LB if token changed
        if (lbTokenCtrl.text.trim().isNotEmpty) {
          try {
            final lb = await api.validateListenBrainzToken(lbTokenCtrl.text.trim());
            if (lb['username'] != null) {
              lbUserCtrl.text = lb['username'];
              await api.updateSettings({'listenBrainzUsername': lb['username']});
            }
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
      if (settings.value == null) return;
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
                loading.value = true;
                try {
                  final res = await api.invidiousLogin(instance, user, pass);
                  if (res['sid'] != null) {
                    await api.updateSettings({
                      'invidiousSid': res['sid'],
                      'invidiousUsername': user,
                      'invidiousInstance': sanitizedInstance,
                    });
                    await loadSettings();
                    await loadInvidiousPlaylists();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e')));
                  }
                } finally {
                  loading.value = false;
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050505) : cs.surface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : cs.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            if (settings.value != null) ...[
              // ── AUTO QUEUE ───────────────────────────────────────────────
              _SectionHeader(label: 'Auto Queue', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    children: [
                      _SwitchTile(
                        label: 'Auto Queue',
                        subtitle: 'Automatically queue the next track when one is about to end',
                        value: settings.value!.ollamaEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value = settings.value!.copyWith(ollamaEnabled: v);
                          api.updateSettings({'ollamaEnabled': v}).ignore();
                        },
                      ),
                      if (settings.value!.ollamaEnabled) ...[
                        const SizedBox(height: 16),
                        _SettingsLabel('QUEUE MODE', cs),
                        const SizedBox(height: 8),
                        _QueueModeSelector(
                          currentMode: settings.value!.queueMode,
                          isDark: isDark,
                          cs: cs,
                          onChanged: (mode) {
                            settings.value = settings.value!.copyWith(queueMode: mode);
                            api.updateSettings({'queueMode': mode}).ignore();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── OLLAMA ENGINE ───────────────────────────────────────────
              if (settings.value!.queueMode == 'my_taste') ...[
                _SectionHeader(label: 'Ollama — AI Engine', isDark: isDark, cs: cs),
                SliverToBoxAdapter(
                  child: _SettingsCard(
                    isDark: isDark,
                    cs: cs,
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
              _SectionHeader(label: 'Last.fm Plugin', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('API KEY (OPTIONAL FALLBACK)', cs),
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
              _SectionHeader(label: 'Invidious Account', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
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
              _SectionHeader(label: 'Scrobbling', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
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
                    ],
                  ),
                ),
              ),

              // ── PLAYER ───────────────────────────────────────────────────
              _SectionHeader(label: 'Player', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    children: [
                      _SwitchTile(
                        label: 'High Quality Audio',
                        subtitle: 'Stream higher bitrate when available',
                        value: settings.value!.highQuality,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value = settings.value!.copyWith(highQuality: v);
                          api.updateSettings({'highQuality': v}).ignore();
                        },
                      ),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      _SwitchTile(
                        label: 'Cache Audio',
                        subtitle: 'Save tracks for offline listening',
                        value: settings.value!.cacheEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value = settings.value!.copyWith(cacheEnabled: v);
                          api.updateSettings({'cacheEnabled': v}).ignore();
                        },
                      ),
                      Divider(color: isDark ? Colors.white12 : Colors.black12),
                      _SwitchTile(
                        label: 'Video Mode',
                        subtitle: 'Prefer high-quality video playback',
                        value: settings.value!.videoMode,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value = settings.value!.copyWith(videoMode: v);
                          api.updateSettings({'videoMode': v}).ignore();
                          ref.read(playerProvider.notifier).fetchSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── SYSTEM ───────────────────────────────────────────────────
              _SectionHeader(label: 'System', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
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
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                  child: ElevatedButton.icon(
                    icon: saving.value ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                    label: Text(saving.value ? 'Syncing...' : 'Save & Sync Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: saving.value ? null : saveServerSettings,
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
                        Icon(Icons.cloud_off_rounded, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('Enter a server URL below to connect.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLoggedIn ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLoggedIn ? Icons.account_circle_rounded : Icons.account_circle_outlined,
            size: 32,
            color: isLoggedIn ? Colors.greenAccent : cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? '@$username' : 'Guest Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isLoggedIn ? Colors.white : cs.onSurfaceVariant,
                    fontSize: 15,
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
          TextButton(
            onPressed: onLogin,
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
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('$count videos', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.sync_rounded, size: 20, color: Colors.white60),
          onPressed: onSync,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.isDark, required this.cs});
  final String label;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.4) : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, required this.isDark, required this.cs});
  final Widget child;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: child,
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
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : cs.onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : cs.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
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
