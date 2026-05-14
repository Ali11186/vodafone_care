import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/vodafone_service.dart';
import '../main.dart';
import 'chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() { _anim.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_phoneCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ادخل الرقم والباسورد')));
      return;
    }
    setState(() => _loading = true);
    try {
      final s = await VodafoneService().login(_phoneCtrl.text.trim(), _passCtrl.text.trim());
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChatScreen(session: s)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final app = MyApp.of(context);
    return Scaffold(
      body: Stack(children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.42,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFCC0000), Color(0xFFE60000), Color(0xFFFF5555)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://t.me/ahrgq'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.send, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('قناتنا', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              IconButton(
                icon: Icon(dark ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: Colors.white),
                onPressed: () => app?.toggleTheme(),
              ),
            ]),
          ),
          FadeTransition(opacity: _fade, child: Column(children: [
            Container(
              width: 85, height: 85,
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: const Center(child: Text('V', style: TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Color(0xFFE60000)))),
            ),
            const SizedBox(height: 14),
            const Text('Vodafone Care', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 4),
            Text('خدمة العملاء على أصابعك', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          ])),
          const SizedBox(height: 28),
          Expanded(child: SlideTransition(position: _slide, child: FadeTransition(opacity: _fade,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.13), blurRadius: 32, offset: const Offset(0, 12))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('تسجيل الدخول', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark ? Colors.white : const Color(0xFF1A1A1A))),
                const SizedBox(height: 22),
                _field(_phoneCtrl, 'رقم الموبايل', Icons.phone_android_rounded, dark, keyboard: TextInputType.phone),
                const SizedBox(height: 14),
                _field(_passCtrl, 'باسورد أنا فودافون', Icons.lock_rounded, dark, obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: Colors.grey[400], size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )),
                const SizedBox(height: 24),
                SizedBox(height: 52, child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE60000), foregroundColor: Colors.white,
                    elevation: 6, shadowColor: const Color(0xFFE60000).withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('دخول', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                )),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse('https://t.me/ahrgq'), mode: LaunchMode.externalApplication),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.send, color: Color(0xFF0088cc), size: 16),
                    const SizedBox(width: 6),
                    Text('انضم لقناتنا على تيليجرام',
                      style: TextStyle(color: const Color(0xFF0088cc), fontSize: 13, decoration: TextDecoration.underline, decorationColor: const Color(0xFF0088cc))),
                  ]),
                ),
              ]),
            ),
          ))),
          const SizedBox(height: 20),
        ])),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, bool dark,
      {TextInputType keyboard = TextInputType.text, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c, obscureText: obscure, keyboardType: keyboard, textDirection: TextDirection.ltr,
      style: TextStyle(color: dark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: const Color(0xFFE60000), size: 21),
        suffixIcon: suffix,
        filled: true, fillColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFF7F7F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE60000), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
