import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTabsEditorScreen extends StatefulWidget {
  final VoidCallback onSaved;

  const AdminTabsEditorScreen({super.key, required this.onSaved});

  @override
  State<AdminTabsEditorScreen> createState() => _AdminTabsEditorScreenState();
}

class _AdminTabsEditorScreenState extends State<AdminTabsEditorScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tabs = [];
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchTabs();
  }

  Future<void> _fetchTabs() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.from('app_tabs').select().order('order_index');
      setState(() {
        _tabs = List<Map<String, dynamic>>.from(res);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCurrentTab() async {
    if (_tabs.isEmpty) return;
    final current = _tabs[_selectedTabIndex];

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('app_tabs').upsert({
        'id': current['id'],
        'label': current['label'],
        'icon_name': current['icon_name'],
        'is_visible': current['is_visible'],
        'blocks': current['blocks'],
        'updated_at': DateTime.now().toIso8601String(),
      });

      HapticFeedback.heavyImpact();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF58CC02),
          content: Text('Вкладка и блоки успешно сохранены в базе! ✓',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

      widget.onSaved();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text('Ошибка сохранения: $e')),
      );
    }
  }

  void _addBlockDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161926),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ВЫБЕРИТЕ ТИП БЛОКА',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            const SizedBox(height: 14),
            ListTile(
              leading:
                  const Icon(Icons.view_carousel, color: Color(0xFFCCFF00)),
              title: const Text('Яркий Баннер (FC Mobile)'),
              subtitle: const Text('Заголовок, описание и метка'),
              onTap: () {
                Navigator.pop(ctx);
                _promptAddBanner();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Color(0xFFFFB300)),
              title: const Text('Объявление от тренера'),
              subtitle:
                  const Text('Текстовая инструкция или установка на игру'),
              onTap: () {
                Navigator.pop(ctx);
                _promptAddNotice();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF)),
              title: const Text('Видеоурок'),
              subtitle: const Text('Ссылка на YouTube разбор техники'),
              onTap: () {
                Navigator.pop(ctx);
                _promptAddVideo();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _promptAddBanner() {
    final titleCtrl = TextEditingController(text: 'НОВАЯ ТРЕНИРОВКА');
    final subCtrl = TextEditingController(text: 'Сбор в субботу в 10:00');
    final tagCtrl = TextEditingController(text: 'ВАЖНО');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text('Добавить баннер',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(labelText: 'Метка (ТЕГ)')),
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(
                controller: subCtrl,
                decoration: const InputDecoration(labelText: 'Подзаголовок')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                foregroundColor: Colors.black),
            onPressed: () {
              final blocks = List<Map<String, dynamic>>.from(
                  _tabs[_selectedTabIndex]['blocks'] ?? []);
              blocks.add({
                'type': 'banner',
                'tag': tagCtrl.text,
                'title': titleCtrl.text,
                'subtitle': subCtrl.text,
              });
              setState(() => _tabs[_selectedTabIndex]['blocks'] = blocks);
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _promptAddNotice() {
    final titleCtrl = TextEditingController(text: 'Совет недели');
    final bodyCtrl = TextEditingController(
        text: 'Не забывайте растягивать икроножные мышцы после кроссов.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text('Объявление тренера',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(labelText: 'Текст сообщения'),
                maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                foregroundColor: Colors.black),
            onPressed: () {
              final blocks = List<Map<String, dynamic>>.from(
                  _tabs[_selectedTabIndex]['blocks'] ?? []);
              blocks.add({
                'type': 'notice',
                'title': titleCtrl.text,
                'body': bodyCtrl.text,
              });
              setState(() => _tabs[_selectedTabIndex]['blocks'] = blocks);
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _promptAddVideo() {
    final titleCtrl = TextEditingController(text: 'Слалом вокруг конусов');
    final durCtrl = TextEditingController(text: '5 мин');
    final urlCtrl = TextEditingController(text: 'https://youtube.com');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2C),
        title: const Text('Видеоурок', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Название упражнения')),
            TextField(
                controller: durCtrl,
                decoration: const InputDecoration(labelText: 'Длительность')),
            TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Ссылка YouTube')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black),
            onPressed: () {
              final blocks = List<Map<String, dynamic>>.from(
                  _tabs[_selectedTabIndex]['blocks'] ?? []);
              blocks.add({
                'type': 'video_card',
                'title': titleCtrl.text,
                'duration': durCtrl.text,
                'url': urlCtrl.text,
              });
              setState(() => _tabs[_selectedTabIndex]['blocks'] = blocks);
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0E17),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F))),
      );
    }

    if (_tabs.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0E17),
        appBar: AppBar(title: const Text('Редактор вкладок')),
        body: const Center(child: Text('В таблице app_tabs пока нет записей.')),
      );
    }

    final currentTab = _tabs[_selectedTabIndex];
    final blocks = List<Map<String, dynamic>>.from(currentTab['blocks'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141724),
        title: const Text('КОНСТРУКТОР ВКЛАДОК',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        actions: [
          TextButton.icon(
            onPressed: _saveCurrentTab,
            icon: const Icon(Icons.cloud_upload, color: Color(0xFF58CC02)),
            label: const Text('СОХРАНИТЬ',
                style: TextStyle(
                    color: Color(0xFF58CC02), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Выбор редактируемой вкладки
          Container(
            color: const Color(0xFF141724),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Вкладка: ',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<int>(
                    value: _selectedTabIndex,
                    dropdownColor: const Color(0xFF1C2234),
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: List.generate(_tabs.length, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          '${_tabs[i]['label']} (${_tabs[i]['id']})',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTabIndex = val);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Настройки вкладки: название и видимость
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: currentTab['label'],
                    decoration: const InputDecoration(
                      labelText: 'Название вкладки в меню',
                      filled: true,
                      fillColor: Color(0xFF141724),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => currentTab['label'] = val,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Видна игроку',
                        style: TextStyle(color: Colors.white60, fontSize: 10)),
                    Switch(
                      value: currentTab['is_visible'] ?? true,
                      activeThumbColor: const Color(0xFF58CC02),
                      onChanged: (v) =>
                          setState(() => currentTab['is_visible'] = v),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12),

          // 3. Список блоков с возможностью удаления и предпросмотра
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ВИЗУАЛЬНЫЕ БЛОКИ ВКЛАДКИ:',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 12)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCCFF00),
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _addBlockDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ДОБАВИТЬ БЛОК',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ],
            ),
          ),

          Expanded(
            child: blocks.isEmpty
                ? const Center(
                    child: Text('Блоков нет. Нажмите «ДОБАВИТЬ БЛОК»',
                        style: TextStyle(color: Colors.white30)))
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: blocks.length,
                    itemBuilder: (ctx, i) {
                      final b = blocks[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181D2C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Text('${i + 1}.',
                                style: const TextStyle(
                                    color: Colors.white30,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${b['type'].toString().toUpperCase()}: ${b['title'] ?? ''}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  if (b['subtitle'] != null ||
                                      b['body'] != null)
                                    Text(
                                      b['subtitle'] ?? b['body'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  blocks.removeAt(i);
                                  currentTab['blocks'] = blocks;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
