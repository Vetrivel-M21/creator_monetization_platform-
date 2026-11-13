import React from 'react';
import { Users, Bell, Check, Clock, Compass, Sparkles } from 'lucide-react';
import type { Video } from '../types';
import { formatDuration } from '../utils/formatters';

interface SubscriptionsViewProps {
  videos: Video[];
  onSelectVideo: (video: Video) => void;
  onNavigateTab?: (tab: string) => void;
}

export const SubscriptionsView: React.FC<SubscriptionsViewProps> = ({
  videos,
  onSelectVideo,
  onNavigateTab,
}) => {
  const creatorsMap = new Map();
  videos.forEach((v) => {
    const handle = v.creatorHandle || v.creator_name || 'creator';
    if (!creatorsMap.has(handle)) {
      creatorsMap.set(handle, {
        name: v.creatorName || v.creator_name || 'Aura Creator',
        handle: handle,
        avatar: v.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${handle}`,
        videosCount: 0,
      });
    }
    creatorsMap.get(handle).videosCount++;
  });

  const creators = Array.from(creatorsMap.values());

  return (
    <div className="flex flex-col gap-6 pb-24 max-w-7xl mx-auto animate-fade-in">
      {/* Top Banner & Header */}
      <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#2563EB] shrink-0">
            <Users size={22} strokeWidth={2.2} />
          </div>
          <div>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-[#0F172A]">
              Subscriptions & Following
            </h1>
            <p className="text-xs text-[#64748B] mt-0.5 font-normal">
              Original releases from verified human creators and studio channels you follow
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="px-3 py-1 rounded-full bg-[#F1F5F9] border border-[#DCE7F6] text-xs font-mono text-[#64748B]">
            {creators.length} Channels Followed
          </span>
        </div>
      </div>

      {/* Subscribed Channels Rail */}
      {creators.length > 0 ? (
        <div className="p-6 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-6 h-6 rounded-lg bg-[#E0EDFF] flex items-center justify-center text-[#2563EB]">
                <Users size={14} />
              </div>
              <h2 className="text-sm font-bold text-[#0F172A] tracking-tight">
                Active Creator Channels ({creators.length})
              </h2>
            </div>
            <span className="text-xs text-emerald-700 font-mono flex items-center gap-1.5 font-semibold">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              Real-time alerts active
            </span>
          </div>

          <div className="flex items-center gap-5 overflow-x-auto pb-2 scrollbar-none">
            {creators.map((c) => (
              <div
                key={c.handle}
                className="flex flex-col items-center gap-2 shrink-0 group cursor-pointer transition-transform hover:-translate-y-0.5"
              >
                <div className="relative">
                  <div className="w-14 h-14 rounded-2xl bg-slate-100 border-2 border-[#DCE7F6] p-0.5 group-hover:border-[#2563EB] transition-all duration-300 shadow-sm">
                    <img
                      src={c.avatar}
                      alt={c.name}
                      className="w-full h-full rounded-[14px] object-cover bg-slate-100"
                    />
                  </div>
                  <div className="absolute -bottom-1 -right-1 w-4 h-4 rounded-full bg-[#2563EB] border-2 border-white flex items-center justify-center shadow-sm">
                    <Check size={9} className="text-white stroke-[3]" />
                  </div>
                </div>
                <span className="text-xs font-semibold text-[#64748B] group-hover:text-[#0F172A] max-w-[80px] truncate text-center">
                  {c.name}
                </span>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="py-16 px-6 text-center rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] max-w-xl mx-auto space-y-4 shadow-sm">
          <div className="w-14 h-14 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center mx-auto text-[#2563EB]">
            <Users size={24} />
          </div>
          <div className="space-y-1">
            <h3 className="text-sm font-bold text-[#0F172A]">No followed creators yet</h3>
            <p className="text-xs text-[#64748B] font-normal">
              Follow talented creators while browsing or watching videos to receive notifications and see their latest uploads here.
            </p>
          </div>
          {onNavigateTab && (
            <button
              onClick={() => onNavigateTab('discover')}
              className="btn-primary-pill inline-flex items-center gap-2 px-5 py-2 text-xs font-bold"
            >
              <Compass size={13} />
              <span>Browse Creators & Videos</span>
            </button>
          )}
        </div>
      )}

      {/* Latest Releases Grid */}
      <div className="space-y-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Bell size={16} className="text-[#2563EB]" />
            <h3 className="text-base font-bold text-[#0F172A] tracking-tight">
              Latest Episodes & Releases
            </h3>
          </div>
          <span className="text-xs text-[#64748B] font-mono">
            {videos.length} new upload{videos.length > 1 ? 's' : ''}
          </span>
        </div>

        {videos.length === 0 ? (
          <div className="py-16 text-center rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] space-y-3 shadow-sm">
            <Sparkles size={28} className="mx-auto text-slate-400" />
            <p className="text-sm font-semibold text-[#0F172A]">All caught up!</p>
            <p className="text-xs text-[#64748B] font-normal">No unread releases from your followed creators at this time.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {videos.map((video) => (
              <div
                key={video.id}
                onClick={() => onSelectVideo(video)}
                className="group cursor-pointer overflow-hidden flex flex-col rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] hover:border-[#BFDBFE] shadow-sm hover:shadow-md transition-all duration-300"
              >
                <div className="relative aspect-video bg-slate-100 overflow-hidden">
                  <img
                    src={video.thumbnailUrl || video.thumbnail_url}
                    alt={video.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]"
                  />
                  <div className="absolute bottom-2.5 right-2.5 bg-black/75 backdrop-blur-md px-2 py-0.5 rounded-md text-[10px] font-mono text-white border border-white/10">
                    {formatDuration(video.duration_minutes, video.duration)}
                  </div>
                </div>

                <div className="p-4 sm:p-5 flex items-start gap-3.5 flex-1 bg-white">
                  <img
                    src={video.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${video.creatorHandle || video.creator_name}`}
                    alt={video.creatorName || video.creator_name}
                    className="w-9 h-9 rounded-full border border-[#DCE7F6] shrink-0 object-cover mt-0.5"
                  />
                  <div className="min-w-0 flex-1 space-y-1">
                    <h4 className="text-sm font-semibold text-[#0F172A] line-clamp-2 leading-snug group-hover:text-[#2563EB] transition-colors">
                      {video.title}
                    </h4>
                    <p className="text-xs text-[#64748B] font-normal truncate">
                      {video.creatorName || video.creator_name} • @{video.creatorHandle || 'creator'}
                    </p>
                    <p className="text-[11px] text-[#64748B] font-mono flex items-center gap-1 pt-1">
                      <Clock size={11} /> {(video.views || video.views_count || 0).toLocaleString()} views
                    </p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

