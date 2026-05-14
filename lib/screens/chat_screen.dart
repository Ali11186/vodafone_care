import 'package:flutter/material.dart';
import '../services/vodafone_service.dart';
import '../services/background_service.dart';
import '../main.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const ChatScreen({super.key, required this.session});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _svc = VodafoneService();
  final List<_Msg> _msgs = [];
  bool _connecting = true, _active = false, _inBg = false;
  Timer? _timer;
  int _pos = 0;
  String? _chatId;
  Map<String, String>? _h;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _inBg = s == AppLifecycleState.paused || s == AppLifecycleState.detached;
    if (_active) { _inBg ? startBackgroundService() : stopBackgroundService(); }
  }

  void _add(String t, _T type) {
    setState(() => _msgs.add(_Msg(t, type)));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _startChat() async {
    _add('جاري الاتصال بخدمة العملاء...', _T.sys);
    try {
      final r = await _svc.startChat(widget.session);
      _chatId = r['chatId']; _h = Map<String, String>.from(r['refreshHeaders']); _pos = r['lastPosition'];
      setState(() { _connecting = false; _active = true; });
      _add('✅ تم الاتصال! ابدأ المحادثة', _T.sys);
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    } catch (e) {
      _add('❌ فشل الاتصال: $e', _T.sys);
      setState(() => _connecting = false);
    }
  }

  Future<void> _refresh() async {
    if (!_active || _chatId == null) return;
    try {
      final r = await _svc.refreshChat(_chatId!, _pos, _h!);
      if (r['position'] != null) _pos = r['position'];
      for (final m in r['messages'] ?? []) {
        _add(m, _T.agent);
        if (_inBg) notifyBackground('👨‍💼 $m'); else await showNotification('👨‍💼 $m');
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final t = _msgCtrl.text.trim();
    if (t.isEmpty || !_active) return;
    _msgCtrl.clear(); _add(t, _T.user);
    try { await _svc.sendMessage(_chatId!, t, _h!); } catch (_) {}
  }

  Future<void> _end() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إنهاء المحادثة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد أنك تريد إنهاء المحادثة؟', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لا', style: TextStyle(color: Colors.grey, fontSize: 16))),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE60000), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _timer?.cancel(); stopBackgroundService();
    if (_chatId != null && _h != null) await _svc.disconnect(_chatId!, _h!);
    setState(() => _active = false);
    _add('👋 تم إنهاء المحادثة', _T.sys);
  }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _timer?.cancel(); _msgCtrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final app = MyApp.of(context);
    final name = '${widget.session['first_name']} ${widget.session['last_name']}';
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFCC0000), Color(0xFFE60000), Color(0xFFFF5555)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        )),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('خدمة العملاء', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(name, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Icon(dark ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: Colors.white),
            onPressed: () => app?.toggleTheme(),
          ),
          if (_active)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _end,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [
        if (_connecting) const LinearProgressIndicator(color: Color(0xFFE60000), backgroundColor: Colors.transparent),
        Expanded(
          child: _msgs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('جاري الاتصال...', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
              ]))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: _msgs.length,
                itemBuilder: (_, i) => _bubble(_msgs[i], dark),
              ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1A1A1A) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: TextField(
                  controller: _msgCtrl, enabled: _active, textDirection: TextDirection.rtl, maxLines: null,
                  style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: _active ? 'اكتب رسالتك...' : 'المحادثة منتهية',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _active ? _send : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: _active ? const LinearGradient(colors: [Color(0xFFCC0000), Color(0xFFFF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                  color: _active ? null : Colors.grey[300],
                  shape: BoxShape.circle,
                  boxShadow: _active ? [BoxShadow(color: const Color(0xFFE60000).withOpacity(0.45), blurRadius: 10, offset: const Offset(0, 4))] : null,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m, bool dark) {
    if (m.type == _T.sys) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(0.07) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(m.text, style: TextStyle(color: dark ? Colors.grey[300] : Colors.grey[600], fontSize: 12)),
        )),
      );
    }
    final isUser = m.type == _T.user;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 15, backgroundColor: const Color(0xFFE60000).withOpacity(0.1),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFE60000), size: 17)),
            const SizedBox(width: 7),
          ],
          Flexible(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              gradient: isUser ? const LinearGradient(colors: [Color(0xFFCC0000), Color(0xFFFF4444)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
              color: isUser ? null : dark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Text(m.text, style: TextStyle(color: isUser ? Colors.white : dark ? Colors.white : Colors.black87, fontSize: 15, height: 1.4)),
          )),
          if (isUser) const SizedBox(width: 7),
        ],
      ),
    );
  }
}

enum _T { user, agent, sys }
class _Msg { final String text; final _T type; _Msg(this.text, this.type); }
