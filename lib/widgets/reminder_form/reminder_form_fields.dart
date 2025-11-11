// [lib/widgets/reminder_form]/reminder_form_fields.dart
// Combined form fields widget for reminder creation/editing

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../controllers/reminder_form_controller.dart';
import '../../utils/reminder_helpers.dart';
import 'date_picker_field.dart';
import 'repeat_type_selector.dart';
import 'space_selector_field.dart';
import '../multi_time_section.dart';

class ReminderFormFields extends StatefulWidget {
  final ReminderFormController controller;
  final bool showSpaceSelector;
  final bool showNotificationToggle;
  final bool showCurrentTime;
  final GlobalKey<FormState>? formKey;

  const ReminderFormFields({
    super.key,
    required this.controller,
    this.showSpaceSelector = true,
    this.showNotificationToggle = true,
    this.showCurrentTime = true,
    this.formKey,
  });

  @override
  State<ReminderFormFields> createState() => _ReminderFormFieldsState();
}

class _ReminderFormFieldsState extends State<ReminderFormFields> {
  DateTime _currentTime = DateTime.now();
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();

    if (widget.showCurrentTime) {
      // Start real-time timer
      _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _currentTime = DateTime.now();
          });
        }
      });
    }

    // Listen to controller changes
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.onSurface,
            width: 1.0,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
      validator: validator,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.onSurface,
          inactiveThumbColor: Theme.of(context).colorScheme.outline,
          inactiveTrackColor:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Time Display
          if (widget.showCurrentTime) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.5)
                    : const Color(0xFFF7F7F7).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, yyyy • h:mm:ss a')
                            .format(_currentTime),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Input Section
          _buildSection(
            'DETAILS',
            [
              _buildInputField(
                controller: widget.controller.titleController,
                label: 'Title',
                hint: 'What do you want to be reminded about?',
                icon: Icons.title,
                validator: validateReminderTitle,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: widget.controller.descriptionController,
                label: 'Description',
                hint: 'Add more details...',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Schedule Section
          _buildSection(
            'SCHEDULE',
            [
              DatePickerField(
                selectedDate: widget.controller.selectedDate,
                onDateChanged: widget.controller.setSelectedDate,
                isMultiTime: widget.controller.isMultiTime,
              ),
              _buildDivider(),

              // Multi-Time Section or Single Time
              MultiTimeSection(
                timeSlots: widget.controller.timeSlots,
                onTimeSlotsChanged: widget.controller.setTimeSlots,
                isMultiTime: widget.controller.isMultiTime,
                onMultiTimeToggle: widget.controller.setMultiTime,
                initialSingleTime: widget.controller.selectedTime,
                onSingleTimeChanged: widget.controller.setSelectedTime,
                singleTimeLabel: 'Time',
                showToggleButton: true,
                padding: EdgeInsets.zero,
              ),
              _buildDivider(),

              RepeatTypeSelector(
                selectedRepeat: widget.controller.selectedRepeat,
                onRepeatChanged: widget.controller.setRepeatType,
              ),
            ],
          ),

          // Space Section
          if (widget.showSpaceSelector) ...[
            const SizedBox(height: 32),
            _buildSection(
              'SPACE',
              [
                SpaceSelectorField(
                  selectedSpace: widget.controller.selectedSpace,
                  availableSpaces: widget.controller.availableSpaces,
                  onSpaceChanged: widget.controller.setSelectedSpace,
                ),
              ],
            ),
          ],

          // Settings Section
          if (widget.showNotificationToggle) ...[
            const SizedBox(height: 32),
            _buildSection(
              'SETTINGS',
              [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Enable Notifications',
                  subtitle: 'Get notified when it\'s time',
                  value: widget.controller.isNotificationEnabled,
                  onChanged: widget.controller.setNotificationEnabled,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
