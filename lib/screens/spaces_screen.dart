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
import '../widgets/search_widget.dart';

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

  bool _isSearchMode = false;
  String _searchQuery = '';

// View toggle
  bool _isGridView = false;

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

  void _openSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearchMode = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchMode = false;
      _searchQuery = '';
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim();
    });
  }

  void _toggleViewMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isGridView = !_isGridView;
      // Force rebuild by touching the state
    });
  }

  List<Space> _getFilteredSpaces() {
    if (_searchQuery.isEmpty) {
      return List.from(_spaces);
    }

    final filtered = _spaces.where((space) {
      return space.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
    return filtered;
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

  // Select All / Deselect All functionality
  void _selectAll() {
    HapticFeedback.mediumImpact();
    setState(() {
      final filteredSpaces = _getFilteredSpaces();
      _selectedSpaces.addAll(filteredSpaces.map((s) => s.id));
      _wigglingSpaces.addAll(filteredSpaces.map((s) => s.id));
    });

    if (_selectedSpaces.isNotEmpty && !_wiggleController.isAnimating) {
      _wiggleController.repeat(reverse: true);
    }
  }

  void _deselectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedSpaces.clear();
      _wigglingSpaces.clear();
    });
    _wiggleController.stop();
    _wiggleController.reset();
  }

  bool get _isAllSelected {
    final filteredSpaces = _getFilteredSpaces();
    return filteredSpaces.isNotEmpty &&
        _selectedSpaces.length == filteredSpaces.length;
  }

  bool get _isPartiallySelected {
    return _selectedSpaces.isNotEmpty && !_isAllSelected;
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
    double brightness = 1.0;
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
                          selectedColor = HSVColor.fromAHSV(
                                  1.0, hue, saturation, brightness)
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
                          selectedColor = HSVColor.fromAHSV(
                                  1.0, hue, saturation, brightness)
                              .toColor();
                        });
                      },
                      gradient: LinearGradient(
                        colors: [
                          HSVColor.fromAHSV(1.0, hue, 0.0, brightness)
                              .toColor(),
                          HSVColor.fromAHSV(1.0, hue, 1.0, brightness)
                              .toColor(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Value/Brightness Slider
                    _buildColorSlider(
                      'Brightness',
                      brightness,
                      0.0,
                      1.0,
                      (value) {
                        setModalState(() {
                          brightness = value;
                          selectedColor = HSVColor.fromAHSV(
                                  1.0, hue, saturation, brightness)
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
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10), // Smaller thumb
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 15),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              // Add these properties for better alignment
              valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
              valueIndicatorColor: Colors.transparent,
            ),
            child: Stack(
              children: [
                // Gradient container with proper margins
                Container(
                  height: 30,
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10), // Margin for thumb space
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                // Slider on top
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  onChanged: onChanged,
                ),
              ],
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

  Widget _buildGridSpaceCard(Space space, {String? searchQuery}) {
    final textColor =
        space.color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedSpaces.contains(space.id);
    final isWiggling = _wigglingSpaces.contains(space.id);

    return AnimatedBuilder(
      animation: _wiggleController,
      builder: (context, child) {
        // Simple wiggle transform - ONLY for spaces that should wiggle
        double rotation = 0.0;
        double translateX = 0.0;

        if (isWiggling && _wiggleController.isAnimating) {
          rotation = ((_wiggleController.value - 0.5) * 0.02); // Small rotation
          translateX = ((_wiggleController.value - 0.5) *
              2); // Small horizontal movement
        }

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotation)
            ..translate(translateX),
          child: GestureDetector(
            onLongPress: () {
              if (!_isSelectionMode) {
                HapticFeedback.mediumImpact();
                _enterSelectionMode(space.id);
                _startWiggle(space.id);
              }
            },
            onTap: _isSelectionMode
                ? () => _toggleSelection(space.id)
                : () => _navigateToSpaceReminders(space),
            child: Container(
              decoration: BoxDecoration(
                color: space.color,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(
                        color: isDark ? Colors.white : Colors.black,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox and icon
                    Row(
                      children: [
                        if (_isSelectionMode) ...[
                          Container(
                            width: 20,
                            height: 20,
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
                          const Spacer(),
                        ],
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            space.icon,
                            size: 18,
                            color: textColor,
                          ),
                        ),
                        if (!_isSelectionMode) const Spacer(),
                      ],
                    ),

                    const Spacer(),

                    // Space name
                    Text(
                      space.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 4),

                    // Reminder count
                    FutureBuilder<int>(
                      future: StorageService.getSpaceReminderCount(space.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(
                          '$count reminder${count == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMergeRemindersModal() {
    String? selectedTargetSpaceId;
    String? newSpaceName;
    bool deleteSourceSpaces = true;
    bool isCreatingNewSpace = false;

    return StatefulBuilder(
      builder: (context, setModalState) {
        final selectedSpacesList =
            _spaces.where((s) => _selectedSpaces.contains(s.id)).toList();

        return Container(
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.merge_outlined,
                        color: Colors.purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merge Spaces',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          Text(
                            'Combine ${selectedSpacesList.length} spaces',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Preview section
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'What will happen',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Source spaces preview
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: selectedSpacesList
                                              .take(3)
                                              .map(
                                                (space) => Container(
                                                  width: 24,
                                                  height: 24,
                                                  margin: const EdgeInsets
                                                      .symmetric(horizontal: 2),
                                                  decoration: BoxDecoration(
                                                    color: space.color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Icon(
                                                    space.icon,
                                                    size: 12,
                                                    color: space.color
                                                                .computeLuminance() >
                                                            0.5
                                                        ? Colors.black87
                                                        : Colors.white,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${selectedSpacesList.length} spaces',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.purple,
                                      size: 20,
                                    ),
                                  ),

                                  // Target preview
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: isCreatingNewSpace
                                                ? Colors.green
                                                : (selectedTargetSpaceId != null
                                                    ? selectedSpacesList
                                                        .firstWhere((s) =>
                                                            s.id ==
                                                            selectedTargetSpaceId)
                                                        .color
                                                    : Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isCreatingNewSpace
                                                ? Icons.add
                                                : (selectedTargetSpaceId != null
                                                    ? selectedSpacesList
                                                        .firstWhere((s) =>
                                                            s.id ==
                                                            selectedTargetSpaceId)
                                                        .icon
                                                    : Icons.help_outline),
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isCreatingNewSpace
                                              ? 'New space'
                                              : (selectedTargetSpaceId != null
                                                  ? 'Target space'
                                                  : 'Select target'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Target selection
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose target space',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            // Create new space option
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isCreatingNewSpace = true;
                                  selectedTargetSpaceId = null;
                                });
                                _showQuickSpaceCreationForMerge(setModalState,
                                    (spaceId, spaceName) {
                                  setModalState(() {
                                    selectedTargetSpaceId = spaceId;
                                    newSpaceName = spaceName;
                                  });
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isCreatingNewSpace
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCreatingNewSpace
                                        ? Colors.green
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.2),
                                    width: isCreatingNewSpace ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isCreatingNewSpace &&
                                                    newSpaceName != null
                                                ? newSpaceName!
                                                : 'Create New Space',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: isCreatingNewSpace
                                                      ? Colors.green.shade700
                                                      : null,
                                                ),
                                          ),
                                          Text(
                                            'Merge all reminders into a new space',
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
                                    if (isCreatingNewSpace)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: Text(
                                      'OR',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                            ),

                            // Existing spaces
                            Text(
                              'Select existing space',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 8),

                            ...selectedSpacesList.map((space) {
                              final isSelected =
                                  selectedTargetSpaceId == space.id &&
                                      !isCreatingNewSpace;
                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    selectedTargetSpaceId = space.id;
                                    isCreatingNewSpace = false;
                                    newSpaceName = null;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? space.color.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? space.color
                                          : Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(alpha: 0.2),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: space.color,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          space.icon,
                                          size: 20,
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
                                            FutureBuilder<int>(
                                              future: StorageService
                                                  .getSpaceReminderCount(
                                                      space.id),
                                              builder: (context, snapshot) {
                                                final count =
                                                    snapshot.data ?? 0;
                                                return Text(
                                                  '$count reminder${count == 1 ? '' : 's'}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                                alpha: 0.6),
                                                      ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: space.color,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Options
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
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
                                        ? Colors.red
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: deleteSourceSpaces
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 14,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        'Remove the original spaces after merging',
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
                    ],
                  ),
                ),
              ),

              // Bottom actions
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (selectedTargetSpaceId != null ||
                                isCreatingNewSpace)
                            ? () => _executeMergeReminders(
                                  selectedTargetSpaceId!,
                                  deleteSourceSpaces,
                                  isCreatingNewSpace: isCreatingNewSpace,
                                  newSpaceName: newSpaceName,
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.merge_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Merge Spaces',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Add this new method for quick space creation during merge
  void _showQuickSpaceCreationForMerge(
      StateSetter setModalState, Function(String, String) onSpaceCreated) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Space name (e.g., "Combined Tasks")',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.green.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All reminders will be moved to this new space',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // Create the space
                final spaces = await SpacesService.getSpaces();
                const availableColors = SpaceColors.presetColors;
                const availableIcons = SpaceIcons.presetIcons;

                final colorIndex = spaces.length % availableColors.length;
                final iconIndex = spaces.length % availableIcons.length;

                final newSpace = Space(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: controller.text.trim(),
                  color: availableColors[colorIndex],
                  icon: availableIcons[iconIndex],
                  createdAt: DateTime.now(),
                );

                await SpacesService.addSpace(newSpace);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  onSpaceCreated(newSpace.id, newSpace.name);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

// Update the existing _executeMergeReminders method to handle new space creation
  Future<void> _executeMergeReminders(
    String targetSpaceId,
    bool deleteSourceSpaces, {
    bool isCreatingNewSpace = false,
    String? newSpaceName,
  }) async {
    try {
      String finalTargetSpaceId = targetSpaceId;

      // If creating new space, targetSpaceId is already the new space ID from creation
      // No need to create it again since we created it in _showQuickSpaceCreationForMerge

      final sourceSpaceIds =
          _selectedSpaces.where((id) => id != finalTargetSpaceId).toList();

      // Move all reminders from source spaces to target space
      final allReminders = await StorageService.getReminders();
      final updatedReminders = allReminders.map((reminder) {
        if (sourceSpaceIds.contains(reminder.spaceId)) {
          return reminder.copyWith(spaceId: finalTargetSpaceId);
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

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCreatingNewSpace
                  ? 'Created "$newSpaceName" and merged ${sourceSpaceIds.length} spaces'
                  : 'Merged ${sourceSpaceIds.length} spaces successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error merging reminders: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error merging spaces: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('No spaces found',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Try searching with different keywords',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text('Search spaces', style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Space> spaces) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: spaces.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index >= spaces.length) return const SizedBox.shrink();
        return _buildNotionBlock(spaces[index], searchQuery: _searchQuery);
      },
    );
  }

  Widget _buildGridView(List<Space> spaces) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        if (index >= spaces.length) return const SizedBox.shrink();
        return _buildGridSpaceCard(spaces[index]);
      },
    );
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
                // Search Icon
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                  tooltip: 'Search Spaces',
                ),
                // List/Grid Toggle
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: _toggleViewMode,
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
                // Add Space
                IconButton(
                  onPressed: () => _navigateToAddSpace(),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Space',
                ),
              ],
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _getFilteredSpaces().isEmpty && _searchQuery.isNotEmpty
                  ? _buildNoSearchResults()
                  : _getFilteredSpaces().isEmpty
                      ? _buildEmptyState()
                      : _isGridView
                          ? _buildGridView(_getFilteredSpaces())
                          : _buildNotionBlocks(_getFilteredSpaces()),

          // Search overlay
          if (_isSearchMode)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Column(
                  children: [
                    SearchWidget(
                      onSearchChanged: _onSearchChanged,
                      onClose: _closeSearch,
                      hintText: 'Search spaces...',
                    ),
                    Expanded(
                      child: _searchQuery.isEmpty
                          ? _buildSearchSuggestions()
                          : _getFilteredSpaces().isEmpty
                              ? _buildNoSearchResults()
                              : _isGridView // ✅ Add grid view check here too
                                  ? _buildSearchGridView(_getFilteredSpaces())
                                  : _buildSearchResults(_getFilteredSpaces()),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchGridView(List<Space> spaces) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: spaces.length,
      itemBuilder: (context, index) {
        if (index >= spaces.length) return const SizedBox.shrink();
        return _buildGridSpaceCard(spaces[index], searchQuery: _searchQuery);
      },
    );
  }

  List<Widget> _buildBulkActions() {
    return [
      Container(
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF007AFF).withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: IconButton(
          icon: Icon(
            _isAllSelected
                ? Icons.deselect
                : (_isPartiallySelected ? Icons.checklist : Icons.select_all),
            size: 20,
          ),
          onPressed: _isAllSelected ? _deselectAll : _selectAll,
          tooltip: _isAllSelected ? 'Deselect All' : 'Select All',
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF007AFF),
          ),
        ),
      ),
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

  Widget _buildNotionBlocks(List<Space> spaces) {
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
                '${_spaces.length} ${spaces.length == 1 ? 'block' : 'blocks'}${_isSelectionMode ? '' : ' • Tap to manage reminders'}',
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
            itemCount: spaces.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildNotionBlock(spaces[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotionBlock(Space space, {String? searchQuery}) {
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
                                          // Space name with highlighting support
                                          searchQuery != null &&
                                                  searchQuery.isNotEmpty
                                              ? HighlightedText(
                                                  text: space.name,
                                                  searchTerm: searchQuery,
                                                  defaultStyle: TextStyle(
                                                    fontSize: titleFontSize,
                                                    fontWeight: FontWeight.w700,
                                                    color: textColor,
                                                    letterSpacing: -0.3,
                                                    height:
                                                        1.2, // Proper line height
                                                  ),
                                                )
                                              : Text(
                                                  space.name,
                                                  style: TextStyle(
                                                    fontSize: titleFontSize,
                                                    fontWeight: FontWeight.w700,
                                                    color: textColor,
                                                    letterSpacing: -0.3,
                                                    height:
                                                        1.2, // Proper line height
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
