import React, { useState } from 'react';
import { Bookmark, Heart, History, Clock, Compass, Play } from 'lucide-react';
import type { Video } from '../types';
import { formatDuration } from '../utils/formatters';

interface LibraryViewProps {
  savedVideos: Video[];
  likedVideos: Video[];
  onSelectVideo: (video: Video) => void;
  onClearHistory?: () => void;
  onNavigateTab?: (tab: string) => void;
}

export const LibraryView: React.FC<LibraryViewProps> = ({
  savedVideos,
  likedVideos,
  onSelectVideo,
  onNavigateTab,
}) => {
  const [activeTab, setActiveTab] = useState<'saved' | 'liked' | 'history'>('saved');

  const displayVideos =
    activeTab === 'saved' ? savedVideos : activeTab === 'liked' ? likedVideos : [];

  return (
    <div className="flex flex-col gap-6 pb-24 max-w-7xl mx-auto animate-fade-in">
      {/* Top Banner & Header */}
      <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#2563EB] shrink-0 shadow-sm">
            <Bookmark size={22} strokeWidth={2.2} />
          </div>
          <div>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-[#0F172A]">
              Your Personal Library
            </h1>
            <p className="text-xs text-[#64748B] mt-0.5 font-normal">
              Access your bookmarked masterclasses, liked creator releases, and watch milestones
            </p>
          </div>
        </div>
      </div>

      {/* Standalone Full-Width Sub-tabs Navigation */}
      <div className="flex items-center gap-6 sm:gap-8 border-b border-[#DCE7F6] pb-px">
        {[
          { id: 'saved' as const, label: 'Saved Bookmarks', count: savedVideos.length, icon: Bookmark },
          { id: 'liked' as const, label: 'Liked Videos', count: likedVideos.length, icon: Heart },
          { id: 'history' as const, label: 'Watch History', count: 0, icon: History },
        ].map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center gap-2 pb-3 pt-1 text-xs sm:text-sm transition-all duration-200 cursor-pointer whitespace-nowrap ${
                isActive
                  ? 'border-b-2 border-[#2563EB] pb-2 text-[#2563EB] font-bold'
                  : 'border-b-2 border-transparent text-[#64748B] hover:text-[#0F172A] font-medium'
              }`}
            >
              <Icon size={15} strokeWidth={isActive ? 2.2 : 1.8} className={isActive ? 'text-[#2563EB]' : 'text-[#64748B]'} />
              <span>{tab.label}</span>
              <span className="text-[10px] font-mono text-[#64748B]">({tab.count})</span>
            </button>
          );
        })}
      </div>

      {/* Grid or Empty State */}
      {displayVideos.length === 0 ? (
        <div className="py-20 px-6 flex flex-col items-center justify-center text-center rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm max-w-xl mx-auto space-y-5">
          <div className="relative w-16 h-16 rounded-3xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#2563EB] shadow-sm">
            {activeTab === 'saved' ? (
              <Bookmark size={26} className="text-[#2563EB]" />
            ) : activeTab === 'liked' ? (
              <Heart size={26} className="text-[#2563EB]" />
            ) : (
              <History size={26} className="text-[#64748B]" />
            )}
            <div className="absolute -inset-1 rounded-3xl bg-gradient-to-tr from-blue-200/40 to-transparent blur-md -z-10" />
          </div>

          <div className="space-y-1.5 flex flex-col items-center">
            <h3 className="text-base font-bold text-[#0F172A] tracking-tight">
              No videos in your {activeTab === 'saved' ? 'saved bookmarks' : activeTab === 'liked' ? 'liked videos' : 'watch history'}
            </h3>
            <p className="text-xs text-[#64748B] leading-relaxed max-w-md mx-auto font-normal">
              {activeTab === 'saved'
                ? 'Save your favorite technical talks, coding tutorials, and original creator episodes to build your curated library.'
                : activeTab === 'liked'
                ? 'Like videos you enjoy while browsing the feed or watching in theater mode to keep them in this collection.'
                : 'Videos you watch on ARMSS Entertainment will automatically be recorded here for seamless continuation.'}
            </p>
          </div>

          {onNavigateTab && (
            <div className="pt-2">
              <button
                onClick={() => onNavigateTab('discover')}
                className="btn-primary-pill inline-flex items-center gap-2 px-6 py-2.5 text-xs font-bold cursor-pointer hover:scale-105 active:scale-95 transition-all shadow-md"
              >
                <Compass size={14} />
                <span>Explore Trending Releases</span>
              </button>
            </div>
          )}
        </div>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center justify-between text-xs text-[#64748B] font-mono">
            <span>Showing {displayVideos.length} {activeTab === 'saved' ? 'bookmarked' : 'liked'} video{displayVideos.length > 1 ? 's' : ''}</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            {displayVideos.map((video) => (
              <div
                key={video.id}
                onClick={() => onSelectVideo(video)}
                className="group cursor-pointer overflow-hidden flex flex-col rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] hover:border-[#BFDBFE] shadow-sm hover:shadow-md transition-all duration-300"
              >
                {/* Clean Thumbnail - Duration pill only pinned to bottom-right */}
                <div className="relative aspect-video bg-slate-100 overflow-hidden">
                  <img
                    src={video.thumbnailUrl || video.thumbnail_url}
                    alt={video.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)]"
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                    <div className="w-12 h-12 rounded-full bg-white text-black flex items-center justify-center shadow-lg transform scale-90 group-hover:scale-100 transition-transform">
                      <Play size={20} className="fill-black ml-0.5" />
                    </div>
                  </div>
                  <div className="absolute bottom-2.5 right-2.5 bg-black/75 backdrop-blur-md px-2 py-0.5 rounded-md text-[10px] font-mono text-white border border-white/10">
                    {formatDuration(video.duration_minutes, video.duration)}
                  </div>
                </div>

                <div className="p-4 sm:p-5 flex-1 space-y-1.5 flex flex-col justify-between bg-white">
                  <div className="space-y-1">
                    <h4 className="text-sm font-semibold text-[#0F172A] line-clamp-2 leading-snug group-hover:text-[#2563EB] transition-colors">
                      {video.title}
                    </h4>
                    <p className="text-xs text-[#64748B] font-normal truncate">
                      {video.creatorName || video.creator_name} • {video.category}
                    </p>
                  </div>
                  <div className="flex items-center justify-between pt-2 border-t border-[#DCE7F6] text-[11px] text-[#64748B] font-mono">
                    <span className="flex items-center gap-1">
                      <Clock size={11} /> {(video.views || video.views_count || 0).toLocaleString()} views
                    </span>
                    <span className="text-emerald-700 font-semibold">Ready to Watch</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

