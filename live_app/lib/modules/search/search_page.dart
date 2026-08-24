import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:live_core/src/huya/huya_search.dart';

import 'search_controller.dart';

const Color kHuyaAccent = Color(0xFFFF8800);

/// 搜索页（Apple Messages 同款玻璃搜索条 + dtv 风格卡片）
class SearchPage extends StatefulWidget {
  final void Function(String roomId, String nickname, String avatarUrl) onOpenRoom;
  final Future<void> Function(
      String roomId, bool follow, String nickname, String avatarUrl)? onToggleFollow;
  final Future<bool> Function(String roomId)? isFollowed;

  const SearchPage({
    super.key,
    required this.onOpenRoom,
    this.onToggleFollow,
    this.isFollowed,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final HuyaSearchController _ctrl = HuyaSearchController();
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onCtrl);
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onCtrl);
    _ctrl.dispose();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    _ctrl.submit();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // ★ 1. Messages 同款：单个玻璃胶囊，放大镜在内，Cancel 滑入，无外部圆钮
          GlassSearchBar(
            controller: _text,
            focusNode: _focus,
            placeholder: '搜索虎牙主播/房间...',
            onChanged: _ctrl.setKeyword,
            onSubmitted: (_) => _submit(),
            showsCancelButton: true,
            onCancel: () {
              _text.clear();
              _ctrl.setKeyword('');
              _focus.unfocus();
            },
            searchIconColor: kHuyaAccent,
            clearIconColor: Colors.white54,
            cancelButtonColor: kHuyaAccent,
            textStyle: const TextStyle(color: Colors.white, fontSize: 15),
            placeholderStyle: const TextStyle(color: Colors.white38, fontSize: 15),
            height: 50,
            useOwnLayer: true,
            settings: LiquidGlassSettings(blur: 8, thickness: 30),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_ctrl.loading) {
      return const Center(
        child: CircularProgressIndicator(color: kHuyaAccent, strokeWidth: 2.5),
      );
    }
    final err = _ctrl.error;
    if (err != null) {
      return Center(
          child: Text(err, style: const TextStyle(color: Colors.white38)));
    }
    if (!_ctrl.searched) {
      return const Center(
          child: Text('搜索主播，或直接输入房间号进入',
              style: TextStyle(color: Colors.white24)));
    }
    if (_ctrl.items.isEmpty) {
      return const Center(
          child: Text('未找到相关主播', style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      itemCount: _ctrl.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(_ctrl.items[i]),
    );
  }

  Widget _card(HuyaSearchItem it) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onOpenRoom(it.roomId, it.nickname, it.avatarUrl),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF16161E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: it.avatarUrl.isNotEmpty
                        ? Image.network(it.avatarUrl,
                            width: 96, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder())
                        : _coverPlaceholder(),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        it.isLive ? '直播中' : '未开播',
                        style: TextStyle(
                          fontSize: 10,
                          // ★ 3. 直播中用虎牙橙
                          color: it.isLive ? kHuyaAccent : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      it.title.isNotEmpty ? it.title : it.nickname,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      it.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HeartButton(
                roomId: it.roomId,
                nickname: it.nickname,
                avatarUrl: it.avatarUrl,
                onToggle: widget.onToggleFollow,
                isFollowed: widget.isFollowed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 96,
        height: 72,
        color: Colors.white10,
        alignment: Alignment.center,
        child: const Icon(Icons.live_tv, color: Colors.white30),
      );
}

class _HeartButton extends StatefulWidget {
  final String roomId;
  final String nickname;
  final String avatarUrl;
  final Future<void> Function(
      String roomId, bool follow, String nickname, String avatarUrl)? onToggle;
  final Future<bool> Function(String roomId)? isFollowed;

  const _HeartButton({
    required this.roomId,
    required this.nickname,
    required this.avatarUrl,
    this.onToggle,
    this.isFollowed,
  });

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton> {
  bool? _followed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.isFollowed == null) return;
    final v = await widget.isFollowed!(widget.roomId);
    if (mounted) setState(() => _followed = v);
  }

  @override
  Widget build(BuildContext context) {
    final followed = _followed ?? false;
    return IconButton(
      icon: Icon(
        followed ? Icons.favorite : Icons.favorite_border,
        color: followed ? const Color(0xFFE5484D) : Colors.white38,
      ),
      onPressed: widget.onToggle == null
          ? null
          : () async {
              await widget.onToggle!(
                  widget.roomId, !followed, widget.nickname, widget.avatarUrl);
              if (mounted) setState(() => _followed = !followed);
            },
    );
  }
}
