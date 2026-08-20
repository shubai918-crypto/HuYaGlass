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
      ..setUserAgent(_desktopUa) // 关键：桌面 UA，拿到 PC 版页面（含聊天框）
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) async {
        await Future.delayed(const Duration(seconds: 3));
        if (!HuyaWebSender.ready) {
          HuyaWebSender.ready = true;
          _scrapeFans();
        }
        // 8 秒后再补抓一次（聊天框/关注数可能异步渲染）
        await Future.delayed(const Duration(seconds: 5));
        _scrapeFans();
      }))
      ..loadRequest(Uri.parse('https://www.huya.com/${widget.roomId}'));

    HuyaWebSender.sendFn = _send;
    if (mounted) setState(() => _ctrl = ctrl);
  }

  /// 注入 JS：主文档 + 同域 iframe 全搜索，填字 + 点「发送」
  Future<String> _send(String text) async {
    final ctrl = _ctrl;
    if (ctrl == null) return 'webview未就绪';
    final js = '''
(function(){
  var t = ${jsonEncode(text)};
  function findInput(d){
    if(!d) return null;
    return d.querySelector('#pub-textarea')
        || d.querySelector('textarea')
        || d.querySelector('.chat-editer[contenteditable]')
        || d.querySelector('[contenteditable="true"]')
        || d.querySelector('input[type="text"][maxlength]');
  }
  function findSend(d){
    if(!d) return null;
    var b = d.querySelector('#pub-send') || d.querySelector('.send-btn')
         || d.querySelector('a[class*="send"]') || d.querySelector('button[class*="send"]');
    if(b) return b;
    var all = d.querySelectorAll('a,button,span,div');
    for(var i=0;i<all.length;i++){
      var x = all[i];
      if((x.innerText||'').trim()==='发送' && x.children.length===0) return x;
    }
    return null;
  }
  var docs = [document];
  var ifs = document.querySelectorAll('iframe');
  for(var i=0;i<ifs.length;i++){
    try { if(ifs[i].contentDocument) docs.push(ifs[i].contentDocument); } catch(e){}
  }
  for(var j=0;j<docs.length;j++){
    var d = docs[j];
    var ta = findInput(d);
    if(!ta) continue;
    if(ta.tagName==='TEXTAREA' || ta.tagName==='INPUT'){
      var proto = ta.tagName==='TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      var set = Object.getOwnPropertyDescriptor(proto,'value').set;
      set.call(ta, t);
    } else {
      ta.innerText = t;
    }
    ta.dispatchEvent(new Event('input',{bubbles:true}));
    ta.dispatchEvent(new Event('change',{bubbles:true}));
    try{ ta.focus(); }catch(e){}
    var btn = findSend(d);
    if(btn){ btn.click(); return 'sent'; }
    ta.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',keyCode:13,which:13,bubbles:true}));
    ta.dispatchEvent(new KeyboardEvent('keyup',{key:'Enter',keyCode:13,which:13,bubbles:true}));
    return 'sent-enter';
  }
  return 'no-input';
})()
''';
    try {
      final result = await ctrl.runJavaScriptReturningResult(js);
      return '$result'.replaceAll('"', '');
    } catch (e) {
      return 'err:$e';
    }
  }

  /// 抓真实订阅数：找「关注」叶子节点，向上取父级文本里的数字
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
      final result = await ctrl.runJavaScriptReturningResult(js);
      final r = '$result'.replaceAll('"', '').trim();
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
    return SizedBox(width: 1, height: 1, child: WebViewWidget(controller: ctrl));
  }
}
