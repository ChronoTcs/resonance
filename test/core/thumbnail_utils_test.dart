import 'package:flutter_test/flutter_test.dart';
import 'package:resonance/core/utils/thumbnail_utils.dart';

void main() {
  group('ThumbnailUtils Fallback Ladder Tests', () {
    test('upgradeResolution upgrades low-res parameters to 1080p', () {
      const url1 = 'https://lh3.googleusercontent.com/abc=w120-h120-l90-rj';
      expect(ThumbnailUtils.upgradeResolution(url1),
          equals('https://lh3.googleusercontent.com/abc=w1080-h1080-l90-rj'));

      const url2 = 'https://yt3.googleusercontent.com/xyz=s120';
      expect(ThumbnailUtils.upgradeResolution(url2),
          equals('https://yt3.googleusercontent.com/xyz=s1080'));

      const ytVideoUrl = 'https://i.ytimg.com/vi/12345/hqdefault.jpg';
      expect(ThumbnailUtils.upgradeResolution(ytVideoUrl),
          equals('https://i.ytimg.com/vi/12345/maxresdefault.jpg'));
    });

    test('getFallbackResolution provides safe 544p / hqdefault fallback when 1080p fails', () {
      const hdUrl1 = 'https://yt3.googleusercontent.com/xyz=w1080-h1080-l90-rj';
      expect(ThumbnailUtils.getFallbackResolution(hdUrl1),
          equals('https://yt3.googleusercontent.com/xyz=w544-h544-l90-rj'));

      const hdUrl2 = 'https://yt3.googleusercontent.com/xyz=s1080';
      expect(ThumbnailUtils.getFallbackResolution(hdUrl2),
          equals('https://yt3.googleusercontent.com/xyz=s544'));

      const maxResYtUrl = 'https://i.ytimg.com/vi/12345/maxresdefault.jpg';
      expect(ThumbnailUtils.getFallbackResolution(maxResYtUrl),
          equals('https://i.ytimg.com/vi/12345/hqdefault.jpg'));
    });

    test('getFallbackResolution returns null for URLs not using 1080p upgrade parameters', () {
      const normalUrl = 'https://example.com/cover.jpg';
      expect(ThumbnailUtils.getFallbackResolution(normalUrl), isNull);

      expect(ThumbnailUtils.getFallbackResolution(''), isNull);
      expect(ThumbnailUtils.getFallbackResolution(null), isNull);
    });

    test('toCardResolution provides clean 400x400 parameter for cards and tiles', () {
      const url1 = 'https://lh3.googleusercontent.com/abc=w120-h120-l90-rj';
      expect(ThumbnailUtils.toCardResolution(url1),
          equals('https://lh3.googleusercontent.com/abc=w400-h400-l90-rj'));

      const url2 = 'https://yt3.googleusercontent.com/xyz=s120';
      expect(ThumbnailUtils.toCardResolution(url2),
          equals('https://yt3.googleusercontent.com/xyz=s400'));

      const ytVideoUrl = 'https://i.ytimg.com/vi/12345/maxresdefault.jpg';
      expect(ThumbnailUtils.toCardResolution(ytVideoUrl),
          equals('https://i.ytimg.com/vi/12345/mqdefault.jpg'));

      expect(ThumbnailUtils.toCardResolution(''), equals(''));
      expect(ThumbnailUtils.toCardResolution(null), equals(''));
    });
  });
}
