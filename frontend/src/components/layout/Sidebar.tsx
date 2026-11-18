import React from 'react';
import { Compass, Film, Bookmark, Video, Shield, LogOut, Tv, Headphones } from 'lucide-react';
import type { User, MainNavTab } from '../../types';

interface SidebarProps {
  activeTab: MainNavTab;
  setActiveTab: (tab: MainNavTab) => void;
  user: User | null;
  onOpenUpload?: () => void;
  onOpenAuth: () => void;
  onLogout: () => void;
  onOpenSupport?: () => void;
  onOpenTerms?: () => void;
  onOpenPrivacy?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  user,
  onOpenAuth,
  onLogout,
  onOpenSupport,
  onOpenTerms,
  onOpenPrivacy,
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
        <div className="sidebar-brand-block flex items-center gap-3">
          <img
            src="/assets/aura_mobile_app_icon_dark_squircle.png"
            alt="Aura Logo"
            className="w-9 h-9 rounded-xl object-contain shadow-sm shrink-0"
          />
          <div className="min-w-0">
            <div className="sidebar-brand-title">
              <span>AURA</span>
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
                className={activeTab === 'studio' ? 'text-[#2563EB]' : 'text-[#64748B]'}
              />
              <span>Creator Studio</span>
            </div>
          </button>

          {user?.role === 'admin' && (
            <button
              onClick={() => setActiveTab('admin')}
              className={`sidebar-nav-button ${activeTab === 'admin' ? 'active' : ''}`}
            >
              <div className="flex items-center gap-3">
                <Shield
                  size={17}
                  strokeWidth={activeTab === 'admin' ? 2.2 : 1.75}
                  className={activeTab === 'admin' ? 'text-[#2563EB]' : 'text-[#64748B]'}
                />
                <span>Admin Moderation</span>
              </div>
              <span className="text-[10px] font-semibold text-[#64748B] bg-[#F1F5F9] px-1.5 py-0.5 rounded border border-[#DCE7F6]">
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
            </button>
          )}
        </nav>

        {/* Creator Program Card - Only for non-verified creators */}
        {(!user || !user.is_kyc_verified) && (
          <div className="sidebar-promo-card space-y-1.5">
            <span className="text-xs font-bold text-[#0F172A] tracking-tight">Creator Program</span>
            <p className="text-[11px] text-[#64748B] leading-relaxed font-normal">
              Upload verified human videos to earn milestone royalties directly to your bank account.
            </p>
          </div>
        )}
      </div>

      {/* Footer Area - Single Logout action when signed in without duplicated profile card */}
      <div className="sidebar-user-footer pt-3 pb-2 space-y-2">
        {user && (
          <button
            onClick={onLogout}
            className="w-full flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-semibold text-[#64748B] hover:text-red-600 hover:bg-red-50 border border-[#DCE7F6] hover:border-red-200 transition-colors cursor-pointer bg-white"
            title="Sign out of Aura"
          >
            <LogOut size={14} />
            <span>Sign Out</span>
          </button>
        )}

        {/* Legal Links */}
        <div className="pt-1 px-1 flex items-center justify-center gap-2 text-[10px] text-[#94A3B8]">
          <button
            type="button"
            onClick={onOpenTerms}
            className="hover:text-[#2563EB] transition-colors cursor-pointer"
          >
            Terms of Service
          </button>
          <span>•</span>
          <button
            type="button"
            onClick={onOpenPrivacy}
            className="hover:text-[#2563EB] transition-colors cursor-pointer"
          >
            Privacy Policy
          </button>
        </div>
      </div>
    </aside>
  );
};
