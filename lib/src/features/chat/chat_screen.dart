import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/app_preferences.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String _currentUserEmail = '';
  String _currentUserName = '';
  bool _isStaff = false;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await AppPreferences.instance.prefs;
    final isStaffLoggedIn = prefs.getBool('is_staff_logged_in') ?? false;

    if (isStaffLoggedIn) {
      final staffEmail = prefs.getString('logged_in_staff_email') ?? 'staff@gct.com';
      setState(() {
        _isStaff = true;
        _currentUserEmail = staffEmail;
        _currentUserName = 'Staff (${staffEmail.split('@').first})';
        _isLoadingUser = false;
      });
    } else {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _isStaff = false;
        _currentUserEmail = user?.email ?? 'doctor@gct.com';
        _currentUserName = 'Doctor';
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc('group_chat')
          .collection('messages')
          .add({
        'senderEmail': _currentUserEmail,
        'senderName': _currentUserName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isStaff': _isStaff,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteMessage(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc('group_chat')
          .collection('messages')
          .doc(docId)
          .delete();
      _showSnackBar('Message deleted successfully.');
    } catch (e) {
      _showSnackBar('Failed to delete message: $e', isError: true);
    }
  }

  Future<void> _clearAllChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear All Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete all messages in this group chat? This action cannot be undone.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear All', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc('group_chat')
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _showSnackBar('All chat history cleared.');
    } catch (e) {
      _showSnackBar('Failed to clear chat: $e', isError: true);
    }
  }

  Future<void> _clearSpecificStaffChat() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc('group_chat')
          .collection('messages')
          .where('isStaff', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        _showSnackBar('No staff messages found to clear.');
        return;
      }

      final staffMap = <String, String>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final email = data['senderEmail'] as String?;
        final name = data['senderName'] as String?;
        if (email != null && name != null) {
          staffMap[email] = name;
        }
      }

      if (!mounted) return;

      final selectedEmail = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Clear Specific Staff Chat', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: staffMap.entries.map((entry) {
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(entry.value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(entry.key, style: GoogleFonts.poppins(fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, entry.key),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.poppins())),
          ],
        ),
      );

      if (selectedEmail == null) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Confirm Deletion', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete all messages sent by $selectedEmail?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins())),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete All', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final deleteSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc('group_chat')
          .collection('messages')
          .where('senderEmail', isEqualTo: selectedEmail)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in deleteSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      _showSnackBar('Cleared messages from $selectedEmail.');
    } catch (e) {
      _showSnackBar('Failed to clear staff messages: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinic Group Chat',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text(
                  'Logged in as $_currentUserName',
                  style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!_isStaff)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'clear_all') {
                  _clearAllChat();
                } else if (val == 'clear_staff') {
                  _clearSpecificStaffChat();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text('Clear All Chat', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_staff',
                  child: Row(
                    children: [
                      const Icon(Icons.person_remove_rounded, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text('Clear Staff Chat', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This is a private group chat for Gonstead Clinic doctor and staff.',
                    style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc('group_chat')
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading chat: ${snapshot.error}',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Send a message to start the conversation!',
                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final senderEmail = data['senderEmail'] ?? '';
                    final senderName = data['senderName'] ?? '';
                    final text = data['text'] ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final isMsgStaff = data['isStaff'] ?? false;

                    final isMe = senderEmail == _currentUserEmail;
                    final canDelete = isMe || (!_isStaff && isMsgStaff);

                    // Formatted time
                    String timeStr = '';
                    if (timestamp != null) {
                      timeStr = DateFormat('hh:mm a').format(timestamp.toDate().toLocal());
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GestureDetector(
                        onLongPress: canDelete
                            ? () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete Message', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                    content: Text('Are you sure you want to delete this message?', style: GoogleFonts.poppins()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: GoogleFonts.poppins())),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _deleteMessage(docId);
                                }
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: isMsgStaff
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.statusPending.withOpacity(0.1),
                                child: Icon(
                                  isMsgStaff ? Icons.badge_outlined : Icons.local_hospital_outlined,
                                  size: 16,
                                  color: isMsgStaff ? AppColors.primary : AppColors.statusPending,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    Text(
                                      senderName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: isMe
                                          ? LinearGradient(
                                              colors: isDark
                                                  ? [AppColors.primary, AppColors.accent]
                                                  : [AppColors.primary, AppColors.primaryDark],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            )
                                          : null,
                                      color: isMe
                                          ? null
                                          : (isDark ? const Color(0xFF1E293B) : Colors.grey[200]),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          text,
                                          style: GoogleFonts.poppins(
                                            color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.poppins(
                                              color: isMe ? Colors.white60 : Colors.grey[500],
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _isStaff
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.statusPending.withOpacity(0.1),
                                child: Icon(
                                  _isStaff ? Icons.badge_outlined : Icons.local_hospital_outlined,
                                  size: 16,
                                  color: _isStaff ? AppColors.primary : AppColors.statusPending,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(fontSize: 14),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
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
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
