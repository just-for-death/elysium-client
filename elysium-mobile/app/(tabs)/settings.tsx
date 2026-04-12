import React, { useState, useEffect } from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { Text, TextInput, Switch, Button, Divider, useTheme } from 'react-native-paper';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { usePlayerStore } from '../../store/usePlayerStore';
import { getSettings, updateSettings, Settings } from '../../services/ElysiumApi';

export default function SettingsScreen() {
  const theme = useTheme();
  const insets = useSafeAreaInsets();
  const { serverIp, setServerIp } = usePlayerStore();

  const [ipInput, setIpInput] = useState(serverIp);
  const [settings, setSettings] = useState<Partial<Settings>>({});
  const [saving, setSaving] = useState(false);

  const loadSettings = async () => {
    if (!serverIp) return;
    try {
      const data = await getSettings(serverIp);
      setSettings(data);
    } catch {
      // Not connected yet
    }
  };

  useEffect(() => { loadSettings(); }, [serverIp]);

  const saveAll = async () => {
    setSaving(true);
    try {
      // Apply new server IP
      const newIp = ipInput.trim();
      if (newIp !== serverIp) setServerIp(newIp);
      await updateSettings(newIp || serverIp, settings);
      Alert.alert('Saved', 'Settings synced to server.');
    } catch (e: any) {
      Alert.alert('Error', e.message || 'Could not save settings');
    } finally {
      setSaving(false);
    }
  };

  const update = (key: keyof Settings, value: any) =>
    setSettings(prev => ({ ...prev, [key]: value }));

  return (
    <ScrollView
      style={[styles.container, { backgroundColor: '#000' }]}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + 20, paddingBottom: 140 }]}
      showsVerticalScrollIndicator={false}
    >
      <Text style={styles.title}>Settings</Text>

      {/* ── Server ── */}
      <SectionHeader label="Server" />
      <TextInput
        label="Server IP (e.g. http://192.168.1.x:3000)"
        value={ipInput}
        onChangeText={setIpInput}
        mode="outlined"
        style={styles.input}
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType="url"
        right={<TextInput.Icon icon="server" />}
      />

      <Divider style={styles.divider} />

      {/* ── Audio Quality ── */}
      <SectionHeader label="Audio" />
      <Row label="High Quality Streams" desc="Prefer highest bitrate audio">
        <Switch value={settings.highQuality ?? false} onValueChange={v => update('highQuality', v)} color={theme.colors.primary} />
      </Row>
      <Row label="Cache Audio" desc="Cache streams for faster repeat play">
        <Switch value={settings.cacheEnabled ?? true} onValueChange={v => update('cacheEnabled', v)} color={theme.colors.primary} />
      </Row>

      <Divider style={styles.divider} />

      {/* ── AI / Ollama ── */}
      <SectionHeader label="AI Queue (Ollama)" />
      <Row label="Enable AI Queue" desc="Generate smart next tracks using Ollama">
        <Switch value={settings.ollamaEnabled ?? false} onValueChange={v => update('ollamaEnabled', v)} color={theme.colors.primary} />
      </Row>
      <TextInput
        label="Ollama URL"
        value={settings.ollamaUrl ?? ''}
        onChangeText={v => update('ollamaUrl', v)}
        mode="outlined"
        style={styles.input}
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType="url"
        disabled={!settings.ollamaEnabled}
      />
      <TextInput
        label="Ollama Model (e.g. llama3)"
        value={settings.ollamaModel ?? ''}
        onChangeText={v => update('ollamaModel', v)}
        mode="outlined"
        style={styles.input}
        autoCapitalize="none"
        autoCorrect={false}
        disabled={!settings.ollamaEnabled}
      />

      <Divider style={styles.divider} />

      {/* ── ListenBrainz ── */}
      <SectionHeader label="ListenBrainz Scrobbling" />
      <TextInput
        label="Username"
        value={settings.listenBrainzUsername ?? ''}
        onChangeText={v => update('listenBrainzUsername', v)}
        mode="outlined"
        style={styles.input}
        autoCapitalize="none"
        autoCorrect={false}
      />
      <TextInput
        label="User Token"
        value={settings.listenBrainzToken ?? ''}
        onChangeText={v => update('listenBrainzToken', v)}
        mode="outlined"
        style={styles.input}
        autoCapitalize="none"
        autoCorrect={false}
        secureTextEntry
        right={<TextInput.Icon icon="key" />}
      />

      <Divider style={styles.divider} />

      <Button
        mode="contained"
        onPress={saveAll}
        loading={saving}
        disabled={saving}
        style={styles.saveBtn}
        contentStyle={{ paddingVertical: 6 }}
        labelStyle={{ fontSize: 16, fontWeight: '700' }}
      >
        Save & Sync to Server
      </Button>
    </ScrollView>
  );
}

function SectionHeader({ label }: { label: string }) {
  return <Text style={styles.sectionLabel}>{label}</Text>;
}

function Row({ label, desc, children }: { label: string; desc?: string; children: React.ReactNode }) {
  const theme = useTheme();
  return (
    <View style={styles.row}>
      <View style={{ flex: 1 }}>
        <Text style={{ color: theme.colors.onSurface, fontWeight: '600', fontSize: 15 }}>{label}</Text>
        {desc && <Text style={{ color: theme.colors.onSurfaceVariant, fontSize: 12, marginTop: 2 }}>{desc}</Text>}
      </View>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: { paddingHorizontal: 20 },
  title: { fontSize: 34, fontWeight: '800', color: '#fff', letterSpacing: -0.5, marginBottom: 24 },
  sectionLabel: { fontSize: 12, fontWeight: '700', textTransform: 'uppercase', letterSpacing: 1.2, color: 'rgba(255,255,255,0.4)', marginBottom: 12, marginTop: 4 },
  input: { marginBottom: 12 },
  divider: { marginVertical: 20, backgroundColor: 'rgba(255,255,255,0.08)' },
  row: { flexDirection: 'row', alignItems: 'center', marginBottom: 16, gap: 12 },
  saveBtn: { marginTop: 8, borderRadius: 12 },
});
