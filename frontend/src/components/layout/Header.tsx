import React, { useState } from 'react';
import { Search, Upload, LogIn, LogOut, Video, Sparkles, Wallet, Building, Shield, ChevronDown, Headphones } from 'lucide-react';
import type { User, UserKYC, StudioSection } from '../../types';

interface HeaderProps {
  searchQuery: string;
  setSearchQuery: (q: string) => void;
  user: User | null;
  kyc: UserKYC | null;
  onOpenUpload: () => void;
  onOpenAuth: () => void;
  onLogout: () => void;
  onNavigateStudio: (section: StudioSection) => void;
  onOpenKYC: () => void;
  onNavigateAdmin: () => void;
  onOpenSupport?: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  searchQuery,
  setSearchQuery,
  user,
  kyc,
  onOpenUpload,
  onOpenAuth,
  onLogout,
  onNavigateStudio,
  onOpenKYC,
  onNavigateAdmin,
  onOpenSupport,
}) => {
  const [showProfileMenu, setShowProfileMenu] = useState(false);

  return (
    <header className="ott-header">
      {/* Search Input Box */}
      <div className="header-search-box">
        <Search
          size={16}
          strokeWidth={2}
          className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-400 pointer-events-none"
        />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search videos, creators, tech..."
          className="header-search-input"
        />
        {searchQuery && (
          <button
            onClick={() => setSearchQuery('')}
            className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-400 hover:text-white text-xs cursor-pointer"
          >
            ✕
          </button>
        )}
      </div>

      {/* Right Action Controls */}
      <div className="flex items-center gap-3">
        {/* Creator Partner Status Chip (Amounts kept inside Monetization) */}
        {user && (
          <div className="hidden sm:flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#E0EDFF] border border-[#BFDBFE] text-xs">
            <span className="w-2 h-2 rounded-full bg-[#10B981] animate-pulse" />
            <span className="text-[#1D4ED8] font-semibold text-[11px] font-mono uppercase tracking-wider">
              {user.tier || 'Silver'} Partner
            </span>
          </div>
        )}

        {/* Support Chat Action */}
        {user && onOpenSupport && (
          <button
            onClick={onOpenSupport}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-white hover:bg-[#F0F6FF] border border-[#DCE7F6] hover:border-[#BFDBFE] text-xs font-semibold text-[#1E293B] shadow-sm transition-all cursor-pointer"
            title="Open Creator Support Desk"
          >
            <Headphones size={14} className="text-[#2563EB]" />
            <span className="hidden md:inline">Support</span>
          </button>
        )}

        {/* Upload Action */}
        <button
          onClick={onOpenUpload}
          className="btn-carmine-pill"
        >
          <Upload size={14} strokeWidth={2.4} />
          <span>Upload</span>
        </button>

        {user ? (
          <div className="relative">
            <button
              onClick={() => setShowProfileMenu((m) => !m)}
              className="flex items-center gap-2.5 p-1 pl-1.5 pr-2.5 rounded-full bg-white hover:bg-[#F8FAFC] border border-[#DCE7F6] hover:border-[#BFDBFE] transition-all cursor-pointer shadow-sm"
            >
              <div className="w-7 h-7 rounded-full bg-gradient-to-tr from-blue-100 to-blue-50 border border-blue-200 flex items-center justify-center font-bold text-xs text-[#2563EB]">
                {user.name ? user.name[0].toUpperCase() : 'U'}
              </div>
              <span className="text-xs font-semibold text-[#0F172A] max-w-[110px] truncate">
                {user.name}
              </span>
              <ChevronDown size={13} className="text-[#64748B]" />
            </button>

            {/* Profile Dropdown */}
            {showProfileMenu && (
              <>
                <div
                  className="fixed inset-0 z-40 bg-black/20 backdrop-blur-[2px]"
                  onClick={() => setShowProfileMenu(false)}
                />
                <div className="absolute right-0 top-12 w-72 p-2.5 rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-[0_15px_35px_rgba(220,231,246,0.95)] z-50 animate-fade-in space-y-1">
                  <div className="p-3 pb-3.5 border-b border-[#DCE7F6] flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-100 to-blue-50 border border-blue-200 flex items-center justify-center text-sm font-bold text-[#2563EB] shrink-0">
                      {user.name ? user.name[0].toUpperCase() : 'U'}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-bold text-[#0F172A] truncate">{user.name}</div>
                      <div className="text-[11px] text-[#64748B] truncate">{user.email || user.mobile}</div>
                      <div className="mt-1 inline-flex items-center px-2 py-0.5 rounded-full bg-[#E0EDFF] border border-[#BFDBFE] text-[10px] font-medium text-[#1D4ED8] uppercase tracking-wider font-mono">
                        {user.tier || 'Silver'} Creator
                      </div>
                    </div>
                  </div>

                  <div className="py-1 space-y-0.5">
                    <button
                      onClick={() => {
                        onNavigateStudio('dashboard');
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-medium text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer text-left"
                    >
                      <Video size={15} className="text-[#2563EB]" />
                      <span>Creator Studio Dashboard</span>
                    </button>

                    <button
                      onClick={() => {
                        onNavigateStudio('monetization');
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-medium text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer text-left"
                    >
                      <Sparkles size={15} className="text-[#F59E0B]" />
                      <span>Monetization & Quotas</span>
                    </button>

                    <button
                      onClick={() => {
                        onNavigateStudio('payouts');
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer text-left"
                    >
                      <div className="flex items-center gap-2.5">
                        <Wallet size={15} className="text-[#10B981]" />
                        <span>Wallet & Payouts</span>
                      </div>
                      <span className="font-mono text-[11px] font-semibold text-[#10B981]">
                        ₹{(user.wallet_amount ?? user.balance ?? 250).toFixed(2)}
                      </span>
                    </button>

                    <button
                      onClick={() => {
                        onOpenKYC();
                        setShowProfileMenu(false);
                      }}
                      className="w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-medium text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer text-left"
                    >
                      <div className="flex items-center gap-2.5">
                        <Building size={15} className="text-[#64748B]" />
                        <span>Banking KYC</span>
                      </div>
                      <span className={`text-[10px] font-semibold px-2 py-0.5 rounded-full ${
                        kyc?.is_verified
                          ? 'bg-[#10B981]/15 text-[#10B981] border border-[#10B981]/30'
                          : 'bg-slate-100 text-[#64748B]'
                      }`}>
                        {kyc?.is_verified ? 'Verified' : 'Pending'}
                      </span>
                    </button>

                    {onOpenSupport && (
                      <button
                        onClick={() => {
                          onOpenSupport();
                          setShowProfileMenu(false);
                        }}
                        className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-medium text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer text-left"
                      >
                        <Headphones size={15} className="text-[#2563EB]" />
                        <span>Creator Support Desk</span>
                      </button>
                    )}

                    {user.role === 'admin' && (
                      <button
                        onClick={() => {
                          onNavigateAdmin();
                          setShowProfileMenu(false);
                        }}
                        className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-semibold text-amber-700 hover:bg-amber-50 transition-colors cursor-pointer text-left"
                      >
                        <Shield size={15} />
                        <span>Admin Moderation Desk</span>
                      </button>
                    )}
                  </div>

                  <div className="pt-1 border-t border-[#DCE7F6]">
                    <button
                      onClick={() => {
                        setShowProfileMenu(false);
                        onLogout();
                      }}
                      className="w-full flex items-center gap-2.5 px-3 py-2 rounded-xl text-xs font-medium text-red-600 hover:bg-red-50 transition-colors cursor-pointer text-left"
                    >
                      <LogOut size={15} />
                      <span>Sign Out</span>
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>
        ) : (
          <button
            onClick={onOpenAuth}
            className="btn-primary-pill"
          >
            <LogIn size={14} strokeWidth={2.4} />
            <span>Sign In</span>
          </button>
        )}
      </div>
    </header>
  );
};
