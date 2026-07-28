import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';


class ManageExercisesMainScreen extends StatefulWidget {
  const ManageExercisesMainScreen({super.key});

  @override
  State<ManageExercisesMainScreen> createState() =>
      _ManageExercisesMainScreenState();
}

class _ManageExercisesMainScreenState extends State<ManageExercisesMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? selectedGrade;
  String? selectedTopic;
  bool _loading = false;
  bool _loadingTopics = false;
  bool _showDeleted = false;

  String? selectedMode;
  String? selectedSet;
  String? selectedType;
  String searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  List<String> availableSets = [];
  List<String> availableTypes = [];

  final List<String> gradeLevels = ['ป.1', 'ป.2', 'ป.3'];

  final Map<String, String> modeOptions = {
    'speech': '🎤 อ่านออกเสียง',
    'main_screen': '📖 อ่านบทความ',
    'quiz': '🧠 แบบทดสอบ',
    'drag_drop': '🐣 ลากวาง',
    'classify': '✒️ จัดหมวดหมู่',
  };

  List<String> availableTopics = [];
  Map<String, String> _topicNames = {};
  List<DocumentSnapshot> _docs = [];
  List<DocumentSnapshot> _filteredDocs = [];


  String topicsSelectedGrade = 'ป.2';

  final Map<String, String> fieldLabels = {
    'mode': 'โหมดแบบฝึก',
    'title': 'ชื่อเรื่อง',
    'lines': 'เนื้อหาบทความ',
    'question': 'คำถาม',
    'choice1': 'ตัวเลือกที่ 1',
    'choice2': 'ตัวเลือกที่ 2',
    'choice3': 'ตัวเลือกที่ 3',
    'choice4': 'ตัวเลือกที่ 4',
    'answer': 'คำตอบ',
    'word': 'คำ',
    'example': 'ตัวอย่าง',
    'tts_text': 'ข้อความอ่านออกเสียง',
    'check': 'ตรวจสอบคำที่ถูก',
    'letter': 'ตัวอักษร',
    'paragraph': 'ย่อหน้า',
    'set': 'ชุดที่',
    'meaning': 'ความหมาย',
    'type': 'ประเภท',
    'choices': 'ตัวเลือก',
    'instruction': 'คำสั่ง',
    'questions': 'คำถาม (รายการ)',
  };

  final Set<String> systemFields = {
    'rubric',
    'tokens',
    'token_hints',
    'created_at',
    'updated_at',
    'deleted_at',
    'is_deleted',
    'display_fields',
    'บทความ',
    'text',
    'หัวข้อ',
    'สถานะลบ',
    'โหมดแบบฝึก',
    'syllable_break',
  };

  String _gradeToNumber(String grade) => grade.replaceAll('ป.', '');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F8),
      appBar: AppBar(
        title: const Text('จัดการแบบฝึกหัด'),
        elevation: 0,
        actions: [
          // ✅ Actions สำหรับ Exercise Tab
          if (_tabController.index == 0 &&
              selectedGrade != null &&
              selectedTopic != null) ...[
            if (_hasActiveFilters())
              IconButton(
                tooltip: 'ล้างตัวกรอง',
                icon: const Icon(Icons.filter_alt_off, color: Colors.orange),
                onPressed: _clearFilters,
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'toggle_deleted') {
                  setState(() => _showDeleted = !_showDeleted);
                  _loadDocuments();
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'toggle_deleted',
                      child: Row(
                        children: [
                          Icon(
                            _showDeleted ? Icons.list : Icons.delete_sweep,
                            color: _showDeleted ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(_showDeleted ? 'แสดงรายการปกติ' : 'แสดงถังขยะ'),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}), // ✅ Refresh actions เมื่อเปลี่ยน tab
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'จัดการแบบฝึกหัด'),
            Tab(icon: Icon(Icons.category), text: 'จัดการหัวข้อ'),
          ],
        ),
      ),
      // ✅ FAB สำหรับแต่ละ tab
      floatingActionButton: _buildFAB(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExerciseTab(), // ✅ ไม่ใช้ Navigator ซ้อน
          _buildTopicsTab(), // ✅ ไม่ใช้ Navigator ซ้อน
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    if (_tabController.index == 0) {
      // Exercise Tab
      if (selectedGrade != null && selectedTopic != null && !_showDeleted) {
        return FloatingActionButton.extended(
          onPressed: () => _showEditSheet(null),
          icon: const Icon(Icons.add),
          label: const Text('เพิ่มข้อมูลใหม่'),
        );
      }
    } else {
      // Topics Tab
      return FloatingActionButton.extended(
        onPressed: () => _showTopicDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มหัวข้อ'),
      );
    }
    return null;
  }

  Widget _buildExerciseTab() {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: CustomScrollView(
            slivers: [
              // ✅ Filter Card
              SliverToBoxAdapter(child: _buildFilterCard(theme)),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ✅ Advanced Filter (ถ้าเลือก topic แล้ว)
              if (selectedGrade != null && selectedTopic != null) ...[
                SliverToBoxAdapter(child: _buildAdvancedFilterBar(theme)),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // ✅ Result Count
              if (selectedGrade != null && selectedTopic != null && !_loading)
                SliverToBoxAdapter(child: _buildResultCount()),

              // ✅ Loading / Content
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildDocListSliver(),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return selectedMode != null ||
        selectedSet != null ||
        selectedType != null ||
        searchQuery.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      selectedMode = null;
      selectedSet = null;
      selectedType = null;
      searchQuery = '';
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  Widget _buildAdvancedFilterBar(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '🔍 ค้นหาคำ, ตัวอย่าง, คำถาม...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon:
                          searchQuery.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => searchQuery = '');
                                  _applyFilters();
                                },
                              )
                              : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: selectedMode,
                    hint: 'โหมด',
                    icon: Icons.category,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทุกโหมด'),
                      ),
                      ...modeOptions.entries.map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => selectedMode = v);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    value: selectedSet,
                    hint: 'ชุดที่',
                    icon: Icons.folder,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทุกชุด'),
                      ),
                      ...availableSets.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text('ชุดที่ $s'),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => selectedSet = v);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    value: selectedType,
                    hint: 'ประเภท',
                    icon: Icons.label,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ทุกประเภท'),
                      ),
                      ...availableTypes.map(
                        (t) => DropdownMenuItem(value: t, child: Text(t)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => selectedType = v);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                if (_hasActiveFilters())
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('ล้าง'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(hint, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResultCount() {
    final total = _docs.length;
    final filtered = _filteredDocs.length;
    final hasFilter = _hasActiveFilters();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasFilter ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasFilter ? Icons.filter_list : Icons.list,
                  size: 16,
                  color: hasFilter ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  hasFilter
                      ? 'แสดง $filtered จาก $total รายการ'
                      : 'ทั้งหมด $total รายการ',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        hasFilter ? Colors.blue.shade700 : Colors.grey.shade700,
                    fontWeight: hasFilter ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (availableSets.length <= 5 && availableSets.isNotEmpty)
            ...availableSets
                .take(4)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: FilterChip(
                      label: Text(
                        'ชุด $s',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: selectedSet == s,
                      onSelected: (selected) {
                        setState(() => selectedSet = selected ? s : null);
                        _applyFilters();
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('เลือกระดับชั้น', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  gradeLevels.map((g) {
                    final active = selectedGrade == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: active,
                      onSelected: (_) async {
                        setState(() {
                          selectedGrade = g;
                          selectedTopic = null;
                          _docs = [];
                          _filteredDocs = [];
                          availableTopics = [];
                          _topicNames = {};
                          _showDeleted = false;
                          _clearFilters();
                        });
                        await _loadTopics();
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 16),
            if (selectedGrade != null) ...[
              Row(
                children: [
                  Text('เลือกหัวข้อ', style: theme.textTheme.titleMedium),
                  if (_loadingTopics) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (availableTopics.isEmpty && !_loadingTopics)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'ไม่พบหัวข้อในระดับชั้นนี้',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      availableTopics
                          .map(
                            (t) => FilterChip(
                              label: Text(_topicNames[t] ?? t),
                              selected: selectedTopic == t,
                              onSelected: (_) {
                                setState(() {
                                  selectedTopic = t;
                                  _showDeleted = false;
                                  _clearFilters();
                                });
                                _loadDocuments();
                              },
                            ),
                          )
                          .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadTopics() async {
    if (selectedGrade == null) return;
    setState(() => _loadingTopics = true);

    try {
      final gradeNumber = _gradeToNumber(selectedGrade!);
      final topicsSnapshot =
          await FirebaseFirestore.instance
              .collection('exercise_topics')
              .where('grade', isEqualTo: gradeNumber)
              .where('is_active', isEqualTo: true)
              .get();

      final topicNames = <String, String>{};
      final topicData = <Map<String, dynamic>>[];

      for (final doc in topicsSnapshot.docs) {
        final data = doc.data();
        topicNames[doc.id] = data['name_th'] ?? doc.id;
        topicData.add({'id': doc.id, 'order': data['order'] ?? 0});
      }

      topicData.sort((a, b) => a['order'].compareTo(b['order']));

      setState(() {
        availableTopics = topicData.map((t) => t['id'] as String).toList();
        _topicNames = topicNames;
        _loadingTopics = false;
      });
    } catch (e) {
      setState(() => _loadingTopics = false);
    }
  }

  Future<void> _loadDocuments() async {
    if (selectedGrade == null || selectedTopic == null) return;
    setState(() => _loading = true);

    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    final collectionRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(selectedTopic!);

    try {
      final snap = await collectionRef.get();
      final List<DocumentSnapshot> filteredDocs = [];
      final sets = <String>{};
      final types = <String>{};

      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isDeleted = data['is_deleted'] == true;

        if (data['set'] != null) sets.add(data['set'].toString());
        if (data['type'] != null) types.add(data['type'].toString());

        if (_showDeleted) {
          if (isDeleted) filteredDocs.add(doc);
        } else {
          if (!data.containsKey('is_deleted') || !isDeleted) {
            filteredDocs.add(doc);
          }
        }
      }

      final sortedSets =
          sets.toList()..sort((a, b) {
            final aNum = int.tryParse(a) ?? 0;
            final bNum = int.tryParse(b) ?? 0;
            return aNum.compareTo(bNum);
          });

      setState(() {
        _docs = filteredDocs;
        _filteredDocs = filteredDocs;
        availableSets = sortedSets;
        availableTypes = types.toList()..sort();
        _loading = false;
      });

      _applyFilters();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    List<DocumentSnapshot> result = [..._docs];

    if (selectedMode != null) {
      result =
          result.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['mode'] == selectedMode;
          }).toList();
    }

    if (selectedSet != null) {
      result =
          result.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['set']?.toString() == selectedSet;
          }).toList();
    }

    if (selectedType != null) {
      result =
          result.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['type']?.toString() == selectedType;
          }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result =
          result.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final searchableFields = [
              'word',
              'example',
              'title',
              'question',
              'tts_text',
              'meaning',
              'instruction',
              'letter',
              'paragraph',
            ];
            for (final field in searchableFields) {
              final value = data[field]?.toString().toLowerCase() ?? '';
              if (value.contains(query)) return true;
            }
            return false;
          }).toList();
    }

    setState(() => _filteredDocs = result);
  }

  Future<String> _nextAutoId() async {
    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    final colRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(selectedTopic!);

    final snap = await colRef.get();
    int maxNum = 0;
    final re = RegExp(r'(\d+)');

    for (final d in snap.docs) {
      final m = re.firstMatch(d.id);
      if (m != null) {
        final n = int.tryParse(m.group(1)!) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return (maxNum + 1).toString().padLeft(2, '0');
  }

  Widget _buildDocListSliver() {
    if (selectedGrade == null || selectedTopic == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('เลือก "ระดับชั้น" และ "หัวข้อ" ตามลำดับ')),
      );
    }

    final items = [..._filteredDocs];

    // ✅ Empty State
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min, // ✅ ใช้ min แทน max
              children: [
                Icon(
                  _hasActiveFilters()
                      ? Icons.search_off
                      : (_showDeleted ? Icons.delete_sweep : Icons.inbox),
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  _hasActiveFilters()
                      ? 'ไม่พบข้อมูลที่ตรงกับตัวกรอง'
                      : (_showDeleted
                          ? 'ไม่มีข้อมูลในถังขยะ'
                          : 'ยังไม่มีข้อมูลในหัวข้อนี้'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                if (_hasActiveFilters()) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('ล้างตัวกรอง'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Sort items
    items.sort((a, b) {
      final rx = RegExp(r'\d+');
      final am = rx.firstMatch(a.id);
      final bm = rx.firstMatch(b.id);
      final ai = am != null ? int.tryParse(am.group(0)!) ?? 0 : 0;
      final bi = bm != null ? int.tryParse(bm.group(0)!) ?? 0 : 0;
      return ai.compareTo(bi);
    });

    // ✅ ใช้ SliverList แทน ListView
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final doc = items[index];
        final data = (doc.data() as Map<String, dynamic>? ?? {});
        final isDeleted = data['is_deleted'] == true;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            color: isDeleted ? Colors.grey.shade100 : null,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              leading: CircleAvatar(
                backgroundColor: isDeleted ? Colors.grey.shade300 : null,
                child: Text('${index + 1}'),
              ),
              title: Text(
                _getDocumentPreview(data),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                  color: isDeleted ? Colors.grey : null,
                ),
              ),
              subtitle: _buildSubtitle(data, isDeleted),
              trailing: _buildTrailingButtons(doc, isDeleted),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 8),
                _kvGrid(data),
              ],
            ),
          ),
        );
      }, childCount: items.length),
    );
  }

  Widget? _buildSubtitle(Map<String, dynamic> data, bool isDeleted) {
    if (isDeleted) {
      return Text(
        'ถูกลบแล้ว',
        style: TextStyle(color: Colors.red.shade300, fontSize: 12),
      );
    }

    final mode = data['mode']?.toString() ?? '';
    final set = data['set']?.toString();
    final type = data['type']?.toString();

    final parts = <String>[];
    if (mode.isNotEmpty) parts.add(modeOptions[mode] ?? mode);
    if (set != null) parts.add('ชุดที่ $set');
    if (type != null) parts.add(type);

    if (parts.isEmpty) return null;
    return Text(
      parts.join(' • '),
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );
  }

  Widget _buildTrailingButtons(DocumentSnapshot doc, bool isDeleted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isDeleted)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _showEditSheet(doc),
            icon: const Icon(Icons.edit),
          ),
        if (isDeleted)
          IconButton(
            tooltip: 'กู้คืน',
            onPressed: () => _restore(doc.id),
            icon: const Icon(Icons.restore, color: Colors.green),
          ),
        IconButton(
          tooltip: isDeleted ? 'ลบถาวร' : 'ลบ',
          onPressed:
              () => isDeleted ? _hardDelete(doc.id) : _softDelete(doc.id),
          icon: Icon(
            isDeleted ? Icons.delete_forever : Icons.delete_outline,
            color: isDeleted ? Colors.red : Colors.orange,
          ),
        ),
      ],
    );
  }

  String _getDocumentPreview(Map<String, dynamic> data) {
    if (data['mode'] == 'main_screen' && data.containsKey('title')) {
      return '📖 ${data['title']}';
    }

    const priorityFields = ['title', 'word', 'example', 'question', 'tts_text'];
    for (final field in priorityFields) {
      final value = data[field];
      if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();
        return text.length > 50 ? '${text.substring(0, 50)}...' : text;
      }
    }
    return 'ไม่มีข้อมูล';
  }

  Widget _kvGrid(Map<String, dynamic> data) {
    final filteredEntries =
        data.entries.where((e) => !systemFields.contains(e.key)).toList();

    if (filteredEntries.isEmpty) return const Text('— ไม่มีข้อมูล —');

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 800 ? 3 : (c.maxWidth > 520 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 78,
          ),
          itemCount: filteredEntries.length,
          itemBuilder: (_, i) {
            final e = filteredEntries[i];
            final label = fieldLabels[e.key] ?? e.key;
            String value = e.value?.toString() ?? '';

            if (e.key == 'mode') value = modeOptions[value] ?? value;

            if (e.key == 'lines') {
              try {
                final List<dynamic> lines = jsonDecode(value);
                value = '📝 ${lines.length} บรรทัด';
              } catch (_) {}
            }

            // ✅ แสดง choices array
            if (e.key == 'choices') {
              try {
                final List<dynamic> choices = jsonDecode(value);
                value = choices.join(', ');
              } catch (_) {}
            }

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFECEAF1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _softDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ย้ายไปถังขยะ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('ย้ายไปถังขยะ'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(selectedTopic!)
        .doc(id)
        .update({'is_deleted': true});
    await _loadDocuments();
  }

  Future<void> _hardDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('ลบถาวร?'),
            content: const Text('การกระทำนี้ไม่สามารถกู้คืนได้!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('ลบถาวร'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(selectedTopic!)
        .doc(id)
        .delete();
    await _loadDocuments();
  }

  Future<void> _restore(String id) async {
    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    await FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(selectedTopic!)
        .doc(id)
        .update({'is_deleted': false});
    await _loadDocuments();
  }

  void _showEditSheet(DocumentSnapshot? doc) async {
    final isEditing = doc != null;
    final original = (doc?.data() as Map<String, dynamic>? ?? {});

    String sheetMode = original['mode']?.toString() ?? 'speech';
    String? currentTopicInSheet = selectedTopic;

    // ✅ Controller สำหรับ set และ type
    final setCtrl = TextEditingController(
      text: original['set']?.toString() ?? '',
    );
    final typeCtrl = TextEditingController(
      text: original['type']?.toString() ?? '',
    );

    final titleCtrl = TextEditingController(
      text: original['title']?.toString() ?? '',
    );
    final linesCtrl = TextEditingController();
    final exampleCtrl = TextEditingController(
      text: original['example']?.toString() ?? '',
    );
    final meaningCtrl = TextEditingController(
      text: original['meaning']?.toString() ?? '',
    );
    final ttsTextCtrl = TextEditingController(
      text: original['tts_text']?.toString() ?? '',
    );

    // ✅✅✅ เพิ่ม paragraphCtrl สำหรับ quiz ✅✅✅
    final paragraphCtrl = TextEditingController(
      text: original['paragraph']?.toString() ?? '',
    );

    final questionCtrl = TextEditingController(
      text: original['question']?.toString() ?? '',
    );

    // ✅✅✅ โหลด choices - รองรับทั้ง array และ choice1-4 ✅✅✅
    final choice1Ctrl = TextEditingController();
    final choice2Ctrl = TextEditingController();
    final choice3Ctrl = TextEditingController();
    final choice4Ctrl = TextEditingController();

    // ลองโหลดจาก choices array ก่อน
    if (original.containsKey('choices')) {
      try {
        final dynamic choicesRaw = original['choices'];
        List<dynamic> choicesList = [];

        if (choicesRaw is String) {
          // ถ้าเป็น JSON string
          choicesList = jsonDecode(choicesRaw);
        } else if (choicesRaw is List) {
          // ถ้าเป็น List อยู่แล้ว
          choicesList = choicesRaw;
        }

        if (choicesList.isNotEmpty) {
          if (choicesList.length > 0) choice1Ctrl.text = choicesList[0]?.toString() ?? '';
          if (choicesList.length > 1) choice2Ctrl.text = choicesList[1]?.toString() ?? '';
          if (choicesList.length > 2) choice3Ctrl.text = choicesList[2]?.toString() ?? '';
          if (choicesList.length > 3) choice4Ctrl.text = choicesList[3]?.toString() ?? '';
        }
      } catch (e) {
        debugPrint('Error parsing choices: $e');
      }
    } else {
      // ถ้าไม่มี choices array ให้โหลดจาก choice1-4
      choice1Ctrl.text = original['choice1']?.toString() ?? '';
      choice2Ctrl.text = original['choice2']?.toString() ?? '';
      choice3Ctrl.text = original['choice3']?.toString() ?? '';
      choice4Ctrl.text = original['choice4']?.toString() ?? '';
    }

    final answerCtrl = TextEditingController(
      text: original['answer']?.toString() ?? '',
    );
    final instructionCtrl = TextEditingController(
      text: original['instruction']?.toString() ?? '',
    );
    final choicesCtrl = TextEditingController();
    final questionsCtrl = TextEditingController();

    if (original.containsKey('lines')) {
      try {
        final List<dynamic> list = jsonDecode(original['lines'].toString());
        linesCtrl.text = list.join('\n');
      } catch (_) {
        linesCtrl.text = original['lines']?.toString() ?? '';
      }
    }

    // สำหรับ drag_drop choices
    if (original.containsKey('choices') && sheetMode == 'drag_drop') {
      try {
        final dynamic choicesRaw = original['choices'];
        List<dynamic> list = [];
        if (choicesRaw is String) {
          list = jsonDecode(choicesRaw);
        } else if (choicesRaw is List) {
          list = choicesRaw;
        }
        choicesCtrl.text = list.join(', ');
      } catch (_) {}
    }

    if (original.containsKey('questions')) {
      try {
        final List<dynamic> list = jsonDecode(original['questions'].toString());
        questionsCtrl.text = list
            .map((q) {
              final s = q['sentence'] ?? '';
              final a = (q['answers'] ?? []).isNotEmpty ? q['answers'][0] : '';
              return a.isNotEmpty ? '$s >>> $a' : s;
            })
            .join('\n');
      } catch (_) {}
    }

    if (original.containsKey('buckets')) {
      try {
        final List<dynamic> list = jsonDecode(original['buckets'].toString());
        choicesCtrl.text = list.join(', ');
      } catch (_) {}
    }

    if (original.containsKey('items')) {
      try {
        final List<dynamic> list = jsonDecode(original['items'].toString());
        questionsCtrl.text = list
            .map((item) {
              final word = item['word'] ?? '';
              final bucket = item['bucket'] ?? '';
              return bucket.isNotEmpty ? '$word >>> $bucket' : word;
            })
            .join('\n');
      } catch (_) {}
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                    top: 12,
                  ),
                  child: ListView(
                    controller: controller,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isEditing ? Icons.edit : Icons.add_circle_outline,
                            color: Theme.of(ctx).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isEditing ? 'แก้ไขข้อมูล' : 'เพิ่มข้อมูลใหม่',
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ✅ เลือกหัวข้อ (เฉพาะตอนเพิ่มใหม่)
                      if (!isEditing && availableTopics.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: currentTopicInSheet,
                          decoration: const InputDecoration(
                            labelText: 'หัวข้อ',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              availableTopics
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(_topicNames[t] ?? t),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) =>
                                  setSheetState(() => currentTopicInSheet = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ✅ เลือก Mode
                      DropdownButtonFormField<String>(
                        value: sheetMode,
                        decoration: const InputDecoration(
                          labelText: '🎯 โหมดแบบฝึก',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'speech',
                            child: Text('🎤 อ่านออกเสียง'),
                          ),
                          DropdownMenuItem(
                            value: 'main_screen',
                            child: Text('📖 อ่านบทความ'),
                          ),
                          DropdownMenuItem(
                            value: 'quiz',
                            child: Text('🧠 แบบทดสอบ'),
                          ),
                          DropdownMenuItem(
                            value: 'drag_drop',
                            child: Text('🐣 ลากวาง'),
                          ),
                          DropdownMenuItem(
                            value: 'classify',
                            child: Text('✒️ จัดหมวดหมู่'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setSheetState(() => sheetMode = v);
                        },
                      ),

                      const SizedBox(height: 16),

            
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: setCtrl,
                              decoration: const InputDecoration(
                                labelText: '📁 ชุดที่',
                                hintText: 'เช่น 1, 2, 3',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      if (sheetMode == 'main_screen') ...[
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อเรื่อง *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: linesCtrl,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: 'เนื้อหาบทความ *',
                            hintText:
                                'พิมพ์แต่ละบรรทัด แล้ว Enter ขึ้นบรรทัดใหม่',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],

                      // speech mode
                      if (sheetMode == 'speech') ...[
                        TextFormField(
                          controller: exampleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'คำ/ประโยคที่ต้องอ่าน *',
                            hintText: 'เช่น กบ, แมว, สวัสดี',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.record_voice_over),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: meaningCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ความหมาย',
                            hintText: 'เช่น สัตว์สะเทินน้ำสะเทินบก',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ttsTextCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ข้อความที่อ่านให้ฟัง',
                            hintText: 'เช่น อ่านคำว่า กบ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      // ✅✅✅ quiz mode - เพิ่ม paragraph ✅✅✅
                      if (sheetMode == 'quiz') ...[
                        // ✅ เพิ่มช่อง paragraph/บทความ
                        TextFormField(
                          controller: paragraphCtrl,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: '📄 บทความ (ถ้ามี)',
                            hintText: 'พิมพ์บทความที่ใช้ในคำถาม...\nสามารถเว้นว่างได้ถ้าไม่มีบทความ',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: questionCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'คำถาม *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: choice1Ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'ตัวเลือก 1 *',
                                  hintText: 'เช่น ก. กรุงเทพ',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: choice2Ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'ตัวเลือก 2 *',
                                  hintText: 'เช่น ข. เชียงใหม่',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: choice3Ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'ตัวเลือก 3',
                                  hintText: 'เช่น ค. ภูเก็ต',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: choice4Ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'ตัวเลือก 4',
                                  hintText: 'เช่น ง. ขอนแก่น',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: answerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'คำตอบที่ถูก *',
                            hintText: 'กรอกตัวเลือกที่ถูกต้อง เช่น ค. อินเดีย',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      // drag_drop mode
                      if (sheetMode == 'drag_drop') ...[
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อแบบฝึก',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: instructionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'คำสั่ง',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: choicesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ตัวเลือก',
                            hintText: 'กบ, กด, เกาะ',
                            helperText: 'คั่นด้วย , (คอมม่า)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: questionsCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'ประโยค',
                            hintText: 'สัตว์ครึ่งบกครึ่งน้ำ คือ... >>> กบ',
                            helperText: 'ประโยค... >>> คำตอบ (แต่ละบรรทัด)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      // classify mode
                      if (sheetMode == 'classify') ...[
                        TextFormField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อเรื่อง *',
                            hintText: 'เช่น แยกคำควบกล้ำ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: instructionCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'คำสั่ง *',
                            hintText: 'เช่น ลากคำไปไว้ในช่องที่ถูกต้อง',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.assignment),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: choicesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'หมวดหมู่ (buckets) *',
                            hintText: 'คำควบกล้ำแท้, คำควบกล้ำไม่แท้',
                            helperText: 'คั่นด้วย , (คอมม่า)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: questionsCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'คำ และหมวดหมู่',
                            hintText: 'กลาง >>> คำควบกล้ำแท้\nทราย >>> คำควบกล้ำไม่แท้',
                            helperText: 'คำ >>> หมวดหมู่ (แต่ละบรรทัด)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('ยกเลิก'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('บันทึก'),
                            onPressed:
                                () => _save(
                                  ctx,
                                  isEditing,
                                  doc,
                                  currentTopicInSheet,
                                  sheetMode,
                                  setCtrl,
                                  typeCtrl,
                                  titleCtrl,
                                  linesCtrl,
                                  exampleCtrl,
                                  meaningCtrl,
                                  ttsTextCtrl,
                                  paragraphCtrl, // ✅ เพิ่ม
                                  questionCtrl,
                                  choice1Ctrl,
                                  choice2Ctrl,
                                  choice3Ctrl,
                                  choice4Ctrl,
                                  answerCtrl,
                                  instructionCtrl,
                                  choicesCtrl,
                                  questionsCtrl,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ✅ แก้ไข _save เพิ่ม paragraphCtrl
  Future<void> _save(
    BuildContext ctx,
    bool isEditing,
    DocumentSnapshot? doc,
    String? topic,
    String mode,
    TextEditingController setCtrl,
    TextEditingController typeCtrl,
    TextEditingController titleCtrl,
    TextEditingController linesCtrl,
    TextEditingController exampleCtrl,
    TextEditingController meaningCtrl,
    TextEditingController ttsCtrl,
    TextEditingController paragraphCtrl, // ✅ เพิ่ม
    TextEditingController questionCtrl,
    TextEditingController c1,
    TextEditingController c2,
    TextEditingController c3,
    TextEditingController c4,
    TextEditingController ansCtrl,
    TextEditingController instrCtrl,
    TextEditingController choicesCtrl,
    TextEditingController questionsCtrl,
  ) async {
    // ✅ Validate: ต้องกรอกชุดที่
    if (setCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอก "ชุดที่"'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final t = isEditing ? selectedTopic : (topic ?? selectedTopic);
    final gradeKey = 'g_${_gradeToNumber(selectedGrade!)}';
    final colRef = FirebaseFirestore.instance
        .collection('questions')
        .doc(gradeKey)
        .collection(t!);

    final payload = <String, dynamic>{
      'mode': mode,
      'is_deleted': false,
      'set': setCtrl.text.trim(),
    };

    // ✅ เพิ่ม type ถ้ามี
    if (typeCtrl.text.trim().isNotEmpty) {
      payload['type'] = typeCtrl.text.trim();
    }

    // main_screen mode
    if (mode == 'main_screen') {
      payload['title'] = titleCtrl.text.trim();
      final list =
          linesCtrl.text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
      payload['lines'] = jsonEncode(list);
    }

    // speech mode
    if (mode == 'speech') {
      if (exampleCtrl.text.trim().isNotEmpty) {
        payload['example'] = exampleCtrl.text.trim();
        payload['check'] = exampleCtrl.text.trim();
      }
      if (meaningCtrl.text.trim().isNotEmpty) {
        payload['meaning'] = meaningCtrl.text.trim();
      }
      if (ttsCtrl.text.trim().isNotEmpty) {
        payload['tts_text'] = ttsCtrl.text.trim();
      }
    }

    // ✅✅✅ quiz mode - เพิ่ม paragraph ✅✅✅
    if (mode == 'quiz') {
      // ✅ บันทึก paragraph
      if (paragraphCtrl.text.trim().isNotEmpty) {
        payload['paragraph'] = paragraphCtrl.text.trim();
      }

      if (questionCtrl.text.trim().isNotEmpty) {
        payload['question'] = questionCtrl.text.trim();
      }

      // ✅ บันทึก choices เป็น array
      final choicesList = <String>[];
      if (c1.text.trim().isNotEmpty) choicesList.add(c1.text.trim());
      if (c2.text.trim().isNotEmpty) choicesList.add(c2.text.trim());
      if (c3.text.trim().isNotEmpty) choicesList.add(c3.text.trim());
      if (c4.text.trim().isNotEmpty) choicesList.add(c4.text.trim());

      if (choicesList.isNotEmpty) {
        payload['choices'] = jsonEncode(choicesList);
      }

      // ✅ บันทึก choice1-4 แยกด้วย (backward compatible)
      if (c1.text.trim().isNotEmpty) payload['choice1'] = c1.text.trim();
      if (c2.text.trim().isNotEmpty) payload['choice2'] = c2.text.trim();
      if (c3.text.trim().isNotEmpty) payload['choice3'] = c3.text.trim();
      if (c4.text.trim().isNotEmpty) payload['choice4'] = c4.text.trim();

      if (ansCtrl.text.trim().isNotEmpty) {
        payload['answer'] = ansCtrl.text.trim();
      }
    }

    // drag_drop mode
    if (mode == 'drag_drop') {
      if (titleCtrl.text.trim().isNotEmpty) {
        payload['title'] = titleCtrl.text.trim();
      }
      if (instrCtrl.text.trim().isNotEmpty) {
        payload['instruction'] = instrCtrl.text.trim();
      }
      if (choicesCtrl.text.trim().isNotEmpty) {
        payload['choices'] = jsonEncode(
          choicesCtrl.text
              .split(',')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList(),
        );
      }
      if (questionsCtrl.text.trim().isNotEmpty) {
        final qs =
            questionsCtrl.text
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((line) {
                  final parts = line.split('>>>');
                  return {
                    'sentence': parts[0].trim(),
                    'answers': parts.length > 1 ? [parts[1].trim()] : [],
                  };
                })
                .toList();
        payload['questions'] = jsonEncode(qs);
      }
    }

    // classify mode
    if (mode == 'classify') {
      if (titleCtrl.text.trim().isNotEmpty) {
        payload['title'] = titleCtrl.text.trim();
      }
      if (instrCtrl.text.trim().isNotEmpty) {
        payload['instruction'] = instrCtrl.text.trim();
      }
      // buckets
      if (choicesCtrl.text.trim().isNotEmpty) {
        payload['buckets'] = jsonEncode(
          choicesCtrl.text
              .split(',')
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList(),
        );
      }
      // items (คำ >>> หมวดหมู่)
      if (questionsCtrl.text.trim().isNotEmpty) {
        final items =
            questionsCtrl.text
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .map((line) {
                  final parts = line.split('>>>');
                  return {
                    'word': parts[0].trim(),
                    'bucket': parts.length > 1 ? parts[1].trim() : '',
                  };
                })
                .toList();
        payload['items'] = jsonEncode(items);
      }
    }

    try {
      if (isEditing) {
        await colRef.doc(doc!.id).update(payload);
      } else {
        final newId = await _nextAutoId();
        await colRef.doc(newId).set(payload);
      }
      if (!mounted) return;
      Navigator.pop(ctx);
      await _loadDocuments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'บันทึกแล้ว' : 'เพิ่มข้อมูลแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildTopicsTab() {
    final grades = ['ป.1', 'ป.2', 'ป.3'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Text(
                'ระดับชั้น:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              ...grades.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: topicsSelectedGrade == g,
                    onSelected: (s) {
                      if (s) setState(() => topicsSelectedGrade = g);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('exercise_topics')
                    .where(
                      'grade',
                      isEqualTo: _gradeToNumber(topicsSelectedGrade),
                    )
                    .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty)
                return Center( 
                  child: Text('ไม่มีหัวข้อใน $topicsSelectedGrade'),
                );

              final topics =
                  snap.data!.docs.toList()..sort(
                    (a, b) => ((a.data() as Map)['order'] ?? 0).compareTo(
                      (b.data() as Map)['order'] ?? 0,
                    ),
                  );

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: topics.length,
                itemBuilder: (_, i) {
                  final doc = topics[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Text(
                        data['icon'] ?? '📚',
                        style: const TextStyle(fontSize: 32),
                      ),
                      title: Text(
                        data['name_th'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        data['is_active'] == true ? 'เปิดใช้งาน' : 'ปิด',
                        style: TextStyle(
                          color:
                              data['is_active'] == true
                                  ? Colors.green
                                  : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showTopicDialog(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _confirmDelTopic(doc),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTopicDialog(DocumentSnapshot? doc) {
    final isEdit = doc != null;
    final data = doc?.data() as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: data?['name_th'] ?? '');
    final iconCtrl = TextEditingController(text: data?['icon'] ?? '📚');
    final orderCtrl = TextEditingController(
      text: (data?['order'] ?? 0).toString(),
    );
    bool isActive = data?['is_active'] ?? true;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setState) => AlertDialog(
                  title: Text(isEdit ? 'แก้ไขหัวข้อ' : 'เพิ่มหัวข้อ'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อหัวข้อ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: iconCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Emoji',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: orderCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'ลำดับ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('เปิดใช้งาน'),
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final payload = {
                          'name_th': nameCtrl.text.trim(),
                          'grade': _gradeToNumber(topicsSelectedGrade),
                          'icon':
                              iconCtrl.text.trim().isNotEmpty
                                  ? iconCtrl.text.trim()
                                  : '📚',
                          'order': int.tryParse(orderCtrl.text) ?? 0,
                          'is_active': isActive,
                          'updated_at': FieldValue.serverTimestamp(),
                        };
                        if (doc == null) {
                          payload['created_at'] = FieldValue.serverTimestamp();
                          await FirebaseFirestore.instance
                              .collection('exercise_topics')
                              .add(payload);
                        } else {
                          await doc.reference.update(payload);
                        }
                        if (mounted) Navigator.pop(ctx);
                      },
                      child: const Text('บันทึก'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _confirmDelTopic(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('ลบหัวข้อ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () async {
                  await doc.reference.delete();
                  if (mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('ลบ'),
              ),
            ],
          ),
    );
  }
}