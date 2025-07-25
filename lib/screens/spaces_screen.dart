import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:voice_remind/screens/filtered_reminders_screen.dart';
import 'package:voice_remind/services/storage_service.dart';
import 'dart:async';
import '../models/space.dart';
import '../services/spaces_service.dart';
import 'add_space_screen.dart';
import '../models/reminder.dart';

class SpacesScreen extends StatefulWidget {
  const SpacesScreen({super.key});

  @override
  State<SpacesScreen> createState() => _SpacesScreenState();
}

class _SpacesScreenState extends State<SpacesScreen>
    with TickerProviderStateMixin {
  List<Space> _spaces = [];
  bool _isLoading = true;
  StreamSubscription<List<Space>>? _spacesSubscription;
  StreamSubscription<List<Reminder>>? _remindersSubscription;

  // Bulk selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedSpaces = {};
  late AnimationController _selectionAnimationController;
  late AnimationController _wiggleController;
  final Set<String> _wigglingSpaces = {};

  // Delete expansion state
  bool _isDeleteExpanded = false;
  bool _deleteWithReminders = true;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
    _setupSpacesListener();
    _setupRemindersListener();

    _selectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _wiggleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _spacesSubscription?.cancel();
    _remindersSubscription?.cancel();
    _selectionAnimationController.dispose();
    _wiggleController.dispose();
    super.dispose();
  }

  void _setupRemindersListener() {
    _remindersSubscription = StorageService.remindersStream.listen((reminders) {
      if (mounted) {
        setState(() {
          // Force rebuild when reminders change to update counts
        });
      }
    });
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

  void _startWiggle(String spaceId) {
    setState(() {
      _wigglingSpaces.add(spaceId);
    });
    _wiggleController.repeat(reverse: true);
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

  // === SELECTION MODE FUNCTIONS ===

  void _enterSelectionMode(String spaceId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedSpaces.add(spaceId);
      _wigglingSpaces.add(spaceId);
    });
    _selectionAnimationController.forward();
    _wiggleController.repeat(reverse: true);
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedSpaces.clear();
      _isDeleteExpanded = false;
      _wigglingSpaces.clear();
    });
    _selectionAnimationController.reverse();
    _wiggleController.stop();
    _wiggleController.reset();
  }

  void _toggleSelection(String spaceId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedSpaces.contains(spaceId)) {
        _selectedSpaces.remove(spaceId);
        _wigglingSpaces.remove(spaceId);
        if (_selectedSpaces.isEmpty) {
          _exitSelectionMode();
          return;
        }
      } else {
        _selectedSpaces.add(spaceId);
        _wigglingSpaces.add(spaceId);
      }
    });

    if (_selectedSpaces.isNotEmpty && !_wiggleController.isAnimating) {
      _wiggleController.repeat(reverse: true);
    }
  }

  // === INDIVIDUAL SPACE ACTIONS ===

  void _navigateToAddSpace({Space? space}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSpaceScreen(space: space),
      ),
    );
  }

  Future<void> _editSpace(Space space) async {
    _navigateToAddSpace(space: space);
  }

  Future<void> _deleteSpace(Space space) async {
    await SpacesService.deleteSpace(space.id);
  }

  // === BULK ACTIONS ===

  void _showCustomColorPicker() {
    Navigator.of(context).pop(); // Close current picker
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildCustomColorPicker(),
    );
  }

  Widget _buildCustomColorPicker() {
    double hue = 0.0;
    double saturation = 1.0;
    double value = 1.0;
    Color selectedColor = Colors.red;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'CUSTOM COLOR',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

              // Material You Colors
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material You',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMaterialYouColor(
                            Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        _buildMaterialYouColor(
                            Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: 12),
                        _buildMaterialYouColor(
                            Theme.of(context).colorScheme.tertiary),
                        const SizedBox(width: 12),
                        _buildMaterialYouColor(
                            Theme.of(context).colorScheme.primaryContainer),
                        const SizedBox(width: 12),
                        _buildMaterialYouColor(
                            Theme.of(context).colorScheme.secondaryContainer),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Color Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // HSV Sliders
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Hue Slider
                    _buildColorSlider(
                      'Hue',
                      hue,
                      0.0,
                      360.0,
                      (value) {
                        setModalState(() {
                          hue = value;
                          selectedColor =
                              HSVColor.fromAHSV(1.0, hue, saturation, value)
                                  .toColor();
                        });
                      },
                      gradient: const LinearGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Saturation Slider
                    _buildColorSlider(
                      'Saturation',
                      saturation,
                      0.0,
                      1.0,
                      (value) {
                        setModalState(() {
                          saturation = value;
                          selectedColor =
                              HSVColor.fromAHSV(1.0, hue, saturation, value)
                                  .toColor();
                        });
                      },
                      gradient: LinearGradient(
                        colors: [
                          HSVColor.fromAHSV(1.0, hue, 0.0, value).toColor(),
                          HSVColor.fromAHSV(1.0, hue, 1.0, value).toColor(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Value/Brightness Slider
                    _buildColorSlider(
                      'Brightness',
                      value,
                      0.0,
                      1.0,
                      (value) {
                        setModalState(() {
                          value = value;
                          selectedColor =
                              HSVColor.fromAHSV(1.0, hue, saturation, value)
                                  .toColor();
                        });
                      },
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          HSVColor.fromAHSV(1.0, hue, saturation, 1.0)
                              .toColor(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Apply Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _applyColorToSelected(selectedColor),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedColor,
                      foregroundColor: selectedColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Custom Color',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialYouColor(Color color) {
    return GestureDetector(
      onTap: () => _applyColorToSelected(color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged,
      {required Gradient gradient}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 30,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 30,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _executeBulkDelete() async {
    try {
      await SpacesService.bulkDeleteSpaces(
        _selectedSpaces.toList(),
        deleteReminders: _deleteWithReminders,
      );
      _exitSelectionMode();
    } catch (e) {
      debugPrint('Error bulk deleting spaces: $e');
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildColorPicker(),
    );
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildIconPicker(),
    );
  }

  Future<void> _applyColorToSelected(Color color) async {
    try {
      await SpacesService.bulkUpdateSpaceColor(_selectedSpaces.toList(), color);
      if (mounted) {
        Navigator.of(context).pop(); // Close color picker
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error updating space colors: $e');
    }
  }

  Future<void> _applyIconToSelected(IconData icon) async {
    try {
      await SpacesService.bulkUpdateSpaceIcon(_selectedSpaces.toList(), icon);
      if (mounted) {
        Navigator.of(context).pop(); // Close icon picker
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error updating space icons: $e');
    }
  }

  void _showMergeReminders() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildMergeRemindersModal(),
    );
  }

  Widget _buildMergeRemindersModal() {
    String? selectedTargetSpaceId;
    bool deleteSourceSpaces = true;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final selectedSpacesList =
            _spaces.where((s) => _selectedSpaces.contains(s.id)).toList();

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.merge_outlined,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'MERGE REMINDERS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),

              // Instructions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Select which space to merge all reminders into',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.purple,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Space selection
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Space',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...selectedSpacesList.map((space) {
                      return FutureBuilder<int>(
                        future: StorageService.getSpaceReminderCount(space.id),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setModalState(() {
                                    selectedTargetSpaceId = space.id;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: selectedTargetSpaceId == space.id
                                        ? space.color.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedTargetSpaceId == space.id
                                          ? space.color
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.2),
                                      width: selectedTargetSpaceId == space.id
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Radio button
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selectedTargetSpaceId ==
                                                    space.id
                                                ? space.color
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                            width: selectedTargetSpaceId ==
                                                    space.id
                                                ? 6
                                                : 2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Space info
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: space.color,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          space.icon,
                                          size: 18,
                                          color:
                                              space.color.computeLuminance() >
                                                      0.5
                                                  ? Colors.black87
                                                  : Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              space.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            Text(
                                              '$count reminder${count == 1 ? '' : 's'}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.6),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Delete source spaces option
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setModalState(() {
                      deleteSourceSpaces = !deleteSourceSpaces;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: deleteSourceSpaces
                                ? (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              width: 1.5,
                            ),
                          ),
                          child: deleteSourceSpaces
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black
                                      : Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete source spaces',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Remove empty spaces after merging reminders',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Apply button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: selectedTargetSpaceId != null
                        ? () => _executeMergeReminders(
                            selectedTargetSpaceId!, deleteSourceSpaces)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Merge Reminders',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeMergeReminders(
      String targetSpaceId, bool deleteSourceSpaces) async {
    try {
      final sourceSpaceIds =
          _selectedSpaces.where((id) => id != targetSpaceId).toList();

      // Move all reminders from source spaces to target space
      final allReminders = await StorageService.getReminders();
      final updatedReminders = allReminders.map((reminder) {
        if (sourceSpaceIds.contains(reminder.spaceId)) {
          return reminder.copyWith(spaceId: targetSpaceId);
        }
        return reminder;
      }).toList();

      await StorageService.saveReminders(updatedReminders);

      // Delete source spaces if requested
      if (deleteSourceSpaces) {
        await SpacesService.bulkDeleteSpaces(sourceSpaceIds,
            deleteReminders: false);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Close merge modal
        _exitSelectionMode();
      }
    } catch (e) {
      debugPrint('Error merging reminders: $e');
    }
  }

  // === UI BUILDERS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isSelectionMode ? '${_selectedSpaces.length} selected' : 'Spaces'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? _buildBulkActions()
            : [
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

  List<Widget> _buildBulkActions() {
    return [
      // Color picker
      Container(
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: IconButton(
          icon: const Icon(Icons.palette_outlined, size: 20),
          onPressed: _showColorPicker,
          tooltip: 'Change Color',
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.orange,
          ),
        ),
      ),

      // Icon picker
      Container(
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: _showIconPicker,
          tooltip: 'Change Icon',
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.blue,
          ),
        ),
      ),

      // ADD THIS: Merge reminders (only show if 2+ spaces selected)
      if (_selectedSpaces.length >= 2)
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.purple.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.merge_outlined, size: 20),
            onPressed: _showMergeReminders,
            tooltip: 'Merge Reminders',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.purple,
            ),
          ),
        ),

      // Expandable delete
      _buildExpandableDeleteButton(),
    ];
  }

  Widget _buildExpandableDeleteButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFDC3545).withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: _isDeleteExpanded ? _buildExpandedDelete() : _buildCompactDelete(),
    );
  }

  Widget _buildCompactDelete() {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isDeleteExpanded = true;
        });
      },
      tooltip: 'Delete Spaces',
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFFDC3545),
      ),
    );
  }

  Widget _buildExpandedDelete() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _deleteWithReminders = !_deleteWithReminders;
              });
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _deleteWithReminders
                        ? const Color(0xFFDC3545)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: const Color(0xFFDC3545),
                      width: 1.5,
                    ),
                  ),
                  child: _deleteWithReminders
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                const Text(
                  'With reminders',
                  style: TextStyle(
                    color: Color(0xFFDC3545),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Execute delete button
          GestureDetector(
            onTap: _executeBulkDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.delete,
                color: Color(0xFFDC3545),
                size: 16,
              ),
            ),
          ),

          // Collapse button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _isDeleteExpanded = false;
              });
            },
            child: const Icon(
              Icons.close,
              color: Color(0xFFDC3545),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'SELECT COLOR',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount:
                  SpaceColors.presetColors.length + 1, // +1 for custom color
              itemBuilder: (context, index) {
                if (index == SpaceColors.presetColors.length) {
                  // Custom color picker circle
                  return GestureDetector(
                    onTap: _showCustomColorPicker,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.indigo,
                            Colors.purple,
                            Colors.red,
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.palette,
                        color: Colors.white,
                        size: 24,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final color = SpaceColors.presetColors[index];
                return GestureDetector(
                  onTap: () => _applyColorToSelected(color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildIconPicker() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'SELECT ICON',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: SpaceIcons.presetIcons.length,
              itemBuilder: (context, index) {
                final icon = SpaceIcons.presetIcons[index];
                final label = SpaceIcons.iconLabels[index];
                return GestureDetector(
                  onTap: () => _applyIconToSelected(icon),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive values
        final isSmallScreen = constraints.maxWidth < 400;
        final iconSize = isSmallScreen ? 64.0 : 80.0;
        final titleSize = isSmallScreen ? 22.0 : 26.0;
        final bodySize = isSmallScreen ? 15.0 : 16.0;
        final buttonHeight = isSmallScreen ? 52.0 : 56.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 24.0 : 32.0,
            vertical: 20,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 140, // More space for navbar
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simple, clean icon
                Container(
                  width: iconSize + 24,
                  height: iconSize + 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.create_new_folder_rounded,
                    size: iconSize,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

                SizedBox(height: isSmallScreen ? 24 : 32),

                // Clean title
                Text(
                  'No spaces yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                // Simple description
                Text(
                  'Create spaces to organize your reminders\nby themes like Work, Home, or Personal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: bodySize,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isSmallScreen ? 32 : 40),

                // Simple examples in one row
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickExample(
                          Icons.work_outline_rounded, 'Work', Colors.blue),
                      _buildQuickExample(
                          Icons.home_outlined, 'Home', Colors.green),
                      _buildQuickExample(
                          Icons.school_outlined, 'Study', Colors.orange),
                    ],
                  ),
                ),

                SizedBox(height: isSmallScreen ? 32 : 40),

                // Fixed button with proper theme colors
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: FilledButton.icon(
                    onPressed: () => _navigateToAddSpace(),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      'Create Space',
                      style: TextStyle(
                        fontSize: bodySize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onPrimary, // This fixes dark mode text
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),

                // Add extra bottom padding to avoid navbar overlap
                SizedBox(
                    height: isSmallScreen
                        ? 100
                        : 120), // Extra space for floating navbar
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickExample(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
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
                '${_spaces.length} ${_spaces.length == 1 ? 'block' : 'blocks'}${_isSelectionMode ? '' : ' • Tap to manage reminders'}',
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
    final isSelected = _selectedSpaces.contains(space.id);
    final isWiggling = _wigglingSpaces.contains(space.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing
        final isSmallScreen = constraints.maxWidth < 400;
        final cardHeight = isSmallScreen ? 72.0 : 80.0;
        final iconSize = isSmallScreen ? 36.0 : 40.0;
        final titleFontSize = isSmallScreen ? 15.0 : 16.0;
        final subtitleFontSize = isSmallScreen ? 12.0 : 13.0;

        return Row(
          children: [
            // Selection checkbox
            if (_isSelectionMode) ...[
              GestureDetector(
                onTap: () => _toggleSelection(space.id),
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isDark ? Colors.white : Colors.black,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: isDark ? Colors.black : Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ),
            ],

            // Space card
            Expanded(
              child: Slidable(
                key: ValueKey(space.id),
                enabled: !_isSelectionMode,
                endActionPane: ActionPane(
                  motion: const BehindMotion(),
                  extentRatio: 0.35,
                  children: [
                    // Edit Action
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(
                            left: 4, right: 2, top: 2, bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _editSpace(space),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Delete Action
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(
                            left: 2, right: 4, top: 2, bottom: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _deleteSpace(space),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC3545)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC3545),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Color(0xFFDC3545),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      HapticFeedback.mediumImpact();
                      _enterSelectionMode(space.id);
                      _startWiggle(space.id);
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _wiggleController,
                    builder: (context, child) {
                      // Simple wiggle transform - ONLY for spaces that should wiggle
                      double rotation = 0.0;
                      double translateX = 0.0;

                      if (isWiggling && _wiggleController.isAnimating) {
                        rotation = ((_wiggleController.value - 0.5) *
                            0.02); // Small rotation
                        translateX = ((_wiggleController.value - 0.5) *
                            2); // Small horizontal movement
                      }

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..rotateZ(rotation)
                          ..translate(translateX),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(space.id)
                                : () => _navigateToSpaceReminders(space),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: cardHeight,
                              decoration: BoxDecoration(
                                color: space.color,
                                borderRadius: BorderRadius.circular(16),
                                border: isSelected
                                    ? Border.all(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        width: 2,
                                      )
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: space.color.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 16 : 20),
                                child: Row(
                                  children: [
                                    // Icon container
                                    Container(
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        color: textColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(
                                            isSmallScreen ? 8 : 10),
                                      ),
                                      child: Icon(
                                        space.icon,
                                        size: isSmallScreen ? 18 : 20,
                                        color: textColor,
                                      ),
                                    ),

                                    SizedBox(width: isSmallScreen ? 12 : 16),

                                    // Text content - FIXED LAYOUT
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Space name with proper spacing
                                          Text(
                                            space.name,
                                            style: TextStyle(
                                              fontSize: titleFontSize,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                              letterSpacing: -0.3,
                                              height: 1.2, // Proper line height
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),

                                          // Add proper spacing between title and subtitle
                                          SizedBox(
                                              height: isSmallScreen ? 2 : 4),

                                          // Reminder count with proper spacing
                                          FutureBuilder<int>(
                                            future: StorageService
                                                .getSpaceReminderCount(
                                                    space.id),
                                            builder: (context, snapshot) {
                                              final count = snapshot.data ?? 0;
                                              return Text(
                                                '$count reminder${count == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontSize: subtitleFontSize,
                                                  color: textColor.withValues(
                                                      alpha: 0.8),
                                                  fontWeight: FontWeight.w500,
                                                  height:
                                                      1.2, // Proper line height
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrow indicator
                                    if (!_isSelectionMode) ...[
                                      SizedBox(width: isSmallScreen ? 8 : 12),
                                      Container(
                                        padding: EdgeInsets.all(
                                            isSmallScreen ? 4 : 6),
                                        decoration: BoxDecoration(
                                          color:
                                              textColor.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: isSmallScreen ? 12 : 14,
                                          color:
                                              textColor.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSpaceReminders(Space space) async {
    final spaceReminders = await StorageService.getRemindersBySpace(space.id);

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilteredRemindersScreen(
          filterType: FilterType.total,
          allReminders: spaceReminders,
          customTitle: space.name,
          customIcon: space.icon,
          customColor: space.color,
          spaceId: space.id,
        ),
      ),
    );
  }
}
