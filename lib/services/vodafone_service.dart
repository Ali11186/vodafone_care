import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class VodafoneService {
  static const _authUrl = 'https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token';
  static const _chatBase = 'https://chat.vodafone.com.eg/genesys/1/service';

  String _randomHex(int len) {
    final r = Random();
    return List.generate(len, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Map<String, String> _deviceHeaders({String? msisdn}) {
    final devices = ['Realme RMX3760', 'Xiaomi M2102J20SG', 'Samsung SM-G998B', 'HUAWEI LIO-L29'];
    final headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      'Connection': 'keep-alive',
      'silentLogin': 'true',
      'clientId': 'AnaVodafoneAndroid',
      'Accept-Language': 'ar',
      'x-agent-version': '2026.4.1',
      'x-agent-device': devices[Random().nextInt(devices.length)],
      'x-agent-build': '${1100 + Random().nextInt(100)}',
      'device-id': _randomHex(16),
      'Content-Type': 'application/x-www-form-urlencoded',
      'Host': 'mobile.vodafone.com.eg',
      'User-Agent': 'okhttp/4.12.0',
    };
    if (msisdn != null) headers['msisdn'] = msisdn;
    return headers;
  }

  Future<Map<String, dynamic>> login(String phone, String password) async {
    final res = await http.post(
      Uri.parse(_authUrl),
      headers: _deviceHeaders(msisdn: phone),
      body: {
        'username': phone, 'password': password,
        'grant_type': 'password',
        'client_secret': 'dca0pbLUWXVhXR266Gw1iT5rqwvvJQoN',
        'client_id': 'AnaVF',
      },
    );
    if (res.statusCode != 200) throw Exception('فشل تسجيل الدخول - تأكد من الرقم والباسورد');
    final token = json.decode(res.body)['access_token'] as String;
    final parts = token.split('.');
    final payload = json.decode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final userInfo = payload['userInfo'] ?? {};
    return {
      'token': token, 'phone': phone,
      'first_name': userInfo['firstName'] ?? 'مستخدم',
      'last_name': userInfo['lastName'] ?? '',
      'tariff': userInfo['tariffModelName'] ?? 'غير محدد',
    };
  }

  Future<Map<String, dynamic>> startChat(Map<String, dynamic> session) async {
    final h = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Xiaomi Build/SKQ1.210216.001) AppleWebKit/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Origin': 'https://web.vodafone.com.eg',
      'Referer': 'https://web.vodafone.com.eg/',
      'Accept-Language': 'ar,ar-EG;q=0.9',
      'X-Requested-With': 'com.emeint.android.myservices',
    };
    final initRes = await http.get(Uri.parse('$_chatBase/Chat2'), headers: h);
    final chatId = json.decode(initRes.body)['_id'];
    final h2 = {...h, 'Content-Type': 'application/json'};
    await http.post(Uri.parse('$_chatBase/$chatId/ixn/chat'), headers: h2,
      body: json.encode({
        'subject': 'ES_1_mobile_es',
        'FirstName': session['first_name'], 'LastName': session['last_name'],
        'EmailAddress': '', 'LoggedIn': 'True', 'message': 'hi',
        'TopicSelected': 'Chat_Contactus_ar', 'MSISDN': session['phone'],
        '_verbose': 'True', 'Language': 'ar', 'RatePlan': session['tariff'],
        'Channel_name': 'app', 'Transfer_test': 'No', 'Source': 'FlexBot',
      }),
    );
    int pos = 0; bool joined = false; int tries = 0;
    while (!joined && tries < 30) {
      await Future.delayed(const Duration(seconds: 2)); tries++;
      final r = await http.post(Uri.parse('$_chatBase/$chatId/ixn/chat/refresh?transcriptPosition=$pos'), headers: h2, body: json.encode({}));
      final d = json.decode(r.body);
      if (d['transcriptPosition'] != null) pos = d['transcriptPosition'];
      for (final m in d['transcriptToShow'] ?? []) {
        if (m[0] == 'Notice.Joined') { joined = true; break; }
      }
    }
    return {'chatId': chatId, 'lastPosition': pos, 'refreshHeaders': h2};
  }

  Future<Map<String, dynamic>> refreshChat(String chatId, int pos, Map<String, String> h) async {
    final r = await http.post(Uri.parse('$_chatBase/$chatId/ixn/chat/refresh?transcriptPosition=$pos'), headers: h, body: json.encode({}));
    final d = json.decode(r.body);
    final msgs = <String>[];
    for (final m in d['transcriptToShow'] ?? []) {
      if (m.length >= 5 && m[0] == 'Message.Text' && m[4] == 'AGENT') msgs.add(m[2]);
    }
    return {'position': d['transcriptPosition'], 'messages': msgs};
  }

  Future<void> sendMessage(String chatId, String msg, Map<String, String> h) async {
    await http.post(Uri.parse('$_chatBase/$chatId/ixn/chat/send'), headers: h, body: json.encode({'message': msg}));
  }

  Future<void> disconnect(String chatId, Map<String, String> h) async {
    try { await http.post(Uri.parse('$_chatBase/$chatId/ixn/chat/disconnect'), headers: h, body: json.encode({'_verbose': 'True'})); } catch (_) {}
  }
}
