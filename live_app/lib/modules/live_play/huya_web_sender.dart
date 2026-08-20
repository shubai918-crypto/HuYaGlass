import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:live_core/live_core.dart';

/// 隐藏 WebView：驱动虎牙网页端真实发弹幕 + 抓取真实订阅数
class HuyaWebSender extends StatefulWidget {
  final String roomId;
  final void Function(int)? onFans;
  const HuyaWebSender({super.key, required this.roomId, this.onFans});

  static Future<String> Function(String)? sendFn;
  static bool ready = false;

  @override
  State<HuyaWebSender> createState() => _HuyaWebSenderState();
}

class _HuyaWebSenderState extends State<HuyaWebSender> {
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cm = WebViewCookieManager();
    await cm.clearCookies();
    final cookie = HuyaLoginManager().cookie;
    if (cookie.isNotEmpty) {
      for (final pair in cookie.split(';')) {
        final idx = pair.indexOf('=');
        if (idx <= 0) continue;
        final name = pair.substring(0, idx).trim();
        final value = pair.substring(idx + 1).trim();
        if (name.isEmpty || value.isEmpty) continue;
        await cm.setCookie(WebViewCookie(
          name: name,
          value: value,
          domain: '.huya.com',
          path: '/',
        ));
      }
    }

    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) async {
        await Future.delayed(const Duration(seconds: 3));
        if (!HuyaWebSender.ready) {
          HuyaWebSender.ready = true;
          _scrapeFans();
        }
      }))
      ..loadRequest(Uri.parse('https://www.huya.com/${widget.roomId}'));

    HuyaWebSender.sendFn = _send;
    if (mounted) setState(() => _ctrl = ctrl);
  }

  /// 注入 JS：填字 + 点发送（多选择器兜底）
  Future<String> _send(String text) async {
    final ctrl = _ctrl;
    if (ctrl == null) return 'webview未就绪';
    final js = '''
(function(){
  var t = ${jsonEncode(text)};
  var ta = document.querySelector('#pub-textarea')
        || document.querySelector('.chat-input textarea')
        || document.querySelector('textarea');
  var ed = document.querySelector('.chat-editer[contenteditable="true"]')
        || document.querySelector('[contenteditable="true"]');
  function fire(el){
    el.dispatchEvent(new Event('input',{bubbles:true}));
    el.dispatchEvent(new Event('change',{bubbles:true}));
    el.dispatchEvent(new KeyboardEvent('keyup',{bubbles:true}));
  }
  if (ta) {
    var set = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value').set;
    set.call(ta, t); fire(ta);
  } else if (ed) {
    ed.innerText = t; fire(ed);
  } else { return 'no-input'; }
  var btn = document.querySelector('#pub-send')
         || document.querySelector('.send-btn')
         || document.querySelector('button[class*="send"]')
         || document.querySelector('.chat-input .send');
  if (btn) { btn.click(); return 'sent'; }
  return 'no-btn';
})()
''';
    try {
      final r = await ctrl.runJavaScriptReturningResult(js);
      return '$r'.replaceAll('"', '');
    } catch (e) {
      return 'err:$e';
    }
  }

  /// 抓网页上真实订阅数（如 78.1万）
  Future<void> _scrapeFans() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    const js = '''
(function(){
  var sels = ['.host-control-subscribe-num','.subscribe-num','.fans-num',
              '.host-control-subscribe i','.host-control-subscribe span',
              '[class*="subscribe"] i','[class*="fans"] i'];
  for (var i=0;i<sels.length;i++){
    var el = document.querySelector(sels[i]);
    if (el && (el.innerText||'').trim()) return (el.innerText||'').trim();
  }
  return '';
})()
''';
    try {
      // 修复：先转为 String 再调用 replaceAll
      final result = await ctrl.runJavaScriptReturningResult(js);
      final r = '$result'.replaceAll('"', '');
      final v = _parseWan(r);
      if (v > 0) widget.onFans?.call(v);
    } catch (_) {}
  }

  int _parseWan(String s) {
    if (s.isEmpty) return 0;
    final m = RegExp(r'([\d.]+)\s*万').firstMatch(s);
    if (m != null) return ((double.tryParse(m.group(1)!) ?? 0) * 10000).round();
    return int.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) return const SizedBox.shrink();
    // 1x1 隐藏渲染（WebView 必须在树里才工作）
    return SizedBox(width: 1, height: 1, child: WebViewWidget(controller: ctrl));
  }
}
