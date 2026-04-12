import { PaperProvider, MD3DarkTheme } from 'react-native-paper';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';

// Boot AudioService singleton
import '../services/AudioService';

// Customize the dark theme slightly for Elysium brand colors
const ElysiumTheme = {
  ...MD3DarkTheme,
  colors: {
    ...MD3DarkTheme.colors,
    primary: '#a994ff',   // Purple accent
    primaryContainer: '#3d2e80',
    onPrimaryContainer: '#e8e0ff',
    surface: '#050505',
    surfaceVariant: '#1a1a1a',
    elevation: {
      ...MD3DarkTheme.colors.elevation,
      level1: '#111111',
      level2: '#1a1a1a',
      level3: '#222222',
    },
  },
};

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <PaperProvider theme={ElysiumTheme}>
        <StatusBar style="light" />
        <Stack>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen
            name="player"
            options={{ presentation: 'fullScreenModal', headerShown: false, animation: 'slide_from_bottom' }}
          />
        </Stack>
      </PaperProvider>
    </GestureHandlerRootView>
  );
}
