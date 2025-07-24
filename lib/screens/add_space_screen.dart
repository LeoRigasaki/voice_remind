// [lib]/screens/add_space_screen.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/space.dart';
import '../services/spaces_service.dart';

class AddSpaceScreen extends StatefulWidget {
  final Space? space;

  const AddSpaceScreen({super.key, this.space});

  @override
  State<AddSpaceScreen> createState() => _AddSpaceScreenState();
}

class _AddSpaceScreenState extends State<AddSpaceScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Color _selectedColor = SpaceColors.presetColors[0];
  IconData _selectedIcon = SpaceIcons.presetIcons[0];
  bool _isLoading = false;
  bool _isEditing = false;

  // Animation controllers for micro-animations
  late AnimationController _colorSelectionController;
  late AnimationController _iconSelectionController;
  late AnimationController _previewController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _colorSelectionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconSelectionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _previewController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (widget.space != null) {
      _isEditing = true;
      _populateFieldsForEditing();
    }

    // Start preview animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewController.forward();
    });
  }

  void _populateFieldsForEditing() {
    final space = widget.space!;
    _nameController.text = space.name;
    _selectedColor = space.color;
    _selectedIcon = space.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorSelectionController.dispose();
    _iconSelectionController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  Future<void> _saveSpace() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final space = Space(
        id: _isEditing ? widget.space!.id : const Uuid().v4(),
        name: _nameController.text.trim(),
        color: _selectedColor,
        icon: _selectedIcon,
        createdAt: _isEditing ? widget.space!.createdAt : DateTime.now(),
      );

      if (_isEditing) {
        await SpacesService.updateSpace(space);
      } else {
        await SpacesService.addSpace(space);
      }

      if (mounted) {
        Navigator.of(context).pop();
        // Space saved successfully - no toast shown
      }
    } catch (e) {
      if (mounted) {
        // Error saving space - just log it, no toast
        debugPrint('Error saving space: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // === CUSTOM COLOR PICKER METHODS (Reused from SpacesScreen) ===

  void _showCustomColorPicker() {
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
                    onPressed: () => _applyCustomColor(selectedColor),
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
      onTap: () => _applyCustomColor(color),
      child: AnimatedScale(
        scale: 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          width: 36, // Slightly smaller
          height: 36,
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

  void _applyCustomColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
    _colorSelectionController.forward().then((_) {
      _colorSelectionController.reverse();
    });
    Navigator.of(context).pop(); // Close color picker
  }

  // === END CUSTOM COLOR PICKER METHODS ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Space' : 'New Space'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSpace,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildNameField(),
            const SizedBox(height: 24),
            _buildColorPicker(),
            const SizedBox(height: 24),
            _buildIconPicker(),
            const SizedBox(height: 24),
            _buildPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Space Name',
        hintText: 'Enter space name',
        prefixIcon: Icon(Icons.label_outline),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a space name';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _saveSpace(),
      onChanged: (value) {
        // Trigger preview animation on text change
        _previewController.reset();
        _previewController.forward();
      },
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6, // Increased from 5 to make circles smaller
            crossAxisSpacing: 10, // Reduced spacing
            mainAxisSpacing: 10,
          ),
          itemCount: SpaceColors.presetColors.length + 1, // +1 for custom color
          itemBuilder: (context, index) {
            if (index == SpaceColors.presetColors.length) {
              // Custom color picker circle with animation
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 200 + (index * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () {
                        _showCustomColorPicker();
                        // Add haptic feedback
                        _colorSelectionController.forward().then((_) {
                          _colorSelectionController.reverse();
                        });
                      },
                      child: AnimatedScale(
                        scale: 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.elasticOut,
                        child: Container(
                          width: 36, // Smaller size
                          height: 36,
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
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.palette,
                            color: Colors.white,
                            size: 18, // Smaller icon
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
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

            final color = SpaceColors.presetColors[index];
            final isSelected = color == _selectedColor;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 200 + (index * 50)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                      // Trigger selection animation
                      _colorSelectionController.forward().then((_) {
                        _colorSelectionController.reverse();
                      });
                      // Trigger preview update
                      _previewController.reset();
                      _previewController.forward();
                    },
                    child: AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.elasticOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 36, // Smaller size
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  width: 3,
                                )
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: AnimatedOpacity(
                          opacity: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            size: 16, // Smaller icon
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Icon',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Increased from 4 to make items smaller
            crossAxisSpacing: 8, // Reduced spacing
            mainAxisSpacing: 8,
            childAspectRatio: 0.9, // Slightly adjusted
          ),
          itemCount: SpaceIcons.presetIcons.length,
          itemBuilder: (context, index) {
            final icon = SpaceIcons.presetIcons[index];
            final label = SpaceIcons.iconLabels[index];
            final isSelected = icon == _selectedIcon;

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 30)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                      // Trigger icon selection animation
                      _iconSelectionController.forward().then((_) {
                        _iconSelectionController.reverse();
                      });
                      // Trigger preview update
                      _previewController.reset();
                      _previewController.forward();
                    },
                    child: AnimatedScale(
                      scale: isSelected ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.15)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(
                              10), // Slightly smaller radius
                          border: Border.all(
                            color: isSelected
                                ? _selectedColor
                                : Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        _selectedColor.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 3), // Reduced padding
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  icon,
                                  color: isSelected
                                      ? _selectedColor
                                      : Theme.of(context).colorScheme.onSurface,
                                  size: 18, // Smaller icon
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(
                                        fontSize: 8, // Smaller text
                                        color: isSelected
                                            ? _selectedColor
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        height: 1.1,
                                      ),
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final textColor =
        _selectedColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _previewController,
          builder: (context, child) {
            final scaleAnimation = Tween<double>(
              begin: 0.9,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: _previewController,
              curve: Curves.easeOutBack,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: _previewController,
              curve: Curves.easeOut,
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        // Animated icon container
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              _selectedIcon,
                              key: ValueKey(_selectedIcon),
                              size: 20,
                              color: textColor,
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Text content with animation
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _nameController.text.isEmpty
                                        ? 'Space Name'
                                        : _nameController.text,
                                    key: ValueKey(_nameController.text),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Flexible(
                                child: Text(
                                  '0 reminders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Animated arrow indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
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
          },
        ),
      ],
    );
  }
}
