import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/core/configs/app_breakpoints.dart';
import 'package:resonance/core/providers/navigation_provider.dart';
import 'package:resonance/core/utils/uicons.dart';
import 'package:resonance/core/widgets/widgets.dart';
import 'package:resonance/features/library/application/library_provider.dart';
import 'package:resonance/features/library/presentation/widgets/morphing_library_bar.dart';
import 'add_audio/add_audio_shortcut_cards.dart';
import 'add_audio/audio_file_drop_card.dart';
import 'add_audio/batch_import_progress_card.dart';
import 'add_audio/mobile_media_import_card.dart';

/// Modern floating inset bottom sheet for adding audio to the local library.
/// Supports drag-and-drop file/folder ingestion, device explorer picking (Windows & Android),
/// direct navigation to the Explore page, and the Downloads manager shortcut.
class AddAudioSheet extends ConsumerStatefulWidget {
  const AddAudioSheet({super.key});

  /// Displays the modern floating bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const AddAudioSheet(),
    );
  }

  @override
  ConsumerState<AddAudioSheet> createState() => _AddAudioSheetState();
}

class _AddAudioSheetState extends ConsumerState<AddAudioSheet> {
  bool _isDragging = false;
  bool _isLoading = false;
  int _currentProgress = 0;
  int _totalProgress = 0;
  String? _errorMessage;

  void _onProgress(int current, int total) {
    if (mounted) {
      setState(() {
        _currentProgress = current;
        _totalProgress = total;
      });
    }
  }

  Future<void> _handleDroppedFiles(List<String> paths) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentProgress = 0;
      _totalProgress = paths.length;
    });

    final count = await ref.read(libraryProvider.notifier).importDroppedPaths(
      paths,
      onProgress: _onProgress,
    );

    if (mounted) {
      if (count > 0) {
        Navigator.pop(context);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No supported audio files found (.mp3, .m4a, .flac, .wav, .ogg, .opus, .aac, .wma)';
        });
      }
    }
  }

  Future<void> _pickAudioFiles() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _currentProgress = 0;
      _totalProgress = 0;
    });

    final count = await ref.read(libraryProvider.notifier).pickAndImportAudioFiles(
      onProgress: _onProgress,
    );

    if (mounted) {
      if (count > 0) {
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _currentProgress = 0;
      _totalProgress = 0;
    });

    final count = await ref.read(libraryProvider.notifier).pickAndImportFolder(
      onProgress: _onProgress,
    );

    if (mounted) {
      if (count > 0) {
        Navigator.pop(context);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToExplore() {
    Navigator.pop(context);
    ref.read(mainNavigationProvider.notifier).setIndex(1);
  }

  void _goToDownloads() {
    final bool isDesktop = AppBreakpoints.isWide(context);
    Navigator.pop(context);
    if (isDesktop) {
      ref.read(mainNavigationProvider.notifier).setIndex(4);
    } else {
      ref.read(libraryNavModeProvider.notifier).setMode(LibraryNavMode.downloads);
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final bool isMobile = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS;

    return FloatingSheetShell(
      title: 'Add Audio to Library',
      icon: UIcons.regular.music,
      onClose: _isLoading ? null : () => Navigator.pop(context),
      children: [
        if (isMobile) ...[
          if (_isLoading) ...[
            BatchImportProgressCard(
              current: _currentProgress,
              total: _totalProgress,
            ),
            const SizedBox(height: 12),
          ],
          MobileMediaImportCard(
            title: 'Browse Audio Files',
            subtitle: 'Pick one or multiple audio tracks from device storage',
            badge: 'MP3, FLAC, M4A, WAV, OGG, OPUS, AAC',
            icon: UIcons.regular.music,
            isLoading: _isLoading,
            onTap: _isLoading ? null : _pickAudioFiles,
          ),
          const SizedBox(height: 10),
          MobileMediaImportCard(
            title: 'Scan Music Folder',
            subtitle: 'Recursively scan and add all songs from a folder or album',
            badge: 'FOLDERS & ALBUMS',
            icon: UIcons.regular.folder_upload,
            isLoading: _isLoading,
            onTap: _isLoading ? null : _pickFolder,
          ),
        ] else ...[
          AudioFileDropCard(
            isDragging: _isDragging,
            isLoading: _isLoading,
            progressCurrent: _currentProgress,
            progressTotal: _totalProgress,
            onDragEntered: () => setState(() => _isDragging = true),
            onDragExited: () => setState(() => _isDragging = false),
            onFilesDropped: (paths) {
              setState(() => _isDragging = false);
              _handleDroppedFiles(paths);
            },
            onPickFiles: _pickAudioFiles,
            onPickFolder: _pickFolder,
          ),
        ],
        const SizedBox(height: 14),
        const SheetDivider(label: 'OR DISCOVER ONLINE'),
        const SizedBox(height: 14),
        ExploreShortcutCard(
          onTap: _isLoading ? null : _goToExplore,
        ),
        const SizedBox(height: 10),
        DownloadsShortcutCard(
          onTap: _isLoading ? null : _goToDownloads,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          SheetErrorBanner(message: _errorMessage!),
        ],
      ],
    );
  }
}
