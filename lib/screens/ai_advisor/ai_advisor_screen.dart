import 'package:catat_uang_app/core/app_notification.dart';
import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/services/ai_context_service.dart';
import 'package:catat_uang_app/services/gemini_service.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:catat_uang_app/widgets/app_list_row.dart';
import 'package:catat_uang_app/widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiSessionManager {
  static final AiSessionManager _instance = AiSessionManager._internal();
  factory AiSessionManager() => _instance;
  AiSessionManager._internal();

  List<Map<String, dynamic>> messages = [];
  DateTime? lastActive;

  void clearSession() {
    messages.clear();
    lastActive = null;
  }
}

class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SupabaseClient get _supabase => Supabase.instance.client;

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String _financialContext = ""; 
  
  final _session = AiSessionManager(); 

  @override
  void initState() {
    super.initState();
    _fetchFinancialContext();
    _loadChatSession();
  }

  void _loadChatSession() {
    final now = DateTime.now();
    if (_session.lastActive != null && now.difference(_session.lastActive!).inMinutes < 10) {
      _messages.addAll(_session.messages);
    } else {
      _session.clearSession();
      final greeting = {
        'isUser': false,
        'text': "Halo bos! 👋 Aku Gemi. Aku udah dapet akses VIP ke seluruh brankas tabungan dan riwayat keuanganmu nih! Mau bahas target nabung atau cek pengeluaran hari ini?"
      };
      _messages.add(greeting);
      _session.messages.add(greeting);
      _session.lastActive = now;
    }
  }

  
 // [UPDATE BIKIN GEMI MAKIN PINTER] Rincian Tabungan & Dompet Dibongkar Habis!
  Future<void> _fetchFinancialContext() async {
    try {
      _financialContext = await buildFinancialContext(_supabase);
      debugPrint("Kertas Contekan Multi-Bulan, Tabungan, & Dompet:\n$_financialContext");
    } catch (e) {
      _financialContext = "Data keuangan belum tersedia atau gagal dimuat.";
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _isLoading = true;
    });
    
    _session.messages = List.from(_messages);
    _session.lastActive = DateTime.now();

    _chatController.clear();
    _scrollToBottom();

    final response = await GeminiService.askFinancialAdvisor(text, _financialContext);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response != null) {
        _messages.add({'isUser': false, 'text': response});
        
        _session.messages = List.from(_messages);
        _session.lastActive = DateTime.now();
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetSession() {
    setState(() {
      _session.clearSession();
      _messages.clear();
      _loadChatSession();
    });
    AppNotification.success(context, "Sesi chat diulang!");
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'AI Advisor',
      backLabel: '',
      largeTitle: false,
      navTitleWidget: const _GemiTitle(),
      scrollController: _scrollController,
      actions: [
        AppNavAction.icon(
          PhosphorIconsRegular.broom,
          onPressed: _resetSession,
          tooltip: "Mulai Chat Baru",
        ),
      ],
      bottomBar: _buildComposer(),
      children: [
        for (final msg in _messages)
          _ChatBubble(text: msg['text'] as String, isUser: msg['isUser'] as bool),
        if (_isLoading) const _TypingBubble(),
      ],
    );
  }

  Widget _buildComposer() {
    return Row(
      children: [
        Expanded(
          // Composer chat khusus layar ini (pill, tombol kirim terpisah) —
          // AppTextField berbentuk kotak radius 16 dan tidak cocok untuk input chat.
          child: TextField(
            controller: _chatController,
            style: AppTextStyles.body.copyWith(fontSize: 15),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: "Tanya soal keuanganmu...",
              hintStyle: AppTextStyles.body.copyWith(fontSize: 15, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Kirim',
          child: GestureDetector(
            onTap: _isLoading ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.textSecondary : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(PhosphorIconsFill.paperPlaneRight, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

class _GemiTitle extends StatelessWidget {
  const _GemiTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIconTile(icon: PhosphorIconsFill.robot, color: AppColors.primary, round: true, size: 30),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("AI Advisor", style: AppTextStyles.bodyStrong.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis),
            Text(
              "Gemi - Siap bantu atur duitmu!",
              style: AppTextStyles.caption.copyWith(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
        ),
        child: isUser
            ? Text(text, style: AppTextStyles.body.copyWith(fontSize: 15, color: Colors.white))
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body.copyWith(fontSize: 15),
                  strong: AppTextStyles.body.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                  listBullet: AppTextStyles.body.copyWith(fontSize: 15),
                ),
              ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text("Gemi sedang menganalisa...", style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
