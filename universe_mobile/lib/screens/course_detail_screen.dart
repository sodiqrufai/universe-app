import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../services/session_service.dart';
import '../services/api_service.dart';

class CourseDetailScreen extends StatefulWidget {
  final dynamic course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _resources = [];
  List<dynamic> _groups = [];
  bool _loadingResources = true;
  bool _loadingGroups = true;
  bool _resourcesError = false;
  bool _groupsError = false;
  String? _typeFilter;
  final _searchController = TextEditingController();

  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  Future<void> _init() async {
    _myUserId = await SessionService.getUserId();
    _fetchResources();
    _fetchGroups();
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Delete this group?'),
        content: const Text('This removes it for everyone. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final data = await ApiService.delete('/education/groups/$groupId');
        if (data['success'] == true) {
          _fetchGroups();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not delete group')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete group')),
          );
        }
      }
    }
  }

  Future<void> _fetchResources() async {
    setState(() {
      _loadingResources = true;
      _resourcesError = false;
    });
    final params = <String, String>{};
    if (_typeFilter != null) params['type'] = _typeFilter!;
    if (_searchController.text.trim().isNotEmpty) {
      params['search'] = _searchController.text.trim();
    }
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    try {
      final data = await ApiService.get(
        '/education/courses/${widget.course['id']}/resources$query',
      );
      setState(() {
        _resources = data['resources'] ?? [];
        _loadingResources = false;
      });
    } catch (e) {
      setState(() {
        _resourcesError = true;
        _loadingResources = false;
      });
    }
  }

  Future<void> _fetchGroups() async {
    setState(() {
      _loadingGroups = true;
      _groupsError = false;
    });
    try {
      final data = await ApiService.get(
        '/education/courses/${widget.course['id']}/groups',
      );
      setState(() {
        _groups = data['groups'] ?? [];
        _loadingGroups = false;
      });
    } catch (e) {
      setState(() {
        _groupsError = true;
        _loadingGroups = false;
      });
    }
  }

  Future<void> _toggleMembership(dynamic group) async {
    try {
      final data = group['isMember'] == true
          ? await ApiService.delete('/education/groups/${group['id']}/leave')
          : await ApiService.post('/education/groups/${group['id']}/join', {});
      if (data['success'] != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update group membership')),
        );
      }
      _fetchGroups();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update group membership')),
        );
      }
    }
  }

  Future<void> _showMembers(String groupId, String groupName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => FutureBuilder(
          future: ApiService.get('/education/groups/$groupId/members'),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            final data = snapshot.data as Map<String, dynamic>;
            final members = data['members'] ?? [];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(groupName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                Expanded(
                  child: members.isEmpty
                      ? const Center(child: Text('No members yet'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final m = members[index]['profiles'];
                            final avatarUrl = m?['avatar_url'];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.lightPurple,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? const Icon(Icons.person, color: AppColors.primary)
                                    : null,
                              ),
                              title: Text(m?['full_name'] ?? 'Student'),
                              subtitle: m?['username'] != null ? Text('@${m['username']}') : null,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: const Text('Create Study Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Group name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                final data = await ApiService.post(
                  '/education/courses/${widget.course['id']}/groups',
                  {
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  },
                );
                if (context.mounted) {
                  Navigator.pop(context, data['success'] == true);
                }
              } catch (_) {
                if (context.mounted) Navigator.pop(context, false);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) {
      _fetchGroups();
    } else if (created == false && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not create group')));
    }
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
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Resource',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
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

    // ApiService has no multipart/file-upload method — this is the one
    // legitimate remaining raw http call in this file, using the same
    // token source as everywhere else.
    try {
      final token = await SessionService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/education/courses/${widget.course['id']}/resources',
        ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Resource uploaded')));
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Upload failed')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload failed')));
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
        title: Text(widget.course['name'] ?? 'Course'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Resources'),
            Tab(text: 'Study Groups'),
          ],
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _fetchResources(),
              decoration: InputDecoration(
                hintText: 'Search resources...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showFilterSheet,
                ),
              ),
            ),
          ),
          Expanded(child: _buildResourcesList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _uploadResource,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }

  Widget _buildResourcesList() {
    if (_loadingResources) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_resourcesError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load resources'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchResources, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_resources.isEmpty) {
      return const Center(child: Text('No resources yet — be the first to share.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _resources.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final r = _resources[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.lightPurple,
              child: Icon(
                r['resource_type'] == 'past_question'
                    ? Icons.quiz_outlined
                    : Icons.description_outlined,
                color: AppColors.primary,
              ),
            ),
            title: Text(r['title'] ?? ''),
            subtitle: Text(
              r['resource_type'] ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.download_outlined, color: AppColors.textMuted),
            onTap: () => launchUrl(
              Uri.parse(r['file_path']),
              mode: LaunchMode.externalApplication,
            ),
          ),
        );
      },
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
      body: _buildGroupsList(),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: _createGroup,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildGroupsList() {
    if (_loadingGroups) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_groupsError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('Could not load study groups'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchGroups, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_groups.isEmpty) {
      return const Center(child: Text('No study groups yet — start one!'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final g = _groups[index];
        final isCreator = g['created_by'] == _myUserId;
        final isMember = g['isMember'] == true;
        return Card(
          child: ListTile(
            title: Text(g['name'] ?? ''),
            subtitle: GestureDetector(
              onTap: () => _showMembers(g['id'], g['name'] ?? 'Group'),
              child: Text(
                '${g['memberCount'] ?? 0} members · View members',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCreator)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                    onPressed: () => _deleteGroup(g['id']),
                  ),
                OutlinedButton(
                  onPressed: () => _toggleMembership(g),
                  style: isMember
                      ? OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                        )
                      : ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ).copyWith(
                          side: WidgetStateProperty.all(BorderSide.none),
                        ),
                  child: Text(isMember ? 'Leave' : 'Join'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
