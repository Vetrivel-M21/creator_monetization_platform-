import React, { useState, useEffect } from 'react';
import { Play, Eye, Clock, Flame, ArrowUpRight, TrendingUp } from 'lucide-react';
import type { Video, Category } from '../types';
import { formatDuration } from '../utils/formatters';
import { categoryService } from '../services/adminService';

interface ExploreViewProps {
  videos: Video[];
  onSelectVideo: (video: Video) => void;
  onNavigateTab: (tab: string) => void;
}

const DEFAULT_CATEGORIES: Category[] = [
  { id: 'cat-self', name: 'Self / Personal', slug: 'self', description: '', is_active: true },
  { id: 'cat-promotion', name: 'Promotion', slug: 'promotion', description: '', is_active: true },
  { id: 'cat-business', name: 'Business', slug: 'business', description: '', is_active: true },
  { id: 'cat-product', name: 'Product Review', slug: 'product', description: '', is_active: true },
];

export const ExploreView: React.FC<ExploreViewProps> = ({ videos, onSelectVideo, onNavigateTab }) => {
  const [categories, setCategories] = useState<Category[]>(DEFAULT_CATEGORIES);
  const [activeCategory, setActiveCategory] = useState<string>('all');

  useEffect(() => {
    categoryService.fetchCategories()
      .then((cats) => {
        if (cats && cats.length > 0) {
          setCategories(cats);
        }
      })
      .catch((err) => console.error('Failed to load categories:', err));
  }, []);

  const filteredVideos = activeCategory === 'all'
    ? videos
    : videos.filter((v) => (v.category || '').toLowerCase() === activeCategory.toLowerCase());

  const featuredVideo = filteredVideos.find((v) => v.video_type !== 'short') || filteredVideos[0] || null;
  const reelShorts = videos.filter((v) => v.video_type === 'short' || v.durationBucket === '2m' || (v.duration_minutes || 0) <= 2).slice(0, 4);
  const upNextVideos = filteredVideos.slice(1, 4);
  const catalogVideos = filteredVideos.slice(1);

  return (
    <div className="flex flex-col gap-6 pb-24 max-w-7xl mx-auto">
      {/* Category Filter Rail with Clean Breathing Room */}
      <div className="category-filter-rail scrollbar-none">
        <button
          onClick={() => setActiveCategory('all')}
          className={`category-pill-btn ${activeCategory === 'all' ? 'active' : ''}`}
        >
          All Channels
        </button>
        {categories.map((cat) => {
          const isActive = activeCategory === cat.slug;
          return (
            <button
              key={cat.id || cat.slug}
              onClick={() => setActiveCategory(cat.slug)}
              className={`category-pill-btn ${isActive ? 'active' : ''}`}
            >
              {cat.name}
            </button>
          );
        })}
      </div>

      {/* Clean Responsive 3-Column Bento Showcase */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-stretch mb-12">
        {/* Hero Premiere Card (Strictly lg:col-span-2) */}
        {featuredVideo && (
          <div
            onClick={() => onSelectVideo(featuredVideo)}
            className="lg:col-span-2 relative rounded-3xl overflow-hidden bg-slate-900 border border-[#DCE7F6] min-h-[380px] sm:min-h-[420px] flex flex-col justify-end p-6 sm:p-8 cursor-pointer group shadow-xl transition-all duration-300 hover:shadow-2xl"
          >
            {/* Background Media */}
            <img
              src={featuredVideo.thumbnailUrl || featuredVideo.thumbnail_url}
              alt={featuredVideo.title}
              className="absolute inset-0 w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-700 ease-[cubic-bezier(0.22,1,0.36,1)]"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-slate-950/90 via-slate-950/50 to-transparent" />

            {/* Single Video Duration Pill Pinned to Bottom-Right */}
            <div className="absolute bottom-6 right-6 sm:bottom-8 sm:right-8 bg-black/75 backdrop-blur-md px-2.5 py-1 rounded-md text-xs font-mono text-white border border-white/10 z-20">
              {formatDuration(featuredVideo.duration_minutes, featuredVideo.duration)}
            </div>

            {/* Bottom Content Frame */}
            <div className="relative z-10 space-y-3 max-w-xl">
              <div className="flex items-center gap-2.5 text-xs text-slate-400 font-normal">
                <img
                  src={featuredVideo.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${featuredVideo.creatorHandle || 'creator'}`}
                  alt={featuredVideo.creatorName || featuredVideo.creator_name}
                  className="w-7 h-7 rounded-full border border-white/20 object-cover"
                />
                <span className="font-semibold text-white">
                  {featuredVideo.creatorName || featuredVideo.creator_name}
                </span>
                <span>•</span>
                <span className="font-mono">
                  {(featuredVideo.views || featuredVideo.views_count || 1420).toLocaleString()} views
                </span>
              </div>

              <h1 className="text-xl sm:text-2xl lg:text-3xl font-extrabold tracking-tight text-white leading-snug line-clamp-2">
                {featuredVideo.title}
              </h1>

              <p className="text-xs sm:text-sm text-slate-400 line-clamp-2 leading-relaxed font-normal">
                {featuredVideo.description || 'Exclusive premiere on Aura Entertainment. Pure high-definition streaming.'}
              </p>

              <div className="pt-2">
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onSelectVideo(featuredVideo);
                  }}
                  className="btn-primary-pill"
                >
                  <Play size={14} className="fill-white" />
                  <span>Watch Premiere</span>
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Up Next & Trending Releases (Strictly lg:col-span-1) */}
        <div className="lg:col-span-1 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] p-5 sm:p-6 flex flex-col justify-between shadow-md">
          <div className="space-y-4">
            <div className="flex items-center justify-between border-b border-[#DCE7F6] pb-3">
              <div className="flex items-center gap-2">
                <Flame size={15} className="text-[#2563EB] fill-[#2563EB]" />
                <span className="text-xs font-bold text-[#0F172A] uppercase tracking-wider font-mono">
                  Trending Releases
                </span>
              </div>
              <span className="text-xs text-[#64748B] font-mono">Up Next</span>
            </div>

            {/* Watchable Episode List */}
            <div className="space-y-2.5">
              {upNextVideos.length > 0 ? (
                upNextVideos.map((video) => (
                  <div
                    key={video.id}
                    onClick={() => onSelectVideo(video)}
                    className="flex items-center gap-3 p-2 rounded-2xl bg-[#F8FAFC] hover:bg-[#F0F6FF] border border-[#DCE7F6] hover:border-[#BFDBFE] transition-all duration-200 cursor-pointer group/item"
                  >
                    <div className="relative w-24 h-14 rounded-xl overflow-hidden bg-slate-900 shrink-0 border border-[#DCE7F6]">
                      <img
                        src={video.thumbnailUrl || video.thumbnail_url}
                        alt={video.title}
                        className="w-full h-full object-cover transition-transform duration-300 group-hover/item:scale-105"
                      />
                      <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/item:opacity-100 flex items-center justify-center transition-opacity">
                        <Play size={15} className="fill-white text-white" />
                      </div>
                      <span className="absolute bottom-1 right-1 px-1.5 py-0.5 rounded bg-black/75 backdrop-blur-sm text-[9px] font-mono text-white">
                        {formatDuration(video.duration_minutes, video.duration)}
                      </span>
                    </div>

                    <div className="min-w-0 flex-1 space-y-0.5">
                      <h4 className="text-xs font-semibold text-[#0F172A] line-clamp-1 group-hover/item:text-[#2563EB] transition-colors">
                        {video.title}
                      </h4>
                      <p className="text-[11px] text-[#64748B] truncate font-normal">
                        {video.creatorName || video.creator_name}
                      </p>
                      <div className="text-[10px] text-[#64748B] font-mono">
                        {(video.views || video.views_count || 0).toLocaleString()} views
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="p-8 text-center text-xs text-[#64748B] font-mono">
                  More trending episodes releasing shortly.
                </div>
              )}
            </div>
          </div>

          <button
            onClick={() => {
              const catalogEl = document.getElementById('catalog-section');
              catalogEl?.scrollIntoView({ behavior: 'smooth' });
            }}
            className="w-full mt-4 py-2.5 rounded-xl bg-[#F0F6FF] hover:bg-[#E0EDFF] text-[#2563EB] border border-[#BFDBFE] text-xs font-bold tracking-tight transition-all active:scale-[0.98] flex items-center justify-center gap-2 cursor-pointer shadow-sm"
          >
            <span>Browse Full Catalog</span>
            <ArrowUpRight size={14} />
          </button>
        </div>
      </div>

      {/* Trending Shorts & Reels */}
      {reelShorts.length > 0 && (
        <section className="space-y-4 pt-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <TrendingUp size={16} className="text-[#2563EB]" />
              <h2 className="text-base sm:text-lg font-bold tracking-tight text-[#0F172A]">
                Trending Shorts & Reels
              </h2>
            </div>
            <button
              onClick={() => onNavigateTab('feed')}
              className="text-xs font-semibold text-[#64748B] hover:text-[#2563EB] transition-colors flex items-center gap-1 cursor-pointer"
            >
              <span>Explore all reels</span>
              <ArrowUpRight size={13} />
            </button>
          </div>

          <div className="shorts-cards-grid">
            {reelShorts.map((short) => (
              <div
                key={short.id}
                onClick={() => onNavigateTab('feed')}
                className="short-card-item group"
              >
                <img
                  src={short.thumbnailUrl || short.thumbnail_url}
                  alt={short.title}
                  className="w-full h-full object-cover transition-transform duration-500 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:scale-105"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-slate-950/90 via-slate-950/30 to-transparent" />

                <div className="absolute top-3 right-3 bg-black/75 backdrop-blur-md px-2 py-0.5 rounded text-[10px] font-mono text-white border border-white/10">
                  {formatDuration(short.duration_minutes, short.duration)}
                </div>

                <div className="absolute bottom-3.5 inset-x-3.5 space-y-1">
                  <p className="text-xs font-bold text-white line-clamp-2 leading-snug">
                    {short.title}
                  </p>
                  <p className="text-[11px] text-slate-300 font-mono flex items-center gap-1">
                    <Eye size={11} /> {(short.views || short.views_count || 0).toLocaleString()} views
                  </p>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Curated Video Catalog */}
      <section id="catalog-section" className="space-y-4 pt-2">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h2 className="text-base sm:text-lg font-bold tracking-tight text-[#0F172A]">
              Curated Video Catalog
            </h2>
            <span className="text-xs text-[#64748B] font-mono">
              ({catalogVideos.length} human-authored videos)
            </span>
          </div>
        </div>

        <div className="catalog-video-grid">
          {catalogVideos.map((video) => (
            <div
              key={video.id}
              onClick={() => onSelectVideo(video)}
              className="video-catalog-card group"
            >
              {/* Thumbnail Container */}
              <div className="relative aspect-video bg-slate-100 overflow-hidden">
                <img
                  src={video.thumbnailUrl || video.thumbnail_url}
                  alt={video.title}
                  className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                />
                <div className="absolute bottom-2.5 right-2.5 bg-black/75 backdrop-blur-md px-2 py-0.5 rounded-md text-[10px] font-mono font-medium text-white border border-white/10">
                  {formatDuration(video.duration_minutes, video.duration)}
                </div>
              </div>

              {/* Card Meta Content */}
              <div className="p-4 sm:p-5 flex items-start gap-3.5 flex-1 bg-white">
                <img
                  src={video.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${video.creatorHandle || video.creator_name}`}
                  alt={video.creatorName || video.creator_name}
                  className="w-9 h-9 rounded-full border border-[#DCE7F6] shrink-0 object-cover mt-0.5"
                />
                <div className="min-w-0 flex-1 space-y-1">
                  <h3 className="text-sm font-semibold text-[#0F172A] line-clamp-2 leading-snug group-hover:text-[#2563EB] transition-colors">
                    {video.title}
                  </h3>
                  <p className="text-xs text-[#64748B] font-normal truncate">
                    {video.creatorName || video.creator_name}
                  </p>
                  <div className="flex items-center gap-2 text-[11px] text-[#64748B] font-mono pt-1">
                    <span>{(video.views || video.views_count || 0).toLocaleString()} views</span>
                    <span>•</span>
                    <span className="flex items-center gap-1">
                      <Clock size={11} /> {video.createdAt ? new Date(video.createdAt).toLocaleDateString() : 'Recent'}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};
