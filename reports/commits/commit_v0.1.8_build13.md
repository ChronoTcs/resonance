Feat: Studio Equalizer overhaul with 22 acoustic presets, real-time Bézier frequency curve, zero-flicker screen persistence, thumbnail memory optimization, safe-area notification placement, and version bump to 0.1.8-beta+13

• Studio Equalizer & 22 Acoustic Presets: expand equalizer catalog from 10 (4 displayed) to 22 studio acoustic profiles across 5 categories (General, Bass, Voice & Speech, Music Genres, Acoustic & Instruments) in equalizer_service.dart; preserve backwards-compatible Vocal alias
• Real-time Bézier Curve Visualizer: create EqualizerCurveVisualizer with smooth Catmull-Rom cubic spline, glowing primary accent stroke, vertical baseline gradient fill, and 240ms tween animation on preset morphing
• Preset Carousel & Categorized Modal: implement EqualizerPresetSelector with 1-tap horizontal chip carousel and full categorized modal sheet with live search filtering
• Adaptive Mobile & Desktop Equalizer Console: build EqualizerBandSlider with live dB readout badge (+3.5 dB, 0 dB, -4.0 dB) and EqualizerBandsConsole providing responsive layout (horizontal scroll with 48dp touch targets on narrow mobile screens <44dp/band; evenly expanded row on wide screens >=44dp/band)
• Canonical Glassmorphic FloatingSheetShell: migrate equalizer modal to FloatingSheetShell with blur, 24px border radius, reset button, master power switch, and linked nearby slider adjustments
• Zero-Flicker Screen Persistence: replace AnimatedSwitcher with IndexedStack in dashboard_screen.dart, keeping all tabs permanently mounted in memory with preserved scroll positions and 0 re-fetch overhead
• Card Resolution & Image Cache Optimization: implement ThumbnailUtils.toCardResolution(url) targeting 400px cards (saving ~90% bandwidth and ~86% bitmap RAM); initialize thumbnail resolution synchronously in media_artwork_widget.dart; configure sqflite_common_ffi on Windows
• In-App Notification Placement: de-pyramidize NotificationBannerOverlay, add responsive top safe-area offset on Android, and enforce symmetrical mobile centering
• Android Notification Dismissal & Bezel Polish: mask notification IDs to positive 31-bit integer preventing sticky ongoing flags; add 12dp right bezel clearance and auto-scrolling ResonanceMarqueeText to docked mini player
• Version Bump: bump version to 0.1.8-beta (+13) across pubspec.yaml, release workflow, and Python engine version info (0.1.8.13)
