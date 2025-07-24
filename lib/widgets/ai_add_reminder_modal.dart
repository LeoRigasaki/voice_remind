// [lib/widgets]/ai_add_reminder_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ai_reminder_service.dart';
import '../screens/settings_screen.dart';

enum ReminderCreationMode { manual, aiText, voice }

class AIAddReminderModal extends StatefulWidget {
  final Reminder? reminder;
  final ReminderCreationMode initialMode;

  const AIAddReminderModal({
    super.key,
    this.reminder,
    this.initialMode = ReminderCreationMode.manual,
  });

  @override
  State<AIAddReminderModal> createState() => _AIAddReminderModalState();
}

class _AIAddReminderModalState extends State<AIAddReminderModal>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  // Current mode
  ReminderCreationMode _currentMode = ReminderCreationMode.manual;

  // Manual form state
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatType _selectedRepeat = RepeatType.none;
  bool _isNotificationEnabled = true;
  bool _isLoading = false;

  // AI Text state
  final _aiInputController = TextEditingController();
  List<Reminder> _aiGeneratedReminders = [];
  Set<int> _selectedReminderIndices = {};
  bool _isGenerating = false;
  bool _showPreview = false;
  String? _aiError;
  double _aiConfidence = 0.0;

  // AI Provider state
  String _currentAIProvider = 'none';
  bool _aiServiceReady = false;

  // Real-time clock
  DateTime _currentTime = DateTime.now();
  Timer? _timeTimer;

  @override
  void initState() {
    super.initState();

    _currentMode = widget.initialMode;

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Initialize tab controller
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _currentMode.index,
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentMode = ReminderCreationMode.values[_tabController.index];
        });
        _animateTabSwitch();
      }
    });

    // Add listener to AI input controller to update button state
    _aiInputController.addListener(() {
      setState(() {
        // This will rebuild the widget when text changes
      });
    });

    // Start real-time timer for current time display
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    // Initialize form if editing
    if (widget.reminder != null) {
      _populateFieldsForEditing();
    } else {
      final now = DateTime.now();
      _selectedTime = TimeOfDay(hour: now.hour + 1, minute: 0);
      _selectedDate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }

    // Load AI service status
    _loadAIServiceStatus();

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });
  }

  Future<void> _loadAIServiceStatus() async {
    try {
      final status = await AIReminderService.getProviderStatus();
      if (mounted) {
        setState(() {
          _currentAIProvider = status['currentProvider'] ?? 'none';
          _aiServiceReady = status['canGenerateReminders'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load AI service status: $e');
    }
  }

  void _populateFieldsForEditing() {
    final reminder = widget.reminder!;
    _titleController.text = reminder.title;
    _descriptionController.text = reminder.description ?? '';
    _selectedDate = reminder.scheduledTime;
    _selectedTime = TimeOfDay.fromDateTime(reminder.scheduledTime);
    _selectedRepeat = reminder.repeatType;
    _isNotificationEnabled = reminder.isNotificationEnabled;
  }

  void _animateTabSwitch() {
    HapticFeedback.lightImpact();
    _scaleController.reset();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _timeTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _aiInputController.dispose();
    super.dispose();
  }

  // Manual form methods
  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDate = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (time != null) {
      setState(() {
        _selectedTime = time;
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _saveManualReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final reminder = Reminder(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scheduledTime: _selectedDate,
        repeatType: _selectedRepeat,
        isNotificationEnabled: _isNotificationEnabled,
      );

      await StorageService.addReminder(reminder);

      if (_isNotificationEnabled && _selectedDate.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(reminder);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Error creating reminder: $e');
      }
    }
  }

  // AI Text methods
  Future<void> _generateReminders() async {
    if (_aiInputController.text.trim().isEmpty) return;

    if (!_aiServiceReady) {
      _showAIConfigurationDialog();
      return;
    }

    setState(() {
      _isGenerating = true;
      _aiError = null;
      _showPreview = false;
    });

    try {
      final response = await AIReminderService.parseRemindersFromText(
        _aiInputController.text.trim(),
      );

      setState(() {
        _aiGeneratedReminders = response.reminders;
        _aiConfidence = response.confidence;
        _selectedReminderIndices = Set.from(
          List.generate(response.reminders.length, (index) => index),
        );
        _showPreview = true;
        _isGenerating = false;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _aiError = e.toString();
        _isGenerating = false;
      });

      // If it's an API key error, show configuration dialog
      if (e.toString().contains('API key') ||
          e.toString().contains('not initialized') ||
          e.toString().contains('not ready')) {
        _showAIConfigurationDialog();
      }
    }
  }

  Future<void> _createSelectedReminders() async {
    if (_selectedReminderIndices.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      for (int index in _selectedReminderIndices) {
        final reminder = _aiGeneratedReminders[index];
        await StorageService.addReminder(reminder);

        if (reminder.isNotificationEnabled &&
            reminder.scheduledTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleReminder(reminder);
        }
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showError('Error creating reminders: $e');
      }
    }
  }

  void _editAIReminder(int index) {
    final reminder = _aiGeneratedReminders[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditReminderSheet(reminder, index),
    );
  }

  Widget _buildEditReminderSheet(Reminder reminder, int index) {
    final titleController = TextEditingController(text: reminder.title);
    final descriptionController =
        TextEditingController(text: reminder.description ?? '');
    DateTime selectedDate = reminder.scheduledTime;
    RepeatType selectedRepeat = reminder.repeatType;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
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
                        'Edit Reminder',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),

                // Edit form
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: const Text('Date & Time'),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy • h:mm a')
                                .format(selectedDate),
                          ),
                          trailing: const Icon(Icons.edit),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime:
                                    TimeOfDay.fromDateTime(selectedDate),
                              );
                              if (time != null) {
                                setModalState(() {
                                  selectedDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),
                      ),
                      Card(
                        child: ListTile(
                          title: const Text('Repeat'),
                          subtitle: Text(_getRepeatDisplayName(selectedRepeat)),
                          trailing: const Icon(Icons.edit),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Container(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Repeat Options',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    for (RepeatType repeat in RepeatType.values)
                                      ListTile(
                                        title:
                                            Text(_getRepeatDisplayName(repeat)),
                                        leading: Radio<RepeatType>(
                                          value: repeat,
                                          groupValue: selectedRepeat,
                                          onChanged: (value) {
                                            setModalState(() {
                                              selectedRepeat = value!;
                                            });
                                            Navigator.pop(context);
                                          },
                                        ),
                                        onTap: () {
                                          setModalState(() {
                                            selectedRepeat = repeat;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final updatedReminder = reminder.copyWith(
                              title: titleController.text.trim(),
                              description:
                                  descriptionController.text.trim().isEmpty
                                      ? null
                                      : descriptionController.text.trim(),
                              scheduledTime: selectedDate,
                              repeatType: selectedRepeat,
                            );

                            setState(() {
                              _aiGeneratedReminders[index] = updatedReminder;
                            });

                            Navigator.pop(context);
                          },
                          child: const Text('Save Changes'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAIConfigurationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI Configuration Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To use AI-powered reminder generation, you need to configure an AI provider first.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✨ Free AI Options:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Google Gemini: 15 requests/minute\n'
                    '• Groq: 14,400 requests/day\n'
                    '• Both are completely free!',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              ).then((_) {
                // Reload AI service status when returning from settings
                _loadAIServiceStatus();
              });
            },
            child: const Text('Configure AI'),
          ),
        ],
      ),
    );
  }

  bool _canGenerateReminders() {
    return !_isGenerating &&
        _aiInputController.text.trim().isNotEmpty &&
        _aiServiceReady;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideController.value) * screenHeight * 0.3),
          child: Container(
            height: screenHeight * 0.95,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: _buildTabContent(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Theme.of(context).colorScheme.onPrimary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: [
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Manual'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _aiServiceReady ? Icons.auto_awesome : Icons.warning_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text('AI Text'),
                if (!_aiServiceReady) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_outlined, size: 18),
                SizedBox(width: 4),
                Text('Voice'),
                SizedBox(width: 4),
                SizedBox(
                  child: Text(
                    'SOON',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildManualTab(),
        _buildAITextTab(),
        _buildVoiceTab(),
      ],
    );
  }

  // ... (Manual tab implementation remains the same as before)
  Widget _buildManualTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Current Time Display
            Container(
              width: double.infinity,
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

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'What do you want to be reminded about?',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Description field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add more details...',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),

                    // Date selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Date'),
                        subtitle: Text(DateFormat('EEEE, MMMM d, y')
                            .format(_selectedDate)),
                        trailing: const Icon(Icons.edit),
                        onTap: _selectDate,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Time selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_outlined),
                        title: const Text('Time'),
                        subtitle: Text(_selectedTime.format(context)),
                        trailing: const Icon(Icons.edit),
                        onTap: _selectTime,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Repeat selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.repeat),
                        title: const Text('Repeat'),
                        subtitle: Text(_getRepeatDisplayName(_selectedRepeat)),
                        trailing: const Icon(Icons.edit),
                        onTap: _showRepeatSelector,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Notification toggle
                    Card(
                      child: SwitchListTile(
                        title: const Text('Enable Notifications'),
                        subtitle: const Text('Get notified when it\'s time'),
                        value: _isNotificationEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isNotificationEnabled = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Create button
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveManualReminder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'CREATE REMINDER',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAITextTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Current Time Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
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
                  decoration: BoxDecoration(
                    color: _aiServiceReady ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI STATUS',
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
                        _aiServiceReady
                            ? '${_currentAIProvider.toUpperCase()} Ready'
                            : 'Not Configured',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                  color: _aiServiceReady
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                      ),
                    ],
                  ),
                ),
                if (!_aiServiceReady)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      ).then((_) => _loadAIServiceStatus());
                    },
                    child: const Text('Setup'),
                  ),
              ],
            ),
          ),

          if (!_showPreview) ...[
            // AI Input section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe your reminders',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _aiServiceReady
                        ? 'Tell me what you need to remember, and I\'ll create smart reminders for you.'
                        : 'Configure an AI provider in Settings to use this feature.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _aiInputController,
                          decoration: InputDecoration(
                            hintText: _aiServiceReady
                                ? 'Example: "Call dentist tomorrow at 10am, buy groceries for Saturday dinner party, and review the budget report by Friday"'
                                : 'Configure AI provider in Settings first...',
                            border: InputBorder.none,
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          enabled: _aiServiceReady,
                        ),
                      ),
                    ),
                  ),
                  if (_aiError != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _aiError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Generate button
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _canGenerateReminders() ? _generateReminders : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canGenerateReminders()
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                    foregroundColor: _canGenerateReminders()
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isGenerating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('GENERATING...'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _aiServiceReady
                                  ? Icons.auto_awesome
                                  : Icons.settings,
                              size: 20,
                              color: _canGenerateReminders()
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _aiServiceReady
                                  ? 'GENERATE REMINDERS'
                                  : 'SETUP AI FIRST',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: _canGenerateReminders()
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ] else
            // Preview section (keeping original implementation)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with confidence
                  Row(
                    children: [
                      Text(
                        'Generated Reminders',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _aiConfidence >= 0.8
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _aiConfidence >= 0.8
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${(_aiConfidence * 100).round()}% confident',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _aiConfidence >= 0.8
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Reminders list
                  Expanded(
                    child: ListView.builder(
                      itemCount: _aiGeneratedReminders.length,
                      itemBuilder: (context, index) {
                        final reminder = _aiGeneratedReminders[index];
                        final isSelected =
                            _selectedReminderIndices.contains(index);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1)
                              : null,
                          child: ListTile(
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedReminderIndices.add(index);
                                  } else {
                                    _selectedReminderIndices.remove(index);
                                  }
                                });
                              },
                            ),
                            title: Text(
                              reminder.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reminder.description != null)
                                  Text(reminder.description!),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM dd • h:mm a')
                                      .format(reminder.scheduledTime),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              onPressed: () => _editAIReminder(index),
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.surface,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedReminderIndices.remove(index);
                                } else {
                                  _selectedReminderIndices.add(index);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        // Back button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _showPreview = false;
                                _aiError = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('EDIT PROMPT'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Create button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                _selectedReminderIndices.isEmpty || _isLoading
                                    ? null
                                    : _createSelectedReminders,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(
                                    'CREATE ${_selectedReminderIndices.length} REMINDER${_selectedReminderIndices.length == 1 ? '' : 'S'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceTab() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 24),
            Text(
              'VOICE REMINDERS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.0,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'COMING SOON',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Voice input for creating reminders\nis currently in development.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRepeatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Repeat Options',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            for (RepeatType repeat in RepeatType.values)
              ListTile(
                title: Text(_getRepeatDisplayName(repeat)),
                subtitle: Text(_getRepeatDescription(repeat)),
                leading: Radio<RepeatType>(
                  value: repeat,
                  groupValue: _selectedRepeat,
                  onChanged: (value) {
                    setState(() {
                      _selectedRepeat = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  setState(() {
                    _selectedRepeat = repeat;
                  });
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getRepeatDisplayName(RepeatType repeat) {
    switch (repeat) {
      case RepeatType.none:
        return 'No Repeat';
      case RepeatType.daily:
        return 'Daily';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
    }
  }

  String _getRepeatDescription(RepeatType repeat) {
    switch (repeat) {
      case RepeatType.none:
        return 'This reminder will only trigger once';
      case RepeatType.daily:
        return 'Repeat every day at the same time';
      case RepeatType.weekly:
        return 'Repeat every week on the same day';
      case RepeatType.monthly:
        return 'Repeat every month on the same date';
    }
  }
}
