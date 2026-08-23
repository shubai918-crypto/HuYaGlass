import 'package:flutter/material.dart';
import 'package:live_core/src/huya/huya_search.dart';

import 'search_controller.dart';

/// 搜索页（dtv 风格：封面+角标 / 标题+副标题 / 心形收藏）
class SearchPage extends StatefulWidget {
  /// 点击结果卡片进房
  final void Function(String roomId, String nickname, String avatarUrl)
      onOpenRoom;

  /// 收藏 / 取消收藏（心形按钮）
  final Future<void> Function(
      String roomId, bool follow, String nickname, String avatarUrl)? onToggleFollow;

  /// 查询是否已收藏
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
          _buildBar(),
          const SizedBox(height: 14),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ================= 顶部搜索栏 =================
  Widget _buildBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: Color(0xFF29C5F6), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _text,
              focusNode: _focus,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
              onChanged: _ctrl.setKeyword,
              decoration: const InputDecoration(
                hintText: '搜索虎牙主播/房间...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF29C5F6)),
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  // ================= 结果区域 =================
  Widget _buildBody() {
    if (_ctrl.loading) {
      return const Center(
        child: CircularProgressIndicator(
            color: Color(0xFF29C5F6), strokeWidth: 2.5),
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
          child: Text('未找到相关主播',
              style: TextStyle(color: Colors.white38)));
    }
    return ListView.separated(
      itemCount: _ctrl.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(_ctrl.items[i]),
    );
  }

  // ================= dtv 风格卡片 =================
  Widget _card(HuyaSearchItem it) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            widget.onOpenRoom(it.roomId, it.nickname, it.avatarUrl),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // 封面 + 直播状态角标
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: it.avatarUrl.isNotEmpty
                        ? Image.network(
                            it.avatarUrl,
                            width: 96,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _coverPlaceholder(),
                          )
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
                          color: it.isLive
                              ? const Color(0xFF29C5F6)
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // 标题 + 副标题
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
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 心形收藏
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

/// 右侧收藏心形按钮
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
      // 接了回调才可点；IconButton 吃掉点击，不会触发外层进房
      onPressed: widget.onToggle == null
          ? null
          : () async {
              await widget.onToggle!(widget.roomId, !followed,
                  widget.nickname, widget.avatarUrl);
              if (mounted) setState(() => _followed = !followed);
            },
    );
  }
}
