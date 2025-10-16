// lib/widgets/search_widgets.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/file_model.dart';
import '../views/search.dart'; // ✅ Đường dẫn đúng (service, không phải view)

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchManager _searchManager = SearchManager();
  final TextEditingController _nameController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;
  Map<String, bool> _fileTypes = {
    'doc': false,
    'txt': false,
    'pdf': false,
    'jpg': false,
    'png': false,
  };

  List<FileModel> _results = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Bạn cần đăng nhập để tìm kiếm.')),
      );
      setState(() => _loading = false);
      return;
    }

    // 🔹 Lấy profileId từ bảng profiles
    final profileRes = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (profileRes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Không tìm thấy profile của người dùng.')),
      );
      setState(() => _loading = false);
      return;
    }

    final profileId = profileRes['id'];

    final selectedTypes = _fileTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final results = await _searchManager.searchFiles(
      profileId: profileId, // ✅ đúng tên tham số
      nameQuery: _nameController.text,
      fromDate: _fromDate,
      toDate: _toDate,
      fileTypes: selectedTypes.isEmpty ? null : selectedTypes,
    );

    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  Widget _buildFileTile(FileModel file) {
    return ListTile(
      leading: Icon(file.isFolder ? Icons.folder : Icons.insert_drive_file),
      title: Text(file.name),
      subtitle: Text(
        '${file.type ?? 'Không rõ'} • ${(file.size ?? 0).toStringAsFixed(2)} KB',
      ),
      trailing: Text(file.createdAt != null
          ? '${file.createdAt!.toLocal()}'.split(' ')[0]
          : ''),
      onTap: () {
        // TODO: mở file hoặc xem chi tiết
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm File')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên file',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickFromDate,
                  child: Text(_fromDate != null
                      ? 'Từ: ${_fromDate!.toLocal()}'.split(' ')[0]
                      : 'Từ ngày'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _pickToDate,
                  child: Text(_toDate != null
                      ? 'Đến: ${_toDate!.toLocal()}'.split(' ')[0]
                      : 'Đến ngày'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _fileTypes.keys.map((ext) {
                return FilterChip(
                  label: Text(ext),
                  selected: _fileTypes[ext]!,
                  onSelected: (val) {
                    setState(() => _fileTypes[ext] = val);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _search,
              child: const Text('Tìm kiếm'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? const Center(child: Text('Không tìm thấy kết quả'))
                  : ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) =>
                    _buildFileTile(_results[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
