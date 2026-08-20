import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:live_core/live_core.dart';

/// 隐藏 WebView：驱动虎牙网页端真实发弹幕 + 抓取真实订阅数
/// 发送成功判定 = 网页输入框被网页客户端清空（真实发出的标志）
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
  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

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
      ..setUserAgent(_desktopUa)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) async {
        await Future.delayed(const Duration(seconds: 3));
        if (!HuyaWebSender.ready) {
          HuyaWebSender.ready = true;
          _scrapeFans();
        }
        await Future.delayed(const Duration(seconds: 5));
        _scrapeFans();
      }))
      ..loadRequest(Uri.parse('https://www.huya.com/${widget.roomId}'));

    HuyaWebSender.sendFn = _send;
    if (mounted) setState(() => _ctrl = ctrl);
  }

  /// 真实发送：填字→点击→验证输入框被清空；no-input 时自动重试
  Future<String> _send(String text) async {
    final ctrl = _ctrl;
    if (ctrl == null) return 'webview未就绪';
    try {
      String r = 'no-input';
      for (var i = 0; i < 3 && r == 'no-input'; i++) {
        if (i > 0) await Future.delayed(const Duration(seconds: 1));
        r = '${await ctrl.runJavaScriptReturningResult(_jsSend(text))}'
            .replaceAll('"', '');
      }
      if (!r.startsWith('clicked')) return r; // no-input 等如实返回
      // 1.2 秒后验证：输入框被网页清空 = 真实发送成功
      await Future.delayed(const Duration(milliseconds: 1200));
      final v = '${await ctrl.runJavaScriptReturningResult(_jsCheck)}'
          .replaceAll('"', '');
      return v == 'cleared' ? 'sent' : 'not-sent';
    } catch (e) {
      return 'err:$e';
    }
  }

  String _jsSend(String text) => '''
(function(){
  var t = ${jsonEncode(text)};
  var ds = [document];
  var ifs = document.querySelectorAll('iframe');
  for (var i=0;i<ifs.length;i++){ try{ if(ifs[i].contentDocument) ds.push(ifs[i].contentDocument); }catch(e){} }
  var ta = null, d0 = null;
  for (var j=0;j<ds.length;j++){
    var d = ds[j];
    ta = d.querySelector('#pub-textarea')
        || d.querySelector('textarea[maxlength]')
        || d.querySelector('textarea')
        || d.querySelector('.chat-editer[contenteditable="true"]')
        || d.querySelector('[contenteditable="true"]');
    if (ta){ d0 = d; break; }
  }
  if (!ta) return 'no-input';
  if (ta.tagName==='TEXTAREA' || ta.tagName==='INPUT'){
    var proto = ta.tagName==='TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    var set = Object.getOwnPropertyDescriptor(proto,'value').set;
    set.call(ta, t);
  } else { ta.innerText = t; }
  ta.dispatchEvent(new Event('input',{bubbles:true}));
  ta.dispatchEvent(new Event('change',{bubbles:true}));
  ta.dispatchEvent(new KeyboardEvent('keyup',{bubbles:true}));
  var btn = d0.querySelector('#pub-send')
         || d0.querySelector('.send-btn')
         || d0.querySelector('a[class*="send"]')
         || d0.querySelector('button[class*="send"]');
  if (!btn){
    var all = d0.querySelectorAll('a,button,span,div');
    for (var i=0;i<all.length;i++){
      var x = all[i];
      if ((x.innerText||'').trim()==='发送' && x.children.length===0){ btn = x; break; }
    }
  }
  if (btn){ btn.click(); return 'clicked'; }
  ta.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',keyCode:13,which:13,bubbles:true}));
  return 'clicked-enter';
})()
''';

  static const _jsCheck = '''
(function(){
  var ta = document.querySelector('#pub-textarea')
        || document.querySelector('textarea[maxlength]')
        || document.querySelector('textarea')
        || document.querySelector('[contenteditable="true"]');
  if (!ta) return 'cleared';
  var v = (ta.tagName==='TEXTAREA' || ta.tagName==='INPUT') ? ta.value : ta.innerText;
  return (v||'').trim()==='' ? 'cleared' : 'still-there';
})()
''';

  /// 抓真实订阅数
  Future<void> _scrapeFans() async {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    const js = '''
(function(){
  var nodes = document.querySelectorAll('*');
  for(var i=0;i<nodes.length;i++){
    var el = nodes[i];
    if(el.children.length) continue;
    var txt = (el.innerText||'').trim();
    if(txt !== '关注') continue;
    var p = el.parentElement;
    for(var k=0;k<3&&p;k++){
      var m = (p.innerText||'').match(/关注\\s*([\\d.]+\\s*万?)/);
      if(m) return m[1].replace(/\\s/g,'');
      p = p.parentElement;
    }
  }
  var m2 = document.documentElement.innerHTML.match(/关注(?:<[^>]*>|\\s){0,6}([\\d][\\d.]*万?)/);
  return m2 ? m2[1] : '';
})()
''';
    try {
      final result = '${await ctrl.runJavaScriptReturningResult(js)}'
          .replaceAll('"', '')
          .trim();
      final v = _parseWan(result);
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
    return SizedBox(width: 1, height: 1, child: WebViewWidget(controller: ctrl));
  }
}
