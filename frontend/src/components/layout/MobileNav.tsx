import React from 'react';
import { Film, Compass, Tv, Bookmark } from 'lucide-react';
import type { User, MainNavTab } from '../../types';

interface MobileNavProps {
  activeTab: MainNavTab;
  setActiveTab: (tab: MainNavTab) => void;
  user: User | null;
}

export const MobileNav: React.FC<MobileNavProps> = ({
  activeTab,
  setActiveTab,
}) => {
  const items = [
    { id: 'discover' as MainNavTab, icon: Film, label: 'Explore' },
    { id: 'feed' as MainNavTab, icon: Compass, label: 'Reels' },
    { id: 'subscriptions' as MainNavTab, icon: Tv, label: 'Following' },
    { id: 'library' as MainNavTab, icon: Bookmark, label: 'Library' },
  ];

  return (
    <nav className="fixed bottom-0 inset-x-0 h-16 bg-[#FFFFFF]/95 backdrop-blur-2xl border-t border-[#DCE7F6] flex items-center justify-around z-50 md:hidden px-2 shadow-[0_-4px_20px_rgba(220,231,246,0.8)]">
      {items.map((item) => {
        const Icon = item.icon;
        const isActive = activeTab === item.id;
        return (
          <button
            key={item.id}
            onClick={() => setActiveTab(item.id)}
            className={`flex flex-col items-center gap-1 py-1.5 px-3 rounded-xl transition-all ${
              isActive
                ? 'text-[#2563EB] font-bold'
                : 'text-[#64748B] hover:text-[#0F172A]'
            }`}
          >
            <div className={`p-1 rounded-lg ${isActive ? 'bg-[#E0EDFF] text-[#1D4ED8] border border-[#BFDBFE]' : ''}`}>
              <Icon size={18} strokeWidth={isActive ? 2.2 : 1.75} />
            </div>
            <span className="text-[10px] tracking-tight">{item.label}</span>
          </button>
        );
      })}
    </nav>
  );
};
