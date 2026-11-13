import React, { useState, useRef } from 'react';
import {
  Film,
  Upload,
  Heart,
  MessageCircle,
  Bookmark,
  Share2,
  Disc,
  Music,
  Play,
  Pause,
  Volume2,
  VolumeX,
} from 'lucide-react';
import type { Video, ReelComment } from '../../types';
import { formatDuration } from '../../utils/formatters';

interface ReelPlayerCardProps {
  video: Video;
  idx: number;
  isLiked: boolean;
  isBookmarked: boolean;
  isSubscribed: boolean;
  likesCount: number;
  commentsCount: number;
  sharesCount: number;
  creatorName: string;
  heartBurstIdx: number | null;
  onLike: (videoId: string, index?: number) => void;
  onBookmark: (videoId: string) => void;
  onShare: (videoId: string) => void;
  onSubscribe: (creatorName: string) => void;
  onOpenComments: (videoId: string) => void;
  onWatchTick: (videoId: string) => void;
}

const ReelPlayerCard: React.FC<ReelPlayerCardProps> = ({
  video,
  idx,
  isLiked,
  isBookmarked,
  isSubscribed,
  likesCount,
  commentsCount,
  sharesCount,
  creatorName,
  heartBurstIdx,
  onLike,
  onBookmark,
  onShare,
  onSubscribe,
  onOpenComments,
  onWatchTick,
}) => {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const progressBarRef = useRef<HTMLDivElement | null>(null);

  const [, setIsPlaying] = useState(true);
  const [isMuted, setIsMuted] = useState(true);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isScrubbing, setIsScrubbing] = useState(false);
  const [playStateIcon, setPlayStateIcon] = useState<'play' | 'pause' | null>(null);

  const lastClickRef = useRef<number>(0);

  // Time & Duration updates
  const handleTimeUpdate = () => {
    if (!videoRef.current || isScrubbing) return;
    setCurrentTime(videoRef.current.currentTime);
    if (!duration && videoRef.current.duration) {
      setDuration(videoRef.current.duration);
    }
    onWatchTick(video.id);
  };

  const handleLoadedMetadata = () => {
    if (videoRef.current) {
      setDuration(videoRef.current.duration || 0);
    }
  };

  // Toggle Play / Pause with animated overlay
  const togglePlayPause = () => {
    const v = videoRef.current;
    if (!v) return;

    if (v.paused) {
      v.play().catch(() => {});
      setIsPlaying(true);
      setPlayStateIcon('play');
    } else {
      v.pause();
      setIsPlaying(false);
      setPlayStateIcon('pause');
    }

    setTimeout(() => {
      setPlayStateIcon(null);
    }, 600);
  };

  // Toggle Mute / Unmute
  const toggleMute = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (!videoRef.current) return;
    const nextMuted = !videoRef.current.muted;
    videoRef.current.muted = nextMuted;
    setIsMuted(nextMuted);
  };

  // Click & Double-click disambiguation
  const handleVideoClick = () => {
    const now = Date.now();
    if (now - lastClickRef.current < 280) {
      // Double tap -> trigger like
      onLike(video.id, idx);
      lastClickRef.current = 0;
    } else {
      lastClickRef.current = now;
      setTimeout(() => {
        if (lastClickRef.current === now) {
          togglePlayPause();
        }
      }, 290);
    }
  };

  // Progress Bar Seek Calculation
  const seekToPosition = (clientX: number) => {
    const bar = progressBarRef.current;
    const v = videoRef.current;
    if (!bar || !v) return;

    const rect = bar.getBoundingClientRect();
    const clickX = Math.max(0, Math.min(clientX - rect.left, rect.width));
    const percent = clickX / rect.width;
    const newTime = percent * (duration || v.duration || 1);

    v.currentTime = newTime;
    setCurrentTime(newTime);
  };

  const handleMouseDown = (e: React.MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
    e.preventDefault();
    setIsScrubbing(true);
    seekToPosition(e.clientX);

    const onMouseMove = (moveEvent: MouseEvent) => {
      moveEvent.preventDefault();
      seekToPosition(moveEvent.clientX);
    };

    const onMouseUp = () => {
      setIsScrubbing(false);
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);
  };

  const handleTouchStart = (e: React.TouchEvent<HTMLDivElement>) => {
    e.stopPropagation();
    setIsScrubbing(true);
    seekToPosition(e.touches[0].clientX);

    const onTouchMove = (moveEvent: TouchEvent) => {
      if (moveEvent.touches.length > 0) {
        seekToPosition(moveEvent.touches[0].clientX);
      }
    };

    const onTouchEnd = () => {
      setIsScrubbing(false);
      window.removeEventListener('touchmove', onTouchMove);
      window.removeEventListener('touchend', onTouchEnd);
    };

    window.addEventListener('touchmove', onTouchMove, { passive: true });
    window.addEventListener('touchend', onTouchEnd);
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;
  const videoSrc = video.hls_url || video.hlsUrl || video.video_url || video.videoUrl || '';

  return (
    <div className="snap-reel-item relative h-[calc(100vh-140px)] min-h-[580px] max-h-[760px] rounded-3xl overflow-hidden bg-black border border-[#DCE7F6] shadow-[0_20px_50px_rgba(220,231,246,0.9)] select-none group">
      {/* Video Media (Tap to Play/Pause, Double-Tap to Like) */}
      <div className="w-full h-full relative cursor-pointer" onClick={handleVideoClick}>
        <video
          ref={videoRef}
          src={videoSrc}
          poster={video.thumbnail_url || video.thumbnailUrl}
          loop
          playsInline
          muted={isMuted}
          autoPlay
          onTimeUpdate={handleTimeUpdate}
          onLoadedMetadata={handleLoadedMetadata}
          className="w-full h-full object-cover"
        />

        {/* Play/Pause Animated Splash Indicator */}
        {playStateIcon && (
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none z-30">
            <div className="w-16 h-16 rounded-full bg-black/60 backdrop-blur-md text-white flex items-center justify-center animate-scale-up shadow-2xl">
              {playStateIcon === 'play' ? (
                <Play size={28} className="fill-white ml-1" />
              ) : (
                <Pause size={28} className="fill-white" />
              )}
            </div>
          </div>
        )}

        {/* Double-Click Heart Burst */}
        {heartBurstIdx === idx && (
          <div className="absolute top-1/2 left-1/2 pointer-events-none z-30 animate-heart-burst">
            <Heart size={90} className="fill-red-500 text-red-500 drop-shadow-2xl" />
          </div>
        )}
      </div>

      {/* Top Overlay Controls: Audio Mute/Unmute */}
      <div className="absolute top-4 right-4 z-20 flex items-center gap-2">
        <button
          onClick={toggleMute}
          className="w-9 h-9 rounded-full bg-black/50 hover:bg-black/70 backdrop-blur-md text-white border border-white/20 flex items-center justify-center transition-all cursor-pointer shadow-md"
          title={isMuted ? 'Unmute video' : 'Mute video'}
        >
          {isMuted ? <VolumeX size={16} /> : <Volume2 size={16} />}
        </button>
      </div>

      {/* Right-Hand Glass Action Bar */}
      <div className="absolute right-3 bottom-16 z-20 flex flex-col items-center gap-4">
        {/* Like */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={() => onLike(video.id, idx)}
            className={`w-11 h-11 rounded-full flex items-center justify-center backdrop-blur-xl transition-all duration-200 active:scale-[0.92] cursor-pointer ${
              isLiked
                ? 'bg-red-500/20 text-red-400 border border-red-500/40'
                : 'bg-black/50 text-white border border-white/15 hover:border-white/30'
            }`}
          >
            <Heart size={18} className={isLiked ? 'fill-red-400' : ''} />
          </button>
          <span className="text-[11px] font-mono font-semibold text-white">
            {likesCount + (isLiked ? 1 : 0)}
          </span>
        </div>

        {/* Comments */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={() => onOpenComments(video.id)}
            className="w-11 h-11 rounded-full bg-black/50 backdrop-blur-xl border border-white/15 hover:border-white/30 text-white flex items-center justify-center transition-all duration-200 active:scale-[0.92] cursor-pointer"
          >
            <MessageCircle size={18} />
          </button>
          <span className="text-[11px] font-mono font-semibold text-white">
            {commentsCount}
          </span>
        </div>

        {/* Bookmark */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={() => onBookmark(video.id)}
            className={`w-11 h-11 rounded-full flex items-center justify-center backdrop-blur-xl transition-all duration-200 active:scale-[0.92] cursor-pointer ${
              isBookmarked
                ? 'bg-amber-500/20 text-amber-300 border border-amber-500/40'
                : 'bg-black/50 text-white border border-white/15 hover:border-white/30'
            }`}
          >
            <Bookmark size={18} className={isBookmarked ? 'fill-amber-300' : ''} />
          </button>
        </div>

        {/* Share */}
        <div className="flex flex-col items-center gap-1">
          <button
            onClick={() => onShare(video.id)}
            className="w-11 h-11 rounded-full bg-black/50 backdrop-blur-xl border border-white/15 hover:border-white/30 text-white flex items-center justify-center transition-all duration-200 active:scale-[0.92] cursor-pointer"
          >
            <Share2 size={18} />
          </button>
          <span className="text-[11px] font-mono font-semibold text-white">
            {sharesCount}
          </span>
        </div>

        {/* Rotating Vinyl Audio Disc */}
        <div className="w-10 h-10 rounded-full bg-zinc-900 border-2 border-white/20 flex items-center justify-center animate-spin-disc mt-2 shadow-xl">
          <Disc size={18} className="text-[#10B981]" />
        </div>
      </div>

      {/* Bottom Gradient & Creator Meta */}
      <div className="absolute bottom-3 inset-x-0 p-5 pb-3 bg-gradient-to-t from-black via-black/60 to-transparent z-10 space-y-2 pointer-events-none">
        <div className="flex items-center justify-between pointer-events-auto">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-full bg-zinc-800 border border-white/20 flex items-center justify-center text-xs font-bold text-white">
              {creatorName[0].toUpperCase()}
            </div>
            <span className="text-xs font-bold text-white tracking-tight">
              {creatorName}
            </span>
          </div>

          <button
            onClick={() => onSubscribe(creatorName)}
            className={`text-[11px] font-semibold px-3 py-1 rounded-full transition-all active:scale-[0.98] cursor-pointer ${
              isSubscribed
                ? 'bg-white/20 text-white border border-white/30'
                : 'bg-[#2563EB] hover:bg-[#1D4ED8] text-white shadow-md'
            }`}
          >
            {isSubscribed ? 'Following' : 'Follow'}
          </button>
        </div>

        <p className="text-xs text-zinc-200 line-clamp-2 leading-snug pointer-events-auto">
          {video.title} — {video.description || 'Exclusive creator short on Aura Entertainment.'}
        </p>

        <div className="flex items-center justify-between text-[11px] text-zinc-400 font-mono">
          <div className="flex items-center gap-1.5">
            <Music size={12} />
            <span className="truncate max-w-[160px]">Original Audio • {creatorName}</span>
          </div>
          {/* Timestamp Indicator */}
          <span className="text-[10px] text-zinc-300">
            {formatDuration(currentTime / 60)} / {formatDuration((duration || video.duration_minutes || 0.5))}
          </span>
        </div>
      </div>

      {/* Modern Interactive Video Progress Bar & Scrubber */}
      <div
        ref={progressBarRef}
        onMouseDown={handleMouseDown}
        onTouchStart={handleTouchStart}
        className="absolute bottom-0 inset-x-0 z-30 h-4 flex items-end cursor-pointer group/bar"
      >
        {/* Background Track */}
        <div className={`w-full ${isScrubbing ? 'h-[6px]' : 'h-[3px] group-hover/bar:h-[6px]'} bg-white/25 backdrop-blur-xs transition-all relative`}>
          {/* Active Fill Track */}
          <div
            className="h-full bg-[#2563EB] relative"
            style={{ width: `${Math.min(100, Math.max(0, progressPercent))}%` }}
          >
            {/* Glowing Scrubber Head Indicator */}
            <div className={`absolute right-0 top-1/2 -translate-y-1/2 translate-x-1/2 w-3.5 h-3.5 rounded-full bg-white shadow-lg border border-black/10 ${isScrubbing ? 'opacity-100 scale-110' : 'opacity-0 group-hover/bar:opacity-100'} transition-all`} />
          </div>
        </div>
      </div>
    </div>
  );
};

export interface ReelsFeedProps {
  videos: Video[];
  subscribedCreators: Record<string, boolean>;
  bookmarkedVideos: Record<string, boolean>;
  likedVideos: Record<string, boolean>;
  commentsMap: Record<string, ReelComment[]>;
  onLike: (videoId: string, index?: number) => void;
  onBookmark: (videoId: string) => void;
  onShare: (videoId: string) => void;
  onSubscribe: (creatorName: string) => void;
  onOpenComments: (videoId: string) => void;
  onOpenUpload: () => void;
  onWatchTick: (videoId: string) => void;
}

export const ReelsFeed: React.FC<ReelsFeedProps> = ({
  videos,
  subscribedCreators,
  bookmarkedVideos,
  likedVideos,
  commentsMap,
  onLike,
  onBookmark,
  onShare,
  onSubscribe,
  onOpenComments,
  onOpenUpload,
  onWatchTick,
}) => {
  const [heartBurstIdx, setHeartBurstIdx] = useState<number | null>(null);

  const triggerLike = (videoId: string, idx?: number) => {
    if (idx !== undefined) {
      setHeartBurstIdx(idx);
      setTimeout(() => setHeartBurstIdx(null), 850);
    }
    onLike(videoId, idx);
  };

  return (
    <div className="flex justify-center w-full px-4 py-4">
      <div className="snap-feed-container w-full max-w-sm sm:max-w-md space-y-6">
        {/* Top Header Bar */}
        <div className="flex items-center justify-between px-2 pb-1">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 rounded-full bg-[#2563EB] animate-pulse" />
            <span className="text-xs font-bold text-[#0F172A] tracking-tight uppercase font-mono">
              Shorts & Original Reels
            </span>
          </div>

          <button
            onClick={onOpenUpload}
            className="btn-pill-primary flex items-center gap-1.5 px-3 py-1 text-[11px] font-semibold cursor-pointer"
          >
            <Upload size={12} strokeWidth={2.2} />
            <span>Post Reel</span>
          </button>
        </div>

        {videos.length === 0 ? (
          <div className="p-12 text-center rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm mt-12 space-y-3">
            <Film size={32} className="mx-auto text-[#94A3B8]" />
            <h3 className="text-sm font-semibold text-[#0F172A]">No Published Reels Yet</h3>
            <p className="text-xs text-[#64748B]">
              Verified creator reels will stream here continuously.
            </p>
          </div>
        ) : (
          videos.map((video, idx) => {
            const creatorName = video.creator_name || video.creatorName || 'Aura Creator';
            const isSubscribed = !!subscribedCreators[creatorName];
            const isBookmarked = !!bookmarkedVideos[video.id];
            const isLiked = !!likedVideos[video.id];
            const comments = commentsMap[video.id] || [];
            const likesCount = video.likes ?? video.likes_count ?? 0;
            const commentsCount = video.comments_count ?? video.commentsCount ?? comments.length;
            const sharesCount = video.shares_count ?? 0;

            return (
              <ReelPlayerCard
                key={video.id}
                video={video}
                idx={idx}
                isLiked={isLiked}
                isBookmarked={isBookmarked}
                isSubscribed={isSubscribed}
                likesCount={likesCount}
                commentsCount={commentsCount}
                sharesCount={sharesCount}
                creatorName={creatorName}
                heartBurstIdx={heartBurstIdx}
                onLike={triggerLike}
                onBookmark={onBookmark}
                onShare={onShare}
                onSubscribe={onSubscribe}
                onOpenComments={onOpenComments}
                onWatchTick={onWatchTick}
              />
            );
          })
        )}
      </div>
    </div>
  );
};
