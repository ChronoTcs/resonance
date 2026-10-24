import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance/features/explore/data/repositories/youtube_search_repository.dart';
import 'package:resonance/features/explore/data/services/youtube_innertube_client.dart';
import 'package:resonance/features/player/application/services/playback_architecture_service.dart';
import 'package:resonance/features/explore/data/repositories/youtube_stream_repository.dart';

class StubInnerTubeClient implements YoutubeInnerTubeClient {
  final Map<String, dynamic> Function(String endpoint, Map<String, dynamic> payload) onPost;

  StubInnerTubeClient(this.onPost);

  @override
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> payload, {
    YoutubeClientProfile profile = YoutubeClientProfile.webRemix,
    bool useAuth = false,
    String? poToken,
    int? signatureTimestamp,
  }) async {
    return onPost(endpoint, payload);
  }

  @override
  String? getText(dynamic node) {
    if (node == null) return null;
    if (node is Map) {
      if (node.containsKey('simpleText')) return node['simpleText'] as String?;
      if (node.containsKey('runs') && node['runs'] is List) {
        final runs = node['runs'] as List;
        return runs.map((r) => (r is Map) ? (r['text'] ?? '') : '').join();
      }
    }
    return node.toString();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubYoutubeStreamRepo implements YoutubeStreamRepository {
  @override
  Future<String?> getStreamUrl(String videoId, {bool isDirectPlay = false, bool forceRefresh = false}) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('YoutubeSearchRepository Enhanced Parser Tests', () {
    test('extracts embedded tracks from artist musicCardShelfRenderer and overlay videoIds', () async {
      final mockData = {
        'contents': {
          'tabbedSearchResultsRenderer': {
            'tabs': [
              {
                'tabRenderer': {
                  'content': {
                    'sectionListRenderer': {
                      'contents': [
                        // Section 0: Artist Card Shelf with embedded contents
                        {
                          'musicCardShelfRenderer': {
                            'title': {
                              'runs': [
                                {
                                  'text': 'JVKE',
                                  'navigationEndpoint': {
                                    'browseEndpoint': {
                                      'browseId': 'UCM1rew0hxgW7e-TRfmrMung',
                                      'browseEndpointContextSupportedConfigs': {
                                        'browseEndpointContextMusicConfig': {
                                          'pageType': 'MUSIC_PAGE_TYPE_ARTIST'
                                        }
                                      }
                                    }
                                  }
                                }
                              ]
                            },
                            'subtitle': {
                              'runs': [{'text': 'Artist'}]
                            },
                            'thumbnail': {
                              'musicThumbnailRenderer': {
                                'thumbnail': {
                                  'thumbnails': [{'url': 'https://example.com/artist.jpg'}]
                                }
                              }
                            },
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'playlistItemData': {'videoId': 'yLpuQXM4dSM'},
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'her (feat. OXYGEN)'}]}
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'Song'}, {'text': ' • '}, {'text': 'JVKE'}, {'text': ' • '}, {'text': '3:12'}]}
                                      }
                                    }
                                  ],
                                  'thumbnail': {
                                    'musicThumbnailRenderer': {
                                      'thumbnail': {
                                        'thumbnails': [{'url': 'https://example.com/her.jpg'}]
                                      }
                                    }
                                  }
                                }
                              }
                            ]
                          }
                        },
                        // Section 1: Item section where videoId is in thumbnail overlay (e.g. single/album)
                        {
                          'itemSectionRenderer': {
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'navigationEndpoint': {
                                    'browseEndpoint': {
                                      'browseId': 'MPREb_123',
                                      'browseEndpointContextSupportedConfigs': {
                                        'browseEndpointContextMusicConfig': {
                                          'pageType': 'MUSIC_PAGE_TYPE_ALBUM'
                                        }
                                      }
                                    }
                                  },
                                  'overlay': {
                                    'musicItemThumbnailOverlayRenderer': {
                                      'content': {
                                        'musicPlayButtonRenderer': {
                                          'playNavigationEndpoint': {
                                            'watchEndpoint': {'videoId': 'oRO3GtaXdAc'}
                                          }
                                        }
                                      }
                                    }
                                  },
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'i\'m not okay'}]}
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'Single'}, {'text': ' • '}, {'text': 'JVKE'}, {'text': ' • '}, {'text': '2:45'}]}
                                      }
                                    }
                                  ],
                                  'thumbnail': {
                                    'musicThumbnailRenderer': {
                                      'thumbnail': {
                                        'thumbnails': [{'url': 'https://example.com/imnotokay.jpg'}]
                                      }
                                    }
                                  }
                                }
                              }
                            ]
                          }
                        },
                        // Section 2: Duplicate item (should be deduplicated)
                        {
                          'itemSectionRenderer': {
                            'contents': [
                              {
                                'musicResponsiveListItemRenderer': {
                                  'playlistItemData': {'videoId': 'yLpuQXM4dSM'},
                                  'flexColumns': [
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'her (feat. OXYGEN)'}]}
                                      }
                                    },
                                    {
                                      'musicResponsiveListItemFlexColumnRenderer': {
                                        'text': {'runs': [{'text': 'Song'}, {'text': ' • '}, {'text': 'JVKE'}]}
                                      }
                                    }
                                  ]
                                }
                              }
                            ]
                          }
                        }
                      ]
                    }
                  }
                }
              }
            ]
          }
        }
      };

      final client = StubInnerTubeClient((endpoint, payload) {
        if (endpoint == 'search') return mockData;
        if (endpoint == 'browse') return {'contents': {}};
        return {};
      });

      final repo = YoutubeSearchRepository(client);
      final results = await repo.search('jvke');

      // Must find both tracks without throwing away Section 0 or Section 1, and deduplicating
      expect(results.length, equals(2));
      expect(results[0].id, equals('yLpuQXM4dSM'));
      expect(results[0].title, equals('her (feat. OXYGEN)'));
      expect(results[1].id, equals('oRO3GtaXdAc'));
      expect(results[1].title, equals('i\'m not okay'));
    });
  });

  group('PlaybackArchitectureService Prefetch Removal Tests', () {
    test('predictiveFetch is harmless no-op without timers or background fetching', () {
      final fakeRepo = _StubYoutubeStreamRepo();
      final container = ProviderContainer(
        overrides: [
          youtubeStreamRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final archService = container.read(playbackArchitectureServiceProvider);

      // Calling predictiveFetch does not crash and does not start any 15-second timers
      expect(() => archService.predictiveFetch(['qez94wCfmxw', 'secondId']), returnsNormally);
      archService.clearCache();
    });
  });
}
