import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _thread;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadThread();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _pollNewMessages();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadThread() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please sign in to access Creator Support Desk';
        });
      }
      return;
    }

    final data = await _apiService.fetchSupportThread(token);
    if (!mounted) return;

    if (data != null) {
      setState(() {
        _thread = data['thread'] as Map<String, dynamic>?;
        final list = data['messages'] as List?;
        _messages = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        _isLoading = false;
        _errorMessage = null;
      });
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to Support Desk';
      });
    }
  }

  Future<void> _pollNewMessages() async {
    final token = await _authService.getToken();
    if (token == null) return;

    final data = await _apiService.fetchSupportThread(token);
    if (!mounted || data == null) return;

    final list = data['messages'] as List?;
    final incoming = list?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    if (incoming.length != _messages.length) {
      setState(() {
        _messages = incoming;
        _thread = data['thread'] as Map<String, dynamic>?;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _sendMessage([String? prefilled]) async {
    final text = (prefilled ?? _msgController.text).trim();
    if (text.isEmpty || _isSending) return;

    final token = await _authService.getToken();
    if (token == null) return;

    setState(() {
      _isSending = true;
    });

    final sent = await _apiService.sendSupportMessage(token, text);
    if (!mounted) return;

    if (sent != null) {
      _msgController.clear();
      setState(() {
        _messages.add(Map<String, dynamic>.from(sent));
        _isSending = false;
      });
      Future.delayed(const Duration(milliseconds: 80), _scrollToBottom);
    } else {
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message. Please retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.support_agent, color: Color(0xFF60A5FA), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Creator Support Desk',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Admin Online',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            onPressed: _loadThread,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Ribbon
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.verified, size: 14, color: Color(0xFF93C5FD)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Milestone Payouts • Account Approval • Review Audit',
                      style: TextStyle(fontSize: 11, color: Color(0xFFBFDBFE), fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (_thread != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (_thread!['status'] ?? 'open').toString().toUpperCase(),
                        style: const TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Message Body
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.amber, size: 36),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                  ),
                                  onPressed: _loadThread,
                                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isAdmin = msg['sender_role'] == 'admin';
                                final text = msg['message'] ?? '';
                                final timeStr = msg['created_at'] != null
                                    ? DateTime.tryParse(msg['created_at'].toString())
                                            ?.toLocal()
                                            .toString()
                                            .substring(11, 16) ??
                                        ''
                                    : '';

                                return Align(
                                  alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? const Color(0xFF1E293B) : const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isAdmin ? 2 : 16),
                                        bottomRight: Radius.circular(isAdmin ? 16 : 2),
                                      ),
                                      border: Border.all(
                                        color: isAdmin
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                      children: [
                                        if (isAdmin)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: const [
                                                Icon(Icons.shield, size: 12, color: Color(0xFF60A5FA)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Aura Admin',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF93C5FD),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        Text(
                                          text,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.white.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // Bottom Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Ask admin support...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF60A5FA), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Direct Creator Support',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Questions regarding your video review, bucket quota milestone payout, or account approval?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _chipPrompt('When will my uploaded video be approved?'),
                _chipPrompt('Monetization payout inquiry'),
                _chipPrompt('KYC verification status'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipPrompt(String text) {
    return ActionChip(
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      label: Text(text, style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11)),
      onPressed: () => _sendMessage(text),
    );
  }
}

