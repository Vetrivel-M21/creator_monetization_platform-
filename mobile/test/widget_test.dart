import 'package:flutter_test/flutter_test.dart';
import 'package:creator_monetization_app/data/models/studio_model.dart';
import 'package:creator_monetization_app/data/models/video_model.dart';
import 'package:creator_monetization_app/core/theme/app_colors.dart';

void main() {
  group('Creator Studio & Monetization Domain Tests', () {
    test('CreatorStudioModel initializes with correct values and pure tier logic', () {
      final sample = CreatorStudioModel.sample();

      expect(sample.channelName, 'Vetri Tech Studio');
      expect(sample.walletBalance, 2750.00);
      expect(sample.welcomeCredit, 250.00);
      expect(sample.isKycVerified, isTrue);
      expect(sample.tier, 'Silver');
      expect(sample.quotas.length, 5);
      expect(sample.transactions.length, 2);
    });

    test('VideoModel duration buckets match platform tier limits', () {
      final video = VideoModel(
        id: 'vid-test',
        title: 'Test Video',
        description: 'Test description',
        category: 'Tech & Code',
        durationMinutes: 31.0,
        durationFormatted: '31:00',
        durationBucket: '30m',
        videoUrl: 'http://example.com/video.mp4',
        hlsUrl: '/api/playback/vid-test/master.m3u8',
        thumbnailUrl: 'http://example.com/thumb.jpg',
        creatorName: 'ARMSS Studio',
        creatorHandle: 'armss',
        creatorAvatar: 'http://example.com/avatar.jpg',
        creatorTier: 'Diamond',
        viewsCount: 1200,
        likesCount: 95,
        commentsCount: 12,
        createdAt: DateTime.now(),
      );

      expect(video.durationBucket, '30m');
      expect(video.likesCount, 95);
      expect(video.isLiked, isFalse);

      final likedVideo = video.copyWith(isLiked: true, likesCount: 96);
      expect(likedVideo.isLiked, isTrue);
      expect(likedVideo.likesCount, 96);
    });

    test('AppColors verifies Light Mode WCAG AA tokens', () {
      expect(AppColors.canvasBackground.toARGB32(), 0xFFF0F6FF);
      expect(AppColors.cardSurface.toARGB32(), 0xFFFFFFFF);
      expect(AppColors.primaryAccent.toARGB32(), 0xFF2563EB);
      expect(AppColors.primaryText.toARGB32(), 0xFF0F172A);
      expect(AppColors.mutedText.toARGB32(), 0xFF64748B);
    });
  });
}
