import React from 'react';
import { Tabs } from 'expo-router';
import { BottomTabBar } from '@react-navigation/bottom-tabs';
import { View, Platform } from 'react-native';
import { useTheme } from 'react-native-paper';
import { BlurView } from 'expo-blur';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import MiniPlayer from '../../components/MiniPlayer';

export default function TabLayout() {
  const theme = useTheme();
  const isIOS = Platform.OS === 'ios';

  return (
    <View style={{ flex: 1, backgroundColor: '#000' }}>
      <Tabs
        tabBar={(props) => {
          const content = (
            <View>
              <MiniPlayer />
              <BottomTabBar
                {...props}
                style={{ backgroundColor: 'transparent', elevation: 0, borderTopWidth: 0 }}
              />
            </View>
          );

          if (isIOS) {
            return (
              <View style={{ position: 'absolute', bottom: 0, left: 0, right: 0 }}>
                <BlurView tint="dark" intensity={90} experimentalBlurMethod="dimezisBlurView">
                  {content}
                </BlurView>
              </View>
            );
          }

          return (
            <View style={{ backgroundColor: theme.colors.elevation.level1, borderTopColor: theme.colors.elevation.level2, borderTopWidth: 1 }}>
              {content}
            </View>
          );
        }}
        screenOptions={{
          headerShown: false,
          tabBarActiveTintColor: theme.colors.primary,
          tabBarInactiveTintColor: 'rgba(255,255,255,0.4)',
          tabBarStyle: { backgroundColor: 'transparent', elevation: 0, borderTopWidth: 0 },
          tabBarLabelStyle: { fontSize: 11, fontWeight: '600' },
        }}
      >
        <Tabs.Screen
          name="index"
          options={{
            title: 'Home',
            tabBarIcon: ({ color }) => <MaterialCommunityIcons name="home" size={26} color={color} />,
          }}
        />
        <Tabs.Screen
          name="search"
          options={{
            title: 'Search',
            tabBarIcon: ({ color }) => <MaterialCommunityIcons name="magnify" size={26} color={color} />,
          }}
        />
        <Tabs.Screen
          name="library"
          options={{
            title: 'Library',
            tabBarIcon: ({ color }) => <MaterialCommunityIcons name="playlist-music" size={26} color={color} />,
          }}
        />
        <Tabs.Screen
          name="settings"
          options={{
            title: 'Settings',
            tabBarIcon: ({ color }) => <MaterialCommunityIcons name="cog" size={26} color={color} />,
          }}
        />
        {/* Hide the explore tab from navigation — it's kept for backwards compat */}
        <Tabs.Screen name="explore" options={{ href: null }} />
      </Tabs>
    </View>
  );
}
