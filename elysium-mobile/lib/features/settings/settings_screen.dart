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
      } catch (_) {
        settings.value = null;
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      loadSettings();
      return null;
    }, [serverIp]);

    Future<void> saveServerSettings() async {
      if (settings.value == null) return;
      saving.value = true;
      try {
        final updated = await api.updateSettings({
          ...settings.value!.toJson(),
          'listenBrainzToken': lbTokenCtrl.text,
          'listenBrainzUsername': lbUserCtrl.text,
          'ollamaUrl': ollamaUrlCtrl.text,
          'ollamaModel': ollamaModelCtrl.text,
        });
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

            // ── Playback ──────────────────────────────────────────────────
            if (settings.value != null) ...[
              _SectionHeader(
                  label: 'Playback', isDark: isDark, cs: cs),
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
                    ],
                  ),
                ),
              ),

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

// ── Shared subwidgets ─────────────────────────────────────────────────────────

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
