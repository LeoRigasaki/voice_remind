import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/custom_repeat_config.dart';

class CustomRepeatDialog extends StatefulWidget {
  final CustomRepeatConfig? initialConfig;

  const CustomRepeatDialog({
    super.key,
    this.initialConfig,
  });

  @override
  State<CustomRepeatDialog> createState() => _CustomRepeatDialogState();
}

class _CustomRepeatDialogState extends State<CustomRepeatDialog> {
  late TextEditingController _minutesController;
  late TextEditingController _hoursController;
  late TextEditingController _daysController;

  Set<int> _selectedDays = {}; // 1=Mon, 7=Sun
  DateTime? _endDate;
  String? _errorMessage;
  String? _hintMessage;

  @override
  void initState() {
    super.initState();

    final config = widget.initialConfig;
    _minutesController = TextEditingController(
      text: config != null && config.minutes > 0 ? '${config.minutes}' : '',
    );
    _hoursController = TextEditingController(
      text: config != null && config.hours > 0 ? '${config.hours}' : '',
    );
    _daysController = TextEditingController(
      text: config != null && config.days > 0 ? '${config.days}' : '',
    );

    if (config != null) {
      _selectedDays = config.specificDays ?? {};
      _endDate = config.endDate;
    }

    // Add listeners for real-time validation
    _minutesController.addListener(_onInputChanged);
    _hoursController.addListener(_onInputChanged);
    _daysController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _hoursController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _validateAndNormalize();
    });
  }

  void _validateAndNormalize() {
    _errorMessage = null;
    _hintMessage = null;

    final config = _buildConfig();
    if (config == null) return;

    // Check validation
    final error = config.validationError;
    if (error != null) {
      _errorMessage = error;
      return;
    }

    // Check if it matches existing repeat type
    final matchType = config.matchesExistingRepeatType();
    if (matchType != null) {
      _hintMessage =
          'This is the same as "$matchType". Consider using $matchType repeat instead.';
    }

    // Auto-normalize if there's overflow
    final normalized = config.normalized;
    if (normalized.minutes != config.minutes ||
        normalized.hours != config.hours ||
        normalized.days != config.days) {
      // Update controllers without triggering listeners
      _minutesController.removeListener(_onInputChanged);
      _hoursController.removeListener(_onInputChanged);
      _daysController.removeListener(_onInputChanged);

      _minutesController.text =
          normalized.minutes > 0 ? '${normalized.minutes}' : '';
      _hoursController.text = normalized.hours > 0 ? '${normalized.hours}' : '';
      _daysController.text = normalized.days > 0 ? '${normalized.days}' : '';

      _minutesController.addListener(_onInputChanged);
      _hoursController.addListener(_onInputChanged);
      _daysController.addListener(_onInputChanged);
    }
  }

  CustomRepeatConfig? _buildConfig() {
    final mins = int.tryParse(_minutesController.text.trim()) ?? 0;
    final hrs = int.tryParse(_hoursController.text.trim()) ?? 0;
    final dys = int.tryParse(_daysController.text.trim()) ?? 0;

    if (mins == 0 && hrs == 0 && dys == 0) {
      return null;
    }

    return CustomRepeatConfig(
      minutes: mins,
      hours: hrs,
      days: dys,
      specificDays: _selectedDays.isEmpty ? null : _selectedDays,
      endDate: _endDate,
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
      _validateAndNormalize();
    });
  }

  Future<void> _selectEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)), // 10 years
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _validateAndNormalize();
      });
    }
  }

  void _clearEndDate() {
    setState(() {
      _endDate = null;
      _validateAndNormalize();
    });
  }

  void _save() {
    final config = _buildConfig();

    if (config == null) {
      setState(() {
        _errorMessage = 'Enter at least 5 minutes';
      });
      return;
    }

    if (!config.isValid) {
      setState(() {
        _errorMessage = config.validationError ?? 'Invalid configuration';
      });
      return;
    }

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final config = _buildConfig();
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Custom Repeat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Interval inputs
                    Text(
                      'Repeat every',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            controller: _minutesController,
                            label: 'min',
                            max: 59,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            controller: _hoursController,
                            label: 'hrs',
                            max: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            controller: _daysController,
                            label: 'days',
                            max: 365,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Day selector (always show)
                    Text(
                      'On specific days (optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDayChip('Mon', 1),
                        _buildDayChip('Tue', 2),
                        _buildDayChip('Wed', 3),
                        _buildDayChip('Thu', 4),
                        _buildDayChip('Fri', 5),
                        _buildDayChip('Sat', 6),
                        _buildDayChip('Sun', 7),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // End date
                    Text(
                      'End date (optional)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectEndDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _endDate != null
                                    ? DateFormat('EEEE, MMMM d, y')
                                        .format(_endDate!)
                                    : 'Select date...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _endDate != null
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (_endDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: _clearEndDate,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Summary
                    if (config != null) ...[
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Summary',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: theme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                config.getSummary(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 20,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Hint message
                    if (_hintMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 20,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _hintMessage!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required int max,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _MaxValueInputFormatter(max),
      ],
      decoration: InputDecoration(
        suffixText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int day) {
    final isSelected = _selectedDays.contains(day);
    final theme = Theme.of(context);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _toggleDay(day),
      selectedColor: theme.primaryColor.withOpacity(0.2),
      checkmarkColor: theme.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? theme.primaryColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

/// Input formatter that prevents values greater than max
class _MaxValueInputFormatter extends TextInputFormatter {
  final int max;

  _MaxValueInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(newValue.text);
    if (value == null || value > max) {
      return oldValue;
    }

    return newValue;
  }
}
