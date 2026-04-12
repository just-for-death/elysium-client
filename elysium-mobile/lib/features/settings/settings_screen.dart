import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/elysium_api.dart';
import '../../core/models/models.dart';
import '../../core/store/providers.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverIp = ref.watch(serverIpProvider);
    final api = useMemoized(() => ElysiumApi(serverIp), [serverIp]);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final serverCtrl =
        useTextEditingController(text: serverIp);
    final settings = useState<ElysiumSettings?>(null);
    final loading = useState(true);
    final saving = useState(false);

    // Server-side settings controllers
    final lbTokenCtrl = useTextEditingController();
    final lbUserCtrl = useTextEditingController();
    final ollamaUrlCtrl = useTextEditingController();
    final ollamaModelCtrl = useTextEditingController();
    final invidiousInstanceCtrl = useTextEditingController();

    // Login controllers
    final invUserCtrl = useTextEditingController();
    final invPassCtrl = useTextEditingController();

    // Playlist sync state
    final invPlaylists = useState<List<dynamic>?>(null);
    final plLoading = useState(false);

    Future<void> loadSettings() async {
      if (serverIp.isEmpty) return;
      loading.value = true;
      try {
        final s = await api.getSettings();
        settings.value = s;
        lbTokenCtrl.text = s.listenBrainzToken;
        lbUserCtrl.text = s.listenBrainzUsername;
        ollamaUrlCtrl.text = s.ollamaUrl;
        ollamaModelCtrl.text = s.ollamaModel;
        invidiousInstanceCtrl.text = s.invidiousInstance;
      } catch (_) {
        settings.value = null;
      } finally {
        loading.value = false;
      }
    }

    Future<void> loadInvidiousPlaylists() async {
      if (settings.value?.invidiousSid == null || serverIp.isEmpty) return;
      plLoading.value = true;
      try {
        final pl = await api.getInvidiousPlaylists(
          instanceUrl: settings.value!.invidiousInstance,
          sid: settings.value!.invidiousSid!,
        );
        invPlaylists.value = pl;
      } catch (_) {
        invPlaylists.value = null;
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
          'listenBrainzToken': lbTokenCtrl.text,
          'listenBrainzUsername': lbUserCtrl.text,
          'ollamaUrl': ollamaUrlCtrl.text,
          'ollamaModel': ollamaModelCtrl.text,
          'invidiousInstance': sanitizedInstance,
        });
        invidiousInstanceCtrl.text = sanitizedInstance;
        settings.value = updated;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved ✓')),
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
                Navigator.pop(ctx);
                loading.value = true;
                try {
                  final res = await api.invidiousLogin(instance, invUserCtrl.text, invPassCtrl.text);
                  if (res['sid'] != null) {
                    await api.updateSettings({
                      'invidiousSid': res['sid'],
                      'invidiousUsername': invUserCtrl.text,
                    });
                    loadSettings();
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

            // ── Server connection ───────────────────────────────────────────
            _SectionHeader(label: 'Server', isDark: isDark, cs: cs),
            SliverToBoxAdapter(
              child: _SettingsCard(
                isDark: isDark,
                cs: cs,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SettingsLabel('Server URL', cs),
                    const SizedBox(height: 8),
                    _StyledTextField(
                      controller: serverCtrl,
                      hint: 'http://192.168.x.x:7771',
                      isDark: isDark,
                      cs: cs,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          final url = serverCtrl.text.trim();
                          if (url.isNotEmpty) {
                            ref.read(serverIpProvider.notifier).update(url);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Invidious ───────────────────────────────────────────────────
            if (settings.value != null) ...[
              _SectionHeader(label: 'Invidious', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('Instance URL', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(
                        controller: invidiousInstanceCtrl,
                        hint: 'https://invidious.io',
                        isDark: isDark,
                        cs: cs,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InvidiousStatus(
                              isLoggedIn: settings.value!.invidiousUsername != null,
                              username: settings.value!.invidiousUsername,
                              isDark: isDark,
                              cs: cs,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: loginToInvidious,
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: Text(settings.value!.invidiousUsername != null ? 'Switch' : 'Login'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    children: [
                      _SwitchTile(
                        label: 'High Quality Audio',
                        subtitle:
                            'Stream higher bitrate when available',
                        value: settings.value!.highQuality,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value =
                              settings.value!.copyWith(highQuality: v);
                          api.updateSettings({'highQuality': v}).ignore();
                        },
                      ),
                      Divider(
                          color: isDark
                              ? Colors.white12
                              : Colors.black12),
                      _SwitchTile(
                        label: 'Cache Audio',
                        subtitle: 'Save tracks for offline listening',
                        value: settings.value!.cacheEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value =
                              settings.value!.copyWith(cacheEnabled: v);
                          api.updateSettings({'cacheEnabled': v}).ignore();
                        },
                      ),
                      Divider(
                          color: isDark
                              ? Colors.white12
                              : Colors.black12),
                      _SwitchTile(
                        label: 'Video Mode',
                        subtitle: 'Prefer high-quality video playback',
                        value: settings.value!.videoMode,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value =
                              settings.value!.copyWith(videoMode: v);
                          api.updateSettings({'videoMode': v}).ignore();
                          ref.read(playerProvider.notifier).fetchSettings();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // ── Invidious Playlists ──────────────────────────────────────────
              if (settings.value!.invidiousUsername != null) ...[
                _SectionHeader(label: 'YouTube Playlists', isDark: isDark, cs: cs),
                SliverToBoxAdapter(
                  child: _SettingsCard(
                    isDark: isDark,
                    cs: cs,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (plLoading.value)
                          const Center(child: LinearProgressIndicator())
                        else if (invPlaylists.value == null || invPlaylists.value!.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('No playlists found', style: TextStyle(color: Colors.white24)),
                            ),
                          )
                        else
                          ...invPlaylists.value!.map((pl) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(pl['title'] ?? 'Playlist', style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: Text('${pl['videoCount'] ?? 0} videos', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.sync_rounded),
                              onPressed: () async {
                                final sc = ScaffoldMessenger.of(context);
                                try {
                                  await api.syncInvidiousPlaylist(
                                    pl['playlistId'],
                                    instanceUrl: settings.value!.invidiousInstance,
                                    sid: settings.value!.invidiousSid!,
                                  );
                                  sc.showSnackBar(const SnackBar(content: Text('Playlist synced to Library ✓')));
                                } catch (e) {
                                  sc.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                                }
                              },
                            ),
                          )),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Refresh Playlists'),
                            onPressed: loadInvidiousPlaylists,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── ListenBrainz ─────────────────────────────────────────────
              _SectionHeader(
                  label: 'ListenBrainz', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('Username', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(
                          controller: lbUserCtrl,
                          hint: 'your_username',
                          isDark: isDark,
                          cs: cs),
                      const SizedBox(height: 14),
                      _SettingsLabel('User Token', cs),
                      const SizedBox(height: 8),
                      _StyledTextField(
                          controller: lbTokenCtrl,
                          hint: 'paste token here',
                          isDark: isDark,
                          cs: cs,
                          obscure: true),
                    ],
                  ),
                ),
              ),

              // ── Ollama AI ─────────────────────────────────────────────────
              _SectionHeader(label: 'AI Queue', isDark: isDark, cs: cs),
              SliverToBoxAdapter(
                child: _SettingsCard(
                  isDark: isDark,
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SwitchTile(
                        label: 'Enable AI Queue',
                        subtitle:
                            'Use Ollama to suggest next tracks',
                        value: settings.value!.ollamaEnabled,
                        cs: cs,
                        isDark: isDark,
                        onChanged: (v) {
                          settings.value = settings.value!
                              .copyWith(ollamaEnabled: v);
                          api.updateSettings({'ollamaEnabled': v}).ignore();
                        },
                      ),
                      if (settings.value!.ollamaEnabled) ...[
                        Divider(
                            color: isDark
                                ? Colors.white12
                                : Colors.black12),
                        const SizedBox(height: 8),
                        _SettingsLabel('Ollama URL', cs),
                        const SizedBox(height: 8),
                        _StyledTextField(
                            controller: ollamaUrlCtrl,
                            hint: 'http://localhost:11434',
                            isDark: isDark,
                            cs: cs),
                        const SizedBox(height: 14),
                        _SettingsLabel('Model', cs),
                        const SizedBox(height: 8),
                        _StyledTextField(
                            controller: ollamaModelCtrl,
                            hint: 'llama3',
                            isDark: isDark,
                            cs: cs),
                      ],
                    ],
                  ),
                ),
              ),

              // Save button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: ElevatedButton.icon(
                    icon: saving.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(saving.value ? 'Saving...' : 'Save Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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
                      else ...[
                        Icon(Icons.cloud_off_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a server URL above to connect.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }
}

class _InvidiousStatus extends StatelessWidget {
  const _InvidiousStatus({
    required this.isLoggedIn,
    this.username,
    required this.isDark,
    required this.cs,
  });

  final bool isLoggedIn;
  final String? username;
  final bool isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isLoggedIn ? 'Status: Logged in' : 'Status: Guest',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isLoggedIn ? Colors.greenAccent : cs.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        if (isLoggedIn && username != null)
          Text(
            '@$username',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label, required this.isDark, required this.cs});
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
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard(
      {required this.child, required this.isDark, required this.cs});
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
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
    return Text(label,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurfaceVariant));
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
      style: TextStyle(
          color: isDark ? Colors.white : cs.onSurface, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : cs.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : cs.onSurface,
                  )),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: cs.primary,
        ),
      ],
    );
  }
}
