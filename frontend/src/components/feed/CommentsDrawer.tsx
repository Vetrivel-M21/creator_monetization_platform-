import React from 'react';
import { X, Send } from 'lucide-react';
import type { ReelComment } from '../../types';

interface CommentsDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  comments: ReelComment[];
  newCommentText: string;
  setNewCommentText: (text: string) => void;
  onPostComment: (e: React.FormEvent) => void;
}

export const CommentsDrawer: React.FC<CommentsDrawerProps> = ({
  isOpen,
  onClose,
  comments,
  newCommentText,
  setNewCommentText,
  onPostComment,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end bg-slate-900/40 backdrop-blur-sm animate-fade-in">
      <div className="w-full max-w-sm sm:max-w-md h-full bg-[#FFFFFF] border-l border-[#DCE7F6] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="p-5 border-b border-[#DCE7F6] flex items-center justify-between">
          <div>
            <h4 className="text-sm font-bold text-[#0F172A] tracking-tight">Community Discussion</h4>
            <span className="text-[11px] text-[#64748B] font-mono">{comments.length} comments</span>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[#F8FAFC] hover:bg-[#F0F6FF] border border-[#DCE7F6] flex items-center justify-center text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
          >
            <X size={16} />
          </button>
        </div>

        {/* Comments Feed */}
        <div className="flex-1 overflow-y-auto p-5 space-y-4">
          {comments.length === 0 ? (
            <div className="p-8 text-center text-xs text-[#64748B] font-mono">
              No comments posted yet. Spark the discussion!
            </div>
          ) : (
            comments.map((c) => (
              <div key={c.id} className="flex gap-3 items-start">
                <div className="w-8 h-8 rounded-full bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-xs font-bold text-[#1D4ED8] shrink-0 mt-0.5">
                  {c.userAvatar ? (
                    <img src={c.userAvatar} alt="avatar" className="w-full h-full rounded-full object-cover" />
                  ) : (
                    <span>{(c.author || c.userName || 'U')[0].toUpperCase()}</span>
                  )}
                </div>
                <div className="min-w-0 flex-1 space-y-0.5">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-[#0F172A]">
                      {c.author || c.userName || 'Community User'}
                    </span>
                    <span className="text-[10px] text-[#64748B] font-mono">
                      {c.time || 'just now'}
                    </span>
                  </div>
                  <p className="text-xs text-[#0F172A] leading-relaxed font-normal">{c.text}</p>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Input Bar */}
        <form onSubmit={onPostComment} className="p-4 border-t border-[#DCE7F6] flex items-center gap-2 bg-[#FFFFFF]">
          <input
            type="text"
            value={newCommentText}
            onChange={(e) => setNewCommentText(e.target.value)}
            placeholder="Share your thoughts..."
            className="flex-1 bg-[#F8FAFC] text-xs text-[#0F172A] placeholder:text-[#94A3B8] px-4 py-2.5 rounded-full border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] focus:outline-none"
          />
          <button
            type="submit"
            disabled={!newCommentText.trim()}
            className="btn-pill-primary px-4 py-2.5 text-xs font-semibold disabled:opacity-40 flex items-center gap-1.5 cursor-pointer"
          >
            <span>Send</span>
            <Send size={12} />
          </button>
        </form>
      </div>
    </div>
  );
};
