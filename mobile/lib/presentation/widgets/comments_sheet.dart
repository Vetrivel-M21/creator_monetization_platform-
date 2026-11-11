import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/video_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import 'auth_required_dialog.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;

  const CommentsSheet({super.key, required this.videoId});

  static void show(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(videoId: videoId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _api = ApiService();
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await _api.fetchComments(widget.videoId);
    if (mounted) {
      setState(() {
        _comments = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isPosting) return;

    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'leave a comment',
      );
      if (!loggedIn || !mounted) return;
    }

    setState(() => _isPosting = true);

    final currentUser = auth.currentUser;
    final userName = currentUser?.displayName ?? 'Community Member';
    final userId = currentUser?.id ?? 'guest';

    // Optimistic local add
    final now = DateTime.now();
    final optimisticComment = CommentModel(
      id: 'cmt-${now.millisecondsSinceEpoch}',
      videoId: widget.videoId,
      author: userName,
      avatar: currentUser?.displayAvatar ?? 'https://api.dicebear.com/7.x/bottts/svg?seed=$userId',
      text: text,
      likes: 0,
      createdAt: now,
      timeFormatted: 'Just now',
    );

    setState(() {
      _comments.insert(0, optimisticComment);
    });
    _controller.clear();
    if (mounted) {
      FocusScope.of(context).unfocus();
    }

    final posted = await _api.postComment(
      widget.videoId,
      content: text,
      userName: userName,
      userId: userId,
      token: auth.token,
    );

    if (mounted) {
      setState(() {
        _isPosting = false;
        if (posted != null) {
          _comments[0] = posted;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final auth = AuthService.instance;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBadge,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_comments.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondaryBadgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Scrollable Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textSecondary),
                            SizedBox(height: 10),
                            Text(
                              'No comments yet. Start the conversation!',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        itemCount: _comments.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (ctx, i) {
                          final c = _comments[i];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: AppColors.secondaryBadge,
                                backgroundImage: NetworkImage(c.avatar),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          c.author,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${c.timeFormatted}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      c.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.thumb_up_alt_outlined, size: 13, color: AppColors.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          c.likes > 0 ? '${c.likes}' : 'Like',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          const Divider(height: 1),

          // 3. Bottom Comment Input Bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomInset + 12),
            color: AppColors.surface,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondaryBadge,
                  backgroundImage: auth.currentUser != null
                      ? NetworkImage(auth.currentUser!.displayAvatar)
                      : null,
                  child: auth.currentUser == null
                      ? const Icon(Icons.person_outline, size: 18, color: AppColors.textSecondary)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.surfaceBorder, width: 1),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: auth.isGuest ? 'Sign in to add a comment...' : 'Add a comment...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                  onPressed: _isPosting ? null : _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
