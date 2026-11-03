import React from 'react';
import { Compass, Film, Bookmark, Video, Shield, Upload, LogIn, LogOut, Flame, Tv, ArrowRight, Headphones } from 'lucide-react';
import type { User, MainNavTab } from '../../types';

interface SidebarProps {
  activeTab: MainNavTab;
  setActiveTab: (tab: MainNavTab) => void;
  user: User | null;
  onOpenUpload: () => void;
  onOpenAuth: () => void;
  onLogout: () => void;
  onOpenSupport?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  user,
  onOpenUpload,
  onOpenAuth,
  onLogout,
  onOpenSupport,
}) => {
  const navItems = [
    { id: 'discover' as MainNavTab, label: 'Explore & Watch', icon: Film },
    { id: 'feed' as MainNavTab, label: 'Shorts & Reels', icon: Compass },
    { id: 'subscriptions' as MainNavTab, label: 'Subscriptions', icon: Tv },
    { id: 'library' as MainNavTab, label: 'Library & Saved', icon: Bookmark },
  ];

  return (
    <aside className="ott-sidebar hidden md:flex">
      <div className="space-y-5 flex-1 overflow-y-auto scrollbar-none pr-0.5">
        {/* Brand Logo Header */}
        <div className="sidebar-brand-block">
          <div className="sidebar-brand-icon">
            <Flame size={20} className="fill-white" />
          </div>
          <div className="min-w-0">
            <div className="sidebar-brand-title">
              <span>ARMSS</span>
              <span className="text-[9px] font-extrabold px-1.5 py-0.5 rounded bg-[#E0EDFF] text-[#1D4ED8] border border-[#BFDBFE] uppercase tracking-wider font-mono">
                ENTERTAINMENT
              </span>
            </div>
            <p className="sidebar-brand-subtitle">
              Creator Streaming Network
            </p>
          </div>
        </div>

        {/* Primary Navigation */}
        <nav className="space-y-1">
          <div className="sidebar-section-title">
            Navigation
          </div>
          {navItems.map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`sidebar-nav-button ${isActive ? 'active' : ''}`}
              >
                <div className="flex items-center gap-3">
                  <Icon
                    size={17}
                    strokeWidth={isActive ? 2.2 : 1.75}
                    className={isActive ? 'text-[#2563EB]' : 'text-[#64748B]'}
                  />
                  <span>{item.label}</span>
                </div>
              </button>
            );
          })}

          {/* Creator Suite Section */}
          <div className="sidebar-section-title" style={{ marginTop: '14px' }}>
            Creator Suite
          </div>

          <button
            onClick={() => {
              if (!user) {
                onOpenAuth();
                return;
              }
              setActiveTab('studio');
            }}
            className={`sidebar-nav-button ${activeTab === 'studio' ? 'active' : ''}`}
          >
            <div className="flex items-center gap-3">
              <Video
                size={17}
                strokeWidth={activeTab === 'studio' ? 2.2 : 1.75}
                className={activeTab === 'studio' ? 'text-[#10B981]' : 'text-slate-400'}
              />
              <span>Creator Studio</span>
            </div>
            <span className="text-[10px] font-mono font-bold text-[#10B981] bg-[#10B981]/15 px-2 py-0.5 rounded-full border border-[#10B981]/25">
              Pro
            </span>
          </button>

          {user?.role === 'admin' && (
            <button
              onClick={() => setActiveTab('admin')}
              className={`sidebar-nav-button ${activeTab === 'admin' ? 'active' : ''}`}
            >
              <div className="flex items-center gap-3">
                <Shield size={17} strokeWidth={1.75} className="text-amber-400" />
                <span className="text-amber-300">Admin Moderation</span>
              </div>
              <span className="text-[9px] font-mono font-bold text-amber-400 bg-amber-500/10 px-2 py-0.5 rounded border border-amber-500/20">
                Staff
              </span>
            </button>
          )}

          {user && onOpenSupport && (
            <button
              onClick={onOpenSupport}
              className="sidebar-nav-button"
            >
              <div className="flex items-center gap-3">
                <Headphones size={17} strokeWidth={1.75} className="text-[#2563EB]" />
                <span>Support & Help</span>
              </div>
              <span className="text-[9px] font-mono font-bold text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                Live
              </span>
            </button>
          )}
        </nav>

        {/* Creator Studio Upload Promotion Banner */}
        <div className="sidebar-promo-card space-y-2.5">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[#0F172A] tracking-tight">Creator Program</span>
            <span className="text-[10px] font-mono font-bold text-[#10B981] bg-[#10B981]/15 px-2 py-0.5 rounded-full border border-[#10B981]/20">
              Verified
            </span>
          </div>
          <p className="text-[11px] text-[#64748B] leading-relaxed font-normal">
            Upload verified human videos to earn channel royalties directly to your bank account.
          </p>
          <button
            onClick={onOpenUpload}
            className="w-full mt-1 flex items-center justify-center gap-2 py-2 rounded-xl bg-[#2563EB] hover:bg-[#1D4ED8] text-white text-xs font-bold tracking-tight transition-all active:scale-[0.98] shadow-[0_2px_10px_rgba(37,99,235,0.3)] cursor-pointer"
          >
            <Upload size={13} strokeWidth={2.4} />
            <span>Publish Video</span>
          </button>
        </div>
      </div>

      {/* Footer Profile or Sign-in Box - Strictly p-4 mb-3 to prevent clipping */}
      <div className="sidebar-user-footer pt-3 pb-2">
        {user ? (
          <div className="flex items-center justify-between p-4 mb-3 rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm">
            <div
              onClick={() => setActiveTab('studio')}
              className="flex items-center gap-3 min-w-0 cursor-pointer flex-1"
            >
              <div className="relative">
                <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-100 to-blue-50 border border-blue-200 flex items-center justify-center font-bold text-xs text-[#2563EB]">
                  {user.name ? user.name[0].toUpperCase() : 'U'}
                </div>
              </div>
              <div className="min-w-0">
                <div className="text-xs font-bold text-[#0F172A] truncate">{user.name}</div>
                <div className="text-[10px] text-[#64748B] font-normal">
                  {user.tier || 'Silver'} Creator
                </div>
              </div>
            </div>
            <button
              onClick={onLogout}
              className="p-1.5 rounded-lg text-slate-400 hover:text-red-500 hover:bg-red-50 transition-colors cursor-pointer"
              title="Sign Out"
            >
              <LogOut size={15} />
            </button>
          </div>
        ) : (
          <button
            onClick={onOpenAuth}
            className="w-full flex items-center justify-center gap-2.5 p-4 mb-3 rounded-xl bg-[#FFFFFF] hover:bg-[#F8FAFC] text-[#0F172A] border border-[#DCE7F6] text-xs font-semibold tracking-tight transition-all active:scale-[0.98] cursor-pointer shadow-sm hover:border-[#BFDBFE]"
          >
            <LogIn size={14} className="text-[#2563EB]" />
            <span>Sign In to Platform</span>
            <ArrowRight size={13} className="text-[#64748B]" />
          </button>
        )}
      </div>
    </aside>
  );
};
