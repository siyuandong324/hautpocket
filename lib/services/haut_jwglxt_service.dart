// 河南工业大学正方教务系统 (jwglxt.haut.edu.cn) Dart 网络爬虫与定时同步服务
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';

class HautJwglxtService {
  final String baseUrl;
  Map<String, String> _cookies = {};
  Timer? _autoSyncTimer;

  HautJwglxtService({this.baseUrl = 'https://jwglxt.haut.edu.cn/jwglxt'});

  /// 配置定时自动更新（间隔分钟数可由用户自定义）
  void startAutoSync({
    required int intervalMinutes,
    required Future<void> Function() onSyncTick,
  }) {
    _autoSyncTimer?.cancel();
    if (intervalMinutes <= 0) return;
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => onSyncTick(),
    );
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// RSA PKCS#1 v1.5 加密正方教务系统密码
  String encryptPasswordRsa(String password, String modulusB64, String exponentB64) {
    final modBytes = base64.decode(modulusB64);
    final expBytes = base64.decode(exponentB64);
    BigInt bytesToBigInt(Uint8List bytes) {
      BigInt result = BigInt.zero;
      for (final b in bytes) {
        result = (result << 8) | BigInt.from(b);
      }
      return result;
    }

    final pubKey = RSAPublicKey(bytesToBigInt(modBytes), bytesToBigInt(expBytes));
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(pubKey));
    final inputBytes = Uint8List.fromList(utf8.encode(password));
    final encrypted = cipher.process(inputBytes);
    return base64.encode(encrypted);
  }

  void _updateCookies(http.Response response) {
    final rawSetCookie = response.headers['set-cookie'];
    if (rawSetCookie == null) return;
    for (final part in rawSetCookie.split(RegExp(r',(?=[^;]+=[^;]+)'))) {
      final kv = part.split(';').first.trim();
      final idx = kv.indexOf('=');
      if (idx > 0) {
        _cookies[kv.substring(0, idx).trim()] = kv.substring(idx + 1).trim();
      }
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  /// 登录正方教务系统（自动容错全角/半角感叹号）
  Future<bool> login(String username, String password) async {
    try {
      return await _attemptLogin(username, password);
    } catch (e) {
      if (password.contains('！')) {
        return await _attemptLogin(username, password.replaceAll('！', '!'));
      }
      rethrow;
    }
  }

  Future<bool> _attemptLogin(String username, String password) async {
    _cookies.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    final loginUri = Uri.parse('$baseUrl/xtgl/login_slogin.html?language=zh_CN&_t=$now');
    final pageResp = await http.get(loginUri);
    _updateCookies(pageResp);

    final doc = html_parser.parse(pageResp.body);
    final csrfToken = doc.getElementById('csrftoken')?.attributes['value'] ?? '';
    if (csrfToken.isEmpty) {
      throw Exception('未能从登录页获取 csrftoken');
    }

    final keyUri = Uri.parse('$baseUrl/xtgl/login_getPublicKey.html?time=$now');
    final keyResp = await http.get(keyUri, headers: {
      'Cookie': _cookieHeader,
      'X-Requested-With': 'XMLHttpRequest',
    });
    _updateCookies(keyResp);
    final keyJson = json.decode(keyResp.body) as Map<String, dynamic>;
    final encryptedPwd = encryptPasswordRsa(
      password,
      keyJson['modulus'] as String,
      keyJson['exponent'] as String,
    );

    final postResp = await http.post(
      Uri.parse('$baseUrl/xtgl/login_slogin.html?time=$now'),
      headers: {
        'Cookie': _cookieHeader,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Referer': loginUri.toString(),
      },
      body: 'csrftoken=${Uri.encodeComponent(csrfToken)}'
          '&language=zh_CN'
          '&yhm=${Uri.encodeComponent(username)}'
          '&mm=${Uri.encodeComponent(encryptedPwd)}'
          '&mm=${Uri.encodeComponent(encryptedPwd)}',
    );
    _updateCookies(postResp);

    if (postResp.body.contains('id="tips"')) {
      final errDoc = html_parser.parse(postResp.body);
      final msg = errDoc.getElementById('tips')?.text.trim() ?? '用户名或密码错误';
      throw Exception(msg);
    }
    return true;
  }

  /// 拉取个人课表查询 (gnmkdm=N2151)
  Future<Map<String, dynamic>> fetchSchedule({String year = '2026', String termCode = '3'}) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/kbcx/xskbcx_cxXsgrkb.html?gnmkdm=N2151'),
      headers: {
        'Cookie': _cookieHeader,
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
      },
      body: {'xnm': year, 'xqm': termCode, 'kzlx': 'ck', 'xsdm': ''},
    );
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  /// 拉取查询个人信息 - 成绩信息 (gnmkdm=N100801 / N305005)
  Future<List<dynamic>> fetchGrades({String year = '', String termCode = ''}) async {
    final endpoints = [
      '$baseUrl/xsxxxggl/xsxxwh_cxXscjxx.html?gnmkdm=N100801',
      '$baseUrl/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N305005',
      '$baseUrl/cjcx/cjcx_cxXsgrcj.html?doType=query&gnmkdm=N305005',
    ];
    for (final ep in endpoints) {
      final resp = await http.post(
        Uri.parse(ep),
        headers: {
          'Cookie': _cookieHeader,
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body: {
          'xnm': year,
          'xqm': termCode,
          '_search': 'false',
          'queryModel.showCount': '5000',
          'queryModel.currentPage': '1',
          'time': '1',
        },
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is Map && decoded['items'] is List) {
          return decoded['items'] as List<dynamic>;
        }
      }
    }
    return [];
  }

  /// 拉取查询个人信息 - 选课信息 (gnmkdm=N100801 / N255005)
  Future<List<dynamic>> fetchSelectedCourses({String year = '2026', String termCode = '3'}) async {
    final endpoints = [
      '$baseUrl/xsxxxggl/xsxxwh_cxXsxkxx.html?gnmkdm=N100801',
      '$baseUrl/xkcx/xkmdcx_cxXkmdcxIndex.html?doType=query&gnmkdm=N255005',
    ];
    for (final ep in endpoints) {
      final resp = await http.post(
        Uri.parse(ep),
        headers: {
          'Cookie': _cookieHeader,
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        },
        body: {
          'xnm': year,
          'xqm': termCode,
          '_search': 'false',
          'queryModel.showCount': '5000',
          'queryModel.currentPage': '1',
          'time': '1',
        },
      );
      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is Map && decoded['items'] is List) {
          return decoded['items'] as List<dynamic>;
        }
      }
    }
    return [];
  }
}
