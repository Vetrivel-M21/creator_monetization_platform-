import React, { useState } from 'react';
import { X, Heart, MessageCircle, Share2, Check, UserPlus, Eye, Clock, Loader2, AlertTriangle } from 'lucide-react';
import type { Video } from '../../types';
import { HLSPlayer } from '../player/HLSPlayer';

const API_HOST = 'https://entertainment.aurapictures.online';

function toAbsoluteUrl(url: string | undefined): string {
  if (!url || url.trim() === '') return '';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url.replace(/^http:\/\//, 'https://');
  }
  return API_HOST + (url.startsWith('/') ? url : '/' + url);
}

interface TheaterModalProps {
  video: Video | null;
  isOpen: boolean;
  onClose: () => void;
  onLike: (id: string) => void;
  onShare: (video: Video) => void;
  onOpenComments: (video: Video) => void;
  isLiked?: boolean;
  onSubscribe?: (creatorHandle: string) => void;
  isSubscribed?: boolean;
}

export const TheaterModal: React.FC<TheaterModalProps> = ({
  video,
  isOpen,
  onClose,
  onLike,
  onShare,
  onOpenComments,
  isLiked = false,
  onSubscribe,
  isSubscribed = false,
}) => {
  const [localFollowing, setLocalFollowing] = useState(false);
  const isFollowing = onSubscribe ? isSubscribed : localFollowing;

  if (!isOpen || !video) return null;

  const creatorName = video.creatorName || video.creator_name || 'ARMSS Creator';
  const creatorHandle = video.creatorHandle || video.creator_name?.toLowerCase().replace(/\s+/g, '_') || 'creator';
  const creatorAvatar = video.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${creatorHandle}`;
  const thumbnailUrl = toAbsoluteUrl(video.thumbnailUrl || video.thumbnail_url);
  const views = video.views ?? video.views_count ?? 0;
  const likes = video.likes ?? video.likes_count ?? 0;
  const commentsCount = video.commentsCount ?? video.comments_count ?? 0;
  const duration = video.duration || `${video.duration_minutes || 10}:00`;
  const durationBucket = (video.durationBucket || '10M').toUpperCase();

  // Build an absolute stream URL with fallback cascade: HLS → progressive MP4
  const rawHls = video.hlsUrl || video.hls_url || '';
  const rawMp4 = video.videoUrl || video.video_url || '';
  const hlsUrl = toAbsoluteUrl(rawHls);
  const mp4Url = toAbsoluteUrl(rawMp4);
  const transcodeStatus = video.transcode_status || video.transcodeStatus || 'ready';
  const isProcessing = transcodeStatus === 'processing' || transcodeStatus === 'pending';

  // Prefer HLS; fall back to direct MP4 (which always exists in /data/masters/); 
  // if nothing exists and still processing, show processing overlay
  const streamUrl = hlsUrl || mp4Url;
  const hasPlayableUrl = streamUrl.trim() !== '';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-5xl bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl shadow-[0_25px_60px_rgba(220,231,246,0.95)] overflow-hidden flex flex-col max-h-[92vh]">
        {/* Top Control Bar */}
        <div className="flex items-center justify-between px-6 py-3.5 border-b border-[#DCE7F6] bg-[#FFFFFF]">
          <div className="flex items-center gap-3">
            <span className="text-[11px] font-bold font-mono px-3 py-0.5 rounded-full bg-[#E0EDFF] border border-[#BFDBFE] text-[#1D4ED8]">
              {durationBucket}
            </span>
            <span className="text-xs text-[#64748B] font-mono flex items-center gap-1.5 font-normal">
              <Eye size={13} /> {views.toLocaleString()} views
            </span>
            <span className="text-xs text-[#64748B] font-mono flex items-center gap-1.5 font-normal">
              <Clock size={13} /> {duration}
            </span>
            {isProcessing && (
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-50 border border-amber-200 text-amber-700 flex items-center gap-1">
                <Loader2 size={10} className="animate-spin" /> Transcoding
              </span>
            )}
          </div>

          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[#F8FAFC] hover:bg-[#F0F6FF] border border-[#DCE7F6] flex items-center justify-center text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
          >
            <X size={16} />
          </button>
        </div>

        {/* Video Player Frame with Adaptive Bitrate Streaming */}
        <div className="relative bg-black w-full aspect-video flex items-center justify-center overflow-hidden">
          {hasPlayableUrl ? (
            <HLSPlayer
              src={streamUrl}
              poster={thumbnailUrl}
              autoPlay
              className="w-full h-full"
            />
          ) : (
            <div className="flex flex-col items-center justify-center gap-3 p-8 text-center">
              {isProcessing ? (
                <>
                  <Loader2 size={36} className="animate-spin text-blue-400" />
                  <p className="text-white text-sm font-semibold">Video is being transcoded…</p>
                  <p className="text-white/60 text-xs">HLS streams will be available shortly. You can still approve or reject this video.</p>
                </>
              ) : (
                <>
                  <AlertTriangle size={36} className="text-amber-400" />
                  <p className="text-white text-sm font-semibold">Stream unavailable</p>
                  <p className="text-white/60 text-xs">No playable media URL found for this video.</p>
                </>
              )}
            </div>
          )}
        </div>

        {/* Video Metadata & Controls */}
        <div className="p-6 bg-[#FFFFFF] border-t border-[#DCE7F6] space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="space-y-1.5">
              <h1 className="text-base sm:text-xl font-bold tracking-tight text-[#0F172A] line-clamp-1">
                {video.title}
              </h1>
              <div className="flex items-center gap-3">
                <div className="flex items-center gap-2.5">
                  <img
                    src={creatorAvatar}
                    alt={creatorName}
                    className="w-7 h-7 rounded-full border border-[#DCE7F6] object-cover"
                  />
                  <div>
                    <span className="text-xs font-semibold text-[#0F172A]">{creatorName}</span>
                    <span className="text-[11px] text-[#64748B] font-mono ml-1.5 font-normal">@{creatorHandle}</span>
                  </div>
                </div>

                <button
                  onClick={() => {
                    if (onSubscribe) {
                      onSubscribe(creatorHandle);
                    } else {
                      setLocalFollowing(!localFollowing);
                    }
                  }}
                  className={`text-xs font-semibold px-3 py-1 rounded-full transition-all flex items-center gap-1.5 cursor-pointer ${
                    isFollowing
                      ? 'bg-[#F0F6FF] text-[#64748B] border border-[#DCE7F6]'
                      : 'bg-[#2563EB] hover:bg-[#1D4ED8] text-white shadow-sm'
                  }`}
                >
                  {isFollowing ? (
                    <>
                      <Check size={12} /> Subscribed
                    </>
                  ) : (
                    <>
                      <UserPlus size={12} /> Subscribe
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center gap-2.5">
              <button
                onClick={() => onLike(video.id)}
                className={`btn-pill-secondary flex items-center gap-2 px-4 py-2 text-xs font-semibold cursor-pointer ${
                  isLiked ? 'text-red-500 border-red-200 bg-red-50' : ''
                }`}
              >
                <Heart size={14} className={isLiked ? 'fill-red-500' : ''} />
                <span className="font-mono">{likes + (isLiked ? 1 : 0)}</span>
              </button>

              <button
                onClick={() => onOpenComments(video)}
                className="btn-pill-secondary flex items-center gap-2 px-4 py-2 text-xs font-semibold cursor-pointer"
              >
                <MessageCircle size={14} />
                <span className="font-mono">{commentsCount} Comments</span>
              </button>

              <button
                onClick={() => onShare(video)}
                className="btn-pill-secondary flex items-center gap-2 px-4 py-2 text-xs font-semibold cursor-pointer"
              >
                <Share2 size={14} />
                <span>Share</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
