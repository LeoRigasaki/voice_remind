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

class _AddSpaceScreenState extends State<AddSpaceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  Color _selectedColor = SpaceColors.presetColors[0];
  IconData _selectedIcon = SpaceIcons.presetIcons[0];
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    if (widget.space != null) {
      _isEditing = true;
      _populateFieldsForEditing();
    }
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
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 5, // 5 columns for 10 colors
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
          children: SpaceColors.presetColors.map((color) {
            final isSelected = color == _selectedColor;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                });
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.onSurface,
                          width: 3,
                        )
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
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
            crossAxisCount:
                5, // Changed from 4 to 5 for better layout with 10 colors
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: SpaceIcons.presetIcons.length,
          itemBuilder: (context, index) {
            final icon = SpaceIcons.presetIcons[index];
            final label = SpaceIcons.iconLabels[index];
            final isSelected = icon == _selectedIcon;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = icon;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedColor.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _selectedColor
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      color: isSelected
                          ? _selectedColor
                          : Theme.of(context).colorScheme.onSurface,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? _selectedColor
                                : Theme.of(context).colorScheme.onSurface,
                            fontSize: 10,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
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

        // Notion-style block preview
        Container(
          height: 90, // Increased from 80 to 90 for more space
          decoration: BoxDecoration(
            color: _selectedColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _selectedColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
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
                    _selectedIcon,
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
                    mainAxisSize: MainAxisSize.min, // Added to prevent overflow
                    children: [
                      Flexible(
                        // Wrapped Text in Flexible
                        child: Text(
                          _nameController.text.isEmpty
                              ? 'Space Name'
                              : _nameController.text,
                          style: TextStyle(
                            fontSize: 14, // Reduced from 16
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1, // Ensure single line
                        ),
                      ),
                      const SizedBox(height: 4), // Increased from 2
                      Text(
                        '0 reminders',
                        style: TextStyle(
                          fontSize: 11, // Reduced from 12
                          color: textColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
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
                    size: 12, // Reduced from 14
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
