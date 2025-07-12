import 'package:flutter/material.dart';
import 'package:voice_remind/screens/filtered_reminders_screen.dart';
import 'package:voice_remind/services/storage_service.dart';
import 'dart:async';
import '../models/space.dart';
import '../services/spaces_service.dart';
import 'add_space_screen.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen> {
  List<Space> _spaces = [];
  bool _isLoading = true;
  StreamSubscription<List<Space>>? _spacesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
    _setupSpacesListener();
  }

  @override
  void dispose() {
    _spacesSubscription?.cancel();
    super.dispose();
  }

  void _setupSpacesListener() {
    _spacesSubscription = SpacesService.spacesStream.listen((spaces) {
      if (mounted) {
        setState(() {
          _spaces = spaces;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpacesService.getSpaces();
      if (mounted) {
        setState(() {
          _spaces = spaces;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToAddSpace({Space? space}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSpaceScreen(space: space),
      ),
    );
  }

  Future<void> _deleteSpace(Space space) async {
    await SpacesService.deleteSpace(space.id);
  }

  void _showDeleteDialog(Space space) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Space'),
        content: Text('Are you sure you want to delete "${space.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteSpace(space);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spaces'),
        actions: [
          IconButton(
            onPressed: () => _navigateToAddSpace(),
            icon: const Icon(Icons.add),
            tooltip: 'Add Space',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _spaces.isEmpty
              ? _buildEmptyState()
              : _buildNotionBlocks(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.view_module_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No spaces yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create workspace-style blocks to organize reminders',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddSpace(),
            icon: const Icon(Icons.add),
            label: const Text('Create Space'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotionBlocks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_spaces.length} ${_spaces.length == 1 ? 'block' : 'blocks'} • Tap to manage reminders',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),

        // Blocks
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _spaces.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildNotionBlock(_spaces[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotionBlock(Space space) {
    final textColor =
        space.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSpaceReminders(space),
        onLongPress: () => _showSpaceOptions(space),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 80,
          decoration: BoxDecoration(
            color: space.color, // Changed from gradient to solid color
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: space.color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.8),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon section
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    space.icon,
                    size: 20,
                    color: textColor,
                  ),
                ),

                const SizedBox(width: 16),

                // Content section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        space.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: StorageService.getSpaceReminderCount(space.id),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Text(
                            '$count reminder${count == 1 ? '' : 's'}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: textColor.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Action indicator
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSpaceOptions(Space space) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with solid color block preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: space.color, // Changed from gradient to solid color
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          space.icon,
                          size: 24,
                          color: space.color.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                space.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: space.color.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                ),
                              ),
                              FutureBuilder<int>(
                                future: StorageService.getSpaceReminderCount(
                                    space.id),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  return Text(
                                    '$count reminder${count == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          (space.color.computeLuminance() > 0.5
                                                  ? Colors.black87
                                                  : Colors.white)
                                              .withValues(alpha: 0.8),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Actions
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Block'),
                onTap: () {
                  Navigator.of(context).pop();
                  _navigateToAddSpace(space: space);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete Block',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteDialog(space);
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToSpaceReminders(Space space) async {
    final spaceReminders = await StorageService.getRemindersBySpace(space.id);

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilteredRemindersScreen(
          filterType: FilterType.total, // Use total as base type
          allReminders: spaceReminders,
          customTitle: space.name,
          customIcon: space.icon,
          customColor: space.color,
        ),
      ),
    );
  }
}
