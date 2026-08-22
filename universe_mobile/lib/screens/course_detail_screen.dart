import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';


class CourseDetailScreen extends StatefulWidget {
  final dynamic course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _resources = [];
  List<dynamic> _groups = [];
  bool _loadingResources = true;
  bool _loadingGroups = true;
  String? _typeFilter;
  final _searchController = TextEditingController();

    String? _myUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserId();
    _fetchResources();
    _fetchGroups();
  }

  Future<void> _loadUserId() async {
    final id = await SessionService.getUserId();
    setState(() {
      _myUserId = id;
    });
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this group?'),
        content: const Text('This removes it for everyone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
        if (confirm == true) {
      final token = await SessionService.getToken();
      final response = await http.delete(
        Uri.parse('http://localhost:3000/education/groups/$groupId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _fetchGroups();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Failed to delete (status ${response.statusCode})')),
          );
        }
      }
    }
  }

  Future<void> _fetchResources() async {
    setState(() {
      _loadingResources = true;
    });
    final token = await SessionService.getToken();
    final params = <String, String>{};
    if (_typeFilter != null) params['type'] = _typeFilter!;
    if (_searchController.text.trim().isNotEmpty) params['search'] = _searchController.text.trim();
    final uri = Uri.parse('http://localhost:3000/education/courses/${widget.course['id']}/resources')
        .replace(queryParameters: params.isEmpty ? null : params);
    try {
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final data = jsonDecode(response.body);
      setState(() {
        _resources = data['resources'] ?? [];
        _loadingResources = false;
      });
    } catch (e) {
      setState(() {
        _loadingResources = false;
      });
    }
  }

  Future<void> _fetchGroups() async {
    setState(() {
      _loadingGroups = true;
    });
    final token = await SessionService.getToken();
    try {
      final response = await http.get(
        Uri.parse('http://localhost:3000/education/courses/${widget.course['id']}/groups'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      setState(() {
        _groups = data['groups'] ?? [];
        _loadingGroups = false;
      });
    } catch (e) {
      setState(() {
        _loadingGroups = false;
      });
    }
  }

  Future<void> _toggleMembership(dynamic group) async {
    final token = await SessionService.getToken();
    if (group['isMember'] == true) {
      await http.delete(
        Uri.parse('http://localhost:3000/education/groups/${group['id']}/leave'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } else {
      await http.post(
        Uri.parse('http://localhost:3000/education/groups/${group['id']}/join'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
    _fetchGroups();
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Study Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final token = await SessionService.getToken();
              final response = await http.post(
                Uri.parse('http://localhost:3000/education/courses/${widget.course['id']}/groups'),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
                body: jsonEncode({'name': nameController.text.trim(), 'description': descController.text.trim()}),
              );
              final data = jsonDecode(response.body);
              if (context.mounted) Navigator.pop(context, data['success'] == true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _fetchGroups();
  }

  Future<void> _uploadResource() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty || files.first.path == null) return;
    final pickedFile = files.first;

    final file = File(pickedFile.path!);
    final titleController = TextEditingController(text: pickedFile.name);
    String type = 'note';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Upload Resource', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['note', 'past_question', 'slide', 'other'].map((t) {
                  return ChoiceChip(
                    label: Text(t),
                    selected: type == t,
                    onSelected: (_) => setModalState(() => type = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final token = await SessionService.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('http://localhost:3000/education/courses/${widget.course['id']}/resources'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = titleController.text.trim();
    request.fields['resourceType'] = type;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      _fetchResources();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resource uploaded')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Upload failed')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course['name']),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          tabs: const [Tab(text: 'Resources'), Tab(text: 'Study Groups')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildResourcesTab(), _buildGroupsTab()],
      ),
    );
  }

  Widget _buildResourcesTab() {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchResources(),
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet),
              ),
            ),
          ),
          Expanded(
            child: _loadingResources
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _resources.isEmpty
                    ? const Center(child: Text('No resources yet — be the first to share.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _resources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final r = _resources[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                r['resource_type'] == 'past_question' ? Icons.quiz_outlined : Icons.description_outlined,
                                color: AppColors.primary,
                              ),
                              title: Text(r['title']),
                              subtitle: Text(r['resource_type']),
                              trailing: const Icon(Icons.download_outlined),
                              onTap: () => launchUrl(Uri.parse(r['file_path']), mode: LaunchMode.externalApplication),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _uploadResource,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ['note', 'past_question', 'slide', 'other'].map((type) {
          return ListTile(
            title: Text(type),
            onTap: () {
              setState(() {
                _typeFilter = _typeFilter == type ? null : type;
              });
              Navigator.pop(context);
              _fetchResources();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupsTab() {
    return Scaffold(
      body: _loadingGroups
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _groups.isEmpty
              ? const Center(child: Text('No study groups yet — start one!'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final g = _groups[index];
                                        final isCreator = g['created_by'] == _myUserId;
                    return Card(
                      child: ListTile(
                        title: Text(g['name']),
                        subtitle: Text('${g['memberCount']} members'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCreator)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteGroup(g['id']),
                              ),
                            ElevatedButton(
                              onPressed: () => _toggleMembership(g),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: g['isMember'] == true ? Colors.grey.shade300 : AppColors.primary,
                                foregroundColor: g['isMember'] == true ? Colors.black87 : Colors.white,
                              ),
                              child: Text(g['isMember'] == true ? 'Leave' : 'Join'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _createGroup,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}