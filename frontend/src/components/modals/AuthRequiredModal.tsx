import React from 'react';
import { X, Heart, MessageCircle, UserPlus, LogIn, Lock } from 'lucide-react';

export type AuthGateAction = 'like' | 'comment' | 'subscribe';

interface AuthRequiredModalProps {
  isOpen: boolean;
  action: AuthGateAction;
  details?: string;
  onClose: () => void;
  onLogin: () => void;
}

export const AuthRequiredModal: React.FC<AuthRequiredModalProps> = ({
  isOpen,
  action,
  details,
  onClose,
  onLogin,
}) => {
  if (!isOpen) return null;

  const contentMap = {
    like: {
      icon: <Heart size={24} className="text-rose-500 fill-rose-500" />,
      bg: 'bg-rose-50 border-rose-200',
      title: 'Sign in to like this video',
      description: 'Liking lets creator know you appreciate their work and helps personalize your recommendations.',
    },
    comment: {
      icon: <MessageCircle size={24} className="text-[#2563EB]" />,
      bg: 'bg-blue-50 border-blue-200',
      title: 'Sign in to join the discussion',
      description: 'Leave comments, discuss ideas, and connect directly with the creators in the community.',
    },
    subscribe: {
      icon: <UserPlus size={24} className="text-[#2563EB]" />,
      bg: 'bg-blue-50 border-blue-200',
      title: details ? `Subscribe to ${details}` : 'Sign in to follow creators',
      description: 'Follow channels to get their latest premieres and support their journey toward milestones.',
    },
  };

  const current = contentMap[action] || contentMap.like;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-xs animate-fade-in">
      <div className="w-full max-w-sm sm:max-w-md bg-[#FFFFFF] rounded-3xl border border-[#DCE7F6] shadow-2xl p-6 sm:p-7 space-y-6 animate-scale-up relative">
        {/* Close Icon */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-1.5 rounded-full text-[#64748B] hover:text-[#0F172A] hover:bg-[#F1F5F9] transition-colors cursor-pointer"
          aria-label="Close dialog"
        >
          <X size={18} />
        </button>

        {/* Action Header */}
        <div className="flex flex-col items-center text-center space-y-3 pt-2">
          <div className={`w-14 h-14 rounded-2xl border flex items-center justify-center ${current.bg} shadow-xs`}>
            {current.icon}
          </div>
          <div className="space-y-1">
            <h3 className="text-base sm:text-lg font-bold text-[#0F172A] tracking-tight">
              {current.title}
            </h3>
            <p className="text-xs text-[#64748B] leading-relaxed max-w-xs mx-auto">
              {current.description}
            </p>
          </div>
        </div>

        {/* Feature Highlights */}
        <div className="p-3.5 rounded-2xl bg-[#F8FAFC] border border-[#DCE7F6] space-y-2">
          <div className="flex items-center gap-2 text-xs text-[#0F172A] font-medium">
            <Lock size={13} className="text-[#2563EB] shrink-0" />
            <span>Pure Creator Platform & Safe Community</span>
          </div>
          <p className="text-[11px] text-[#64748B] leading-normal">
            Guests can watch all approved videos anytime. An account is only required to like, comment, bookmark, and follow creators.
          </p>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center gap-3 pt-1">
          <button
            type="button"
            onClick={onClose}
            className="flex-1 py-2.5 rounded-xl text-xs font-semibold text-[#64748B] hover:text-[#0F172A] bg-[#F1F5F9] hover:bg-[#E2E8F0] transition-colors cursor-pointer text-center"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => {
              onClose();
              onLogin();
            }}
            className="flex-1 btn-pill-primary py-2.5 text-xs font-semibold flex items-center justify-center gap-1.5 cursor-pointer shadow-md"
          >
            <LogIn size={14} />
            <span>Log In / Sign Up</span>
          </button>
        </div>
      </div>
    </div>
  );
};
