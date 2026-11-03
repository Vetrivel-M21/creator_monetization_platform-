import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Send,
  Headphones,
  Shield,
  Sparkles,
  RefreshCw,
  AlertCircle
} from 'lucide-react';
import type { SupportThread, SupportMessage } from '../../types';
import { supportService } from '../../services/adminService';

interface SupportChatModalProps {
  isOpen: boolean;
  onClose: () => void;
  userName?: string;
}

export const SupportChatModal: React.FC<SupportChatModalProps> = ({
  isOpen,
  onClose,
  userName = 'Creator'
}) => {
  const [thread, setThread] = useState<SupportThread | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [newMessage, setNewMessage] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  const loadThread = async (isInitial = false) => {
    try {
      if (isInitial) setIsLoading(true);
      const res = await supportService.fetchThread();
      setThread(res.thread);
      setMessages(res.messages || []);
      setError(null);
      if (isInitial) {
        setTimeout(scrollToBottom, 100);
      }
    } catch (err: any) {
      if (isInitial) {
        setError(err.message || 'Failed to connect to ARMSS Creator Support Desk');
      }
    } finally {
      if (isInitial) setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!isOpen) return;

    loadThread(true);

    // Auto-polling every 4 seconds for immediate two-way chat response
    const interval = setInterval(() => {
      loadThread(false);
    }, 4000);

    return () => clearInterval(interval);
  }, [isOpen]);

  useEffect(() => {
    if (messages.length > 0) {
      scrollToBottom();
    }
  }, [messages.length]);

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = newMessage.trim();
    if (!text || isSending) return;

    try {
      setIsSending(true);
      setError(null);
      const sentMsg = await supportService.sendMessage(text);
      setMessages((prev) => [...prev, sentMsg]);
      setNewMessage('');
      setTimeout(scrollToBottom, 50);
      if (inputRef.current) inputRef.current.focus();
    } catch (err: any) {
      setError(err.message || 'Failed to send message. Please retry.');
    } finally {
      setIsSending(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/50 backdrop-blur-sm animate-fade-in">
      <div className="bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl w-full max-w-lg h-[640px] max-h-[92vh] shadow-2xl flex flex-col overflow-hidden relative">
        {/* Support Desk Header */}
        <div className="p-4 sm:p-5 bg-gradient-to-r from-[#0F172A] to-[#1E293B] text-white flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-blue-600/30 border border-blue-400/40 flex items-center justify-center text-blue-400 shrink-0">
              <Headphones size={20} strokeWidth={2.4} />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-bold tracking-tight text-white">Creator Support Desk</h3>
                <span className="flex items-center gap-1 text-[10px] bg-emerald-500/20 text-emerald-300 border border-emerald-400/30 px-2 py-0.5 rounded-full font-mono font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  Live
                </span>
              </div>
              <p className="text-[11px] text-slate-300 font-normal">
                Direct messaging with ARMSS Platform Admins
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5">
            <button
              onClick={() => loadThread(false)}
              title="Refresh conversation"
              className="p-2 rounded-full text-slate-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
            >
              <RefreshCw size={15} />
            </button>
            <button
              onClick={onClose}
              className="p-2 rounded-full text-slate-400 hover:text-white hover:bg-white/10 transition-colors cursor-pointer"
            >
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Info Banner */}
        <div className="px-4 py-2.5 bg-[#F0F6FF] border-b border-[#DCE7F6] text-xs text-[#1D4ED8] flex items-center justify-between font-mono">
          <div className="flex items-center gap-1.5 truncate">
            <Sparkles size={13} className="shrink-0" />
            <span className="truncate">Tier Monetization, KYC & Video Audit Assistance</span>
          </div>
          {thread && (
            <span className="text-[10px] font-bold uppercase tracking-wider px-2 py-0.5 rounded-full bg-white border border-[#BFDBFE]">
              {thread.status}
            </span>
          )}
        </div>

        {/* Message Thread Body */}
        <div className="flex-1 p-4 sm:p-5 overflow-y-auto space-y-4 bg-[#F8FAFC]">
          {isLoading ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-400 gap-2">
              <RefreshCw size={24} className="animate-spin text-blue-600" />
              <span className="text-xs font-mono">Connecting to support secure channel...</span>
            </div>
          ) : messages.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-center p-6 space-y-3">
              <div className="w-14 h-14 rounded-full bg-blue-50 border border-blue-200 text-blue-600 flex items-center justify-center">
                <Headphones size={24} />
              </div>
              <div className="space-y-1">
                <h4 className="text-sm font-bold text-slate-800">Hello {userName}!</h4>
                <p className="text-xs text-slate-500 max-w-xs leading-relaxed">
                  Have questions about video review approval, Silver/Gold/Diamond quotas, or withdrawal payouts?
                  Send a message below to chat with an administrator.
                </p>
              </div>
              <div className="pt-2 flex flex-wrap justify-center gap-1.5 text-[11px]">
                <button
                  onClick={() => setNewMessage('Hi Admin, can you check my video approval status?')}
                  className="px-3 py-1 rounded-full bg-white border border-slate-200 text-slate-700 hover:border-blue-300 hover:text-blue-600 transition-colors cursor-pointer"
                >
                  "Check my video approval"
                </button>
                <button
                  onClick={() => setNewMessage('When will my milestone reward payout settle?')}
                  className="px-3 py-1 rounded-full bg-white border border-slate-200 text-slate-700 hover:border-blue-300 hover:text-blue-600 transition-colors cursor-pointer"
                >
                  "Milestone payout status"
                </button>
              </div>
            </div>
          ) : (
            messages.map((m) => {
              const isAdmin = m.sender_role === 'admin';
              return (
                <div
                  key={m.id}
                  className={`flex flex-col ${isAdmin ? 'items-start' : 'items-end'}`}
                >
                  <div className="flex items-center gap-1.5 mb-1 px-1 text-[11px] text-slate-400">
                    {isAdmin ? (
                      <span className="inline-flex items-center gap-1 text-[10px] font-bold text-blue-700 bg-blue-50 px-2 py-0.5 rounded-full border border-blue-200 font-mono">
                        <Shield size={10} /> ARMSS Admin Desk
                      </span>
                    ) : (
                      <span className="text-slate-500 font-mono font-medium">You</span>
                    )}
                    <span className="font-mono text-[10px]">
                      {new Date(m.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>

                  <div
                    className={`max-w-[85%] rounded-2xl px-4 py-3 text-xs leading-relaxed shadow-sm ${
                      isAdmin
                        ? 'bg-white border border-[#DCE7F6] text-slate-800 rounded-tl-sm'
                        : 'bg-[#2563EB] text-white rounded-tr-sm font-normal'
                    }`}
                  >
                    <p className="whitespace-pre-wrap break-words">{m.message}</p>
                  </div>
                </div>
              );
            })
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Error Alert */}
        {error && (
          <div className="px-4 py-2 bg-red-50 border-t border-red-200 text-red-600 text-xs flex items-center gap-2">
            <AlertCircle size={14} className="shrink-0" />
            <span className="truncate">{error}</span>
          </div>
        )}

        {/* Bottom Input Field */}
        <form
          onSubmit={handleSendMessage}
          className="p-3 sm:p-4 bg-white border-t border-[#DCE7F6] flex items-center gap-2 shrink-0"
        >
          <input
            ref={inputRef}
            type="text"
            value={newMessage}
            onChange={(e) => setNewMessage(e.target.value)}
            placeholder="Type your message to support..."
            disabled={isSending}
            className="flex-1 bg-slate-50 border border-slate-200 focus:border-blue-500 focus:bg-white rounded-full px-4 py-2.5 text-xs text-slate-800 placeholder-slate-400 outline-none transition-colors"
          />
          <button
            type="submit"
            disabled={!newMessage.trim() || isSending}
            className="w-10 h-10 rounded-full bg-[#2563EB] text-white hover:bg-blue-700 disabled:opacity-40 disabled:hover:bg-[#2563EB] flex items-center justify-center shrink-0 shadow-sm transition-all cursor-pointer"
          >
            <Send size={15} />
          </button>
        </form>
      </div>
    </div>
  );
};
