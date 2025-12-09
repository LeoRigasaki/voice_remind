// [lib/widgets]/ai_add_reminder_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/voice_service.dart';
import '../models/reminder.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/ai_reminder_service.dart';
import '../services/spaces_service.dart';
import '../utils/reminder_helpers.dart';
import '../screens/settings_screen.dart';
import '../widgets/multi_time_section.dart';
import '../models/space.dart';
import '../models/custom_repeat_config.dart';
import '../widgets/reminder_form/space_selector_field.dart';
import '../widgets/reminder_form/custom_repeat_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

enum ReminderCreationMode { manual, aiText, voice }

// Voice conversation states inspired by leading assistants
enum VoiceConversationState { idle, listening, thinking, speaking }

class AIAddReminderModal extends StatefulWidget {
  final Reminder? reminder;
  final ReminderCreationMode initialMode;
  final Space? preSelectedSpace;

  const AIAddReminderModal({
    super.key,
    this.reminder,
    this.initialMode = ReminderCreationMode.manual,
    this.preSelectedSpace,
  });

  @override
  State<AIAddReminderModal> createState() => _AIAddReminderModalState();
}

class _AIAddReminderModalState extends State<AIAddReminderModal>
    with TickerProviderStateMixin {
  TabController? _tabController;
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
  CustomRepeatConfig? _customRepeatConfig;
  bool _isNotificationEnabled = true;
  bool _isLoading = false;

  // Multi-time state
  bool _isMultiTime = false;
  List<TimeSlot> _timeSlots = [];

  // Space state
  Space? _selectedSpace;
  List<Space> _availableSpaces = [];

  StreamSubscription<VoiceState>? _voiceStateSubscription;
  StreamSubscription<String>? _voiceTranscriptionSubscription;
  StreamSubscription<List<Reminder>>? _voiceResultsSubscription;

  List<Reminder> _voiceGeneratedReminders = [];
  bool _showVoicePreview = false;
  String? _voiceError;
  String _voiceTranscription = '';
  // AI Text state
  final _aiInputController = TextEditingController();
  List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
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

  // ===== Enhanced Voice UI state =====
  VoiceConversationState _voiceState = VoiceConversationState.idle;

  // Animation controllers for orb/waveform
  late AnimationController _orbPulseController; // base pulsing
  late AnimationController _ringController; // concentric rings
  late AnimationController _waveformController; // bar jitter

  // Derived animations
  late Animation<double> _pulse; // 0..1
  late Animation<double> _rings; // 0..1

  // Enhanced audio level simulation with frequency bands
  double _audioLevel = 0.0;
  final List<double> _frequencyBands =
      List.filled(21, 0.0); // For individual bar reactivity
  Timer? _audioMockTimer;

  @override
  void initState() {
    super.initState();
    // Set pre-selected space immediately (synchronously) before async initialization
    if (widget.preSelectedSpace != null) {
      _selectedSpace = widget.preSelectedSpace;
      debugPrint(
          '🎯 Pre-selected space set in initState: ${_selectedSpace?.name}');
    }
    _initializeModal();
  }

  Future<void> _initializeModal() async {
    // Initialize voice service
    _initializeVoiceService();

    // Initialize animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // Slower, more natural pulse for breathing effect
    _orbPulseController = AnimationController(
      duration: const Duration(milliseconds: 2400), // Slower breathing
      vsync: this,
    )..repeat(reverse: true);

    // Consistent rhythm for ripples - each ring spawns every 800ms
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 2400), // 3 rings × 800ms each
      vsync: this,
    )..repeat();

    // Voice-reactive waveform animation
    _waveformController = AnimationController(
      duration:
          const Duration(milliseconds: 150), // Faster for voice reactivity
      vsync: this,
    )..repeat();

    _pulse = CurvedAnimation(
      parent: _orbPulseController,
      curve: Curves.easeInOut,
    );
    _rings = CurvedAnimation(
      parent: _ringController,
      curve: Curves.linear,
    );

    await _loadAIServiceStatus();
    await _loadDefaultTabPreference();
    await _loadSpaces();
    await _initializeTabs();

    // Add listener to AI input controller to update button state
    _aiInputController.addListener(() {
      setState(() {});
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

    // Start entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
    });

    // Start enhanced mock audio with frequency bands
    _beginEnhancedMockAudio();
  }

  Future<void> _loadAIServiceStatus() async {
    try {
      // First check storage directly for selected provider
      final selectedProvider = await StorageService.getSelectedAIProvider();
      final isProviderNone =
          selectedProvider == null || selectedProvider == 'none';

      if (isProviderNone) {
        // If no provider selected, immediately set AI as not ready
        if (mounted) {
          final wasReady = _aiServiceReady;
          setState(() {
            _currentAIProvider = 'none';
            _aiServiceReady = false;
          });

          if (wasReady != _aiServiceReady) {
            await _initializeTabs();
          }
        }
        return;
      }

      // Only check service status if provider is selected
      final status = await AIReminderService.getProviderStatus();
      if (mounted) {
        final wasReady = _aiServiceReady;
        setState(() {
          _currentAIProvider = status['currentProvider'] ?? 'none';
          _aiServiceReady =
              (status['canGenerateReminders'] ?? false) && !isProviderNone;
        });

        if (wasReady != _aiServiceReady) {
          await _initializeTabs();
        }
      }
    } catch (e) {
      debugPrint('Failed to load AI service status: $e');
      if (mounted) {
        setState(() {
          _currentAIProvider = 'none';
          _aiServiceReady = false;
        });
        await _initializeTabs();
      }
    }
  }

  Future<void> _initializeTabs() async {
    debugPrint(
        '🔧 Initializing tabs - AI ready: $_aiServiceReady, provider: $_currentAIProvider');

    if (_tabController != null) {
      _tabController!.dispose();
    }

    // Always create 3 tabs for discoverability
    _tabController = TabController(
      length: 3,
      vsync: this,
      // Use current mode for initial index, but constrain to manual if AI not ready
      initialIndex: _aiServiceReady ? _modeToIndex(_currentMode) : 0,
    );

    _tabController!.addListener(() {
      if (!_tabController!.indexIsChanging) {
        final newIndex = _tabController!.index;
        final previousMode = _currentMode;

        // If user clicks AI tabs but no provider configured, show setup dialog
        if (!_aiServiceReady && newIndex > 0) {
          _showAIConfigurationDialog();
          // Revert to manual tab
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabController!.animateTo(0);
          });
          return;
        }

        // Unfocus any active text fields when switching away from AI Text tab
        if (previousMode == ReminderCreationMode.aiText && newIndex != 1) {
          _aiInputController.clearComposing();
          FocusScope.of(context).unfocus();
        }

        // Normal tab switching for configured users
        setState(() {
          _currentMode = ReminderCreationMode.values[newIndex];
        });
        _animateTabSwitch();
      }
    });
  }

  Future<void> _loadDefaultTabPreference() async {
    try {
      final defaultTabIndex = await StorageService.getDefaultReminderTab();
      final defaultMode = _indexToMode(defaultTabIndex);

      // Only use preference if no explicit initialMode was provided
      if (widget.initialMode == ReminderCreationMode.manual) {
        setState(() {
          _currentMode = defaultMode;
        });
      }
    } catch (e) {
      debugPrint('Failed to load default tab preference: $e');
    }
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpacesService.getSpaces();
      if (mounted) {
        setState(() {
          _availableSpaces = spaces;
          // Pre-select space if provided and not already set
          if (widget.preSelectedSpace != null && _selectedSpace == null) {
            _selectedSpace = widget.preSelectedSpace;
            debugPrint(
                '📍 Pre-selected space in loadSpaces: ${_selectedSpace?.name}');
          }
          debugPrint(
              '✅ Spaces loaded: ${_availableSpaces.length} spaces, selected: ${_selectedSpace?.name ?? "none"}');
        });
      }
    } catch (e) {
      debugPrint('Error loading spaces: $e');
    }
  }

  void _onSingleTimeChanged(TimeOfDay newTime) {
    setState(() {
      _selectedTime = newTime;
      // Update selected date to preserve the date but use new time
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        newTime.hour,
        newTime.minute,
      );
    });
  }

  Future<void> _initializeVoiceService() async {
    try {
      await VoiceService.initialize();

      // Subscribe to voice service streams
      _voiceStateSubscription =
          VoiceService.instance.stateStream.listen(_onVoiceStateChanged);
      _voiceTranscriptionSubscription = VoiceService
          .instance.transcriptionStream
          .listen(_onVoiceTranscription);
      _voiceResultsSubscription =
          VoiceService.instance.resultsStream.listen(_onVoiceResults);

      debugPrint('✅ Voice service initialized in modal');
    } catch (e) {
      debugPrint('❌ Voice service initialization failed: $e');
      setState(() {
        _voiceError = 'Voice service not available: ${e.toString()}';
      });
    }
  }

  void _onVoiceStateChanged(VoiceState state) {
    // Map VoiceService states to your existing UI states
    setState(() {
      _voiceState = switch (state) {
        VoiceState.idle => VoiceConversationState.idle,
        VoiceState.recording => VoiceConversationState.listening,
        VoiceState.processing => VoiceConversationState.thinking,
        VoiceState.completed => VoiceConversationState.idle,
        VoiceState.error => VoiceConversationState.idle,
      };

      if (state == VoiceState.error) {
        _voiceError = 'Voice processing failed. Please try again.';
      } else if (state == VoiceState.completed) {
        _voiceError = null;
      }
    });
  }

  void _onVoiceTranscription(String transcription) {
    setState(() {
      _voiceTranscription = transcription;
    });
  }

  void _onVoiceResults(List<Reminder> reminders) {
    setState(() {
      _voiceGeneratedReminders = reminders;
      _showVoicePreview = reminders.isNotEmpty;
      // Select all generated reminders by default
      _selectedReminderIndices = Set.from(
        List.generate(reminders.length, (index) => index),
      );
    });
  }

  void _populateFieldsForEditing() {
    final reminder = widget.reminder!;
    _titleController.text = reminder.title;
    _descriptionController.text = reminder.description ?? '';
    _selectedDate = reminder.scheduledTime;
    _selectedTime = TimeOfDay.fromDateTime(reminder.scheduledTime);
    _selectedRepeat = reminder.repeatType;
    _isNotificationEnabled = reminder.isNotificationEnabled;

    // Handle multi-time reminder editing
    if (reminder.hasMultipleTimes) {
      _isMultiTime = true;
      _timeSlots = [...reminder.timeSlots];
    }
  }

  void _animateTabSwitch() {
    HapticFeedback.lightImpact();
    _scaleController.reset();
    _scaleController.forward();
  }

  ReminderCreationMode _indexToMode(int index) {
    switch (index) {
      case 0:
        return ReminderCreationMode.manual;
      case 1:
        return ReminderCreationMode.aiText;
      case 2:
        return ReminderCreationMode.voice;
      default:
        return ReminderCreationMode.manual;
    }
  }

  int _modeToIndex(ReminderCreationMode mode) {
    switch (mode) {
      case ReminderCreationMode.manual:
        return 0;
      case ReminderCreationMode.aiText:
        return 1;
      case ReminderCreationMode.voice:
        return 2;
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _timeTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _aiInputController.dispose();
    _orbPulseController.dispose();
    _ringController.dispose();
    _waveformController.dispose();
    _audioMockTimer?.cancel();
    _voiceStateSubscription?.cancel();
    _voiceTranscriptionSubscription?.cancel();
    _voiceResultsSubscription?.cancel();
    super.dispose();
  }

  // Manual form methods
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate.isBefore(now) ? now : _selectedDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
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

  void _onMultiTimeToggle(bool isMultiTime) {
    setState(() {
      _isMultiTime = isMultiTime;
      if (!isMultiTime) {
        _timeSlots.clear();
      }
    });
  }

  void _onTimeSlotsChanged(List<TimeSlot> timeSlots) {
    setState(() {
      _timeSlots = timeSlots;
    });
  }

  Future<void> _saveManualReminder() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate multi-time setup
    if (_isMultiTime && _timeSlots.isEmpty) {
      _showError(
          'Please add at least one time slot or switch to single time mode');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Reminder reminder;

      if (_isMultiTime) {
        // Create multi-time reminder
        reminder = Reminder(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          scheduledTime: _selectedDate, // Keep for backward compatibility
          repeatType: _selectedRepeat,
          isNotificationEnabled: _isNotificationEnabled,
          spaceId: _selectedSpace?.id,
          timeSlots: _timeSlots,
          isMultiTime: true,
          customRepeatConfig: _customRepeatConfig,
        );
      } else {
        // Create single-time reminder
        reminder = Reminder(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          scheduledTime: _selectedDate,
          repeatType: _selectedRepeat,
          isNotificationEnabled: _isNotificationEnabled,
          spaceId: _selectedSpace?.id,
          timeSlots: [],
          isMultiTime: false,
          customRepeatConfig: _customRepeatConfig,
        );
      }

      debugPrint(
          '💾 Saving manual reminder with space: ${_selectedSpace?.name ?? "none"} (ID: ${_selectedSpace?.id})');

      await StorageService.addReminder(reminder);

      if (_isNotificationEnabled) {
        if (_isMultiTime) {
          // Schedule notifications for pending time slots
          final now = DateTime.now();
          for (final timeSlot in _timeSlots) {
            if (timeSlot.status == ReminderStatus.pending) {
              final notificationTime = DateTime(
                now.year,
                now.month,
                now.day,
                timeSlot.time.hour,
                timeSlot.time.minute,
              );

              if (notificationTime.isAfter(now)) {
                await NotificationService.scheduleReminder(reminder);
              }
            }
          }
        } else {
          // Schedule single notification
          if (_selectedDate.isAfter(DateTime.now())) {
            await NotificationService.scheduleReminder(reminder);
          }
        }
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

  // AI Text methods (enhanced for multi-time support)
  Future<void> _generateReminders() async {
    // Check if we have either text or images
    if (_aiInputController.text.trim().isEmpty && _selectedImages.isEmpty) {
      _showError('Please enter text or select images');
      return;
    }

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
      List<Reminder> allReminders = [];
      double totalConfidence = 0.0;

      // Image mode: process all images in a single context
      if (_selectedImages.isNotEmpty) {
        final customPrompt = _aiInputController.text.trim();

        // Read all images into a list
        final imageBytesList = await Future.wait(
          _selectedImages.map((image) => image.readAsBytes()),
        );

        // Send all images in a single context so AI can analyze them together
        final response = await AIReminderService.parseRemindersFromImage(
          imageBytesList: imageBytesList,
          customPrompt: customPrompt.isEmpty ? null : customPrompt,
        );

        allReminders = response.reminders;
        totalConfidence = response.confidence;
      }
      // Text mode: use text parsing
      else {
        final response = await AIReminderService.parseRemindersFromText(
          _aiInputController.text.trim(),
        );
        allReminders = response.reminders;
        totalConfidence = response.confidence;
      }

      setState(() {
        _aiGeneratedReminders = allReminders;
        _aiConfidence = totalConfidence;
        _selectedReminderIndices = Set.from(
          List.generate(allReminders.length, (index) => index),
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

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        // Limit to 5 images maximum
        final imagesToAdd =
            images.take(5).map((xfile) => File(xfile.path)).toList();

        setState(() {
          _selectedImages = imagesToAdd;
          _showPreview = false;
        });

        if (images.length > 5) {
          _showError('Only the first 5 images were selected (maximum limit)');
        }
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          // Add to existing images if less than 5, otherwise replace all
          if (_selectedImages.length < 5) {
            _selectedImages = [..._selectedImages, File(image.path)];
          } else {
            _selectedImages = [File(image.path)];
            _showError('Maximum 5 images allowed. Previous images cleared.');
          }
          _showPreview = false;
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages = List.from(_selectedImages)..removeAt(index);
      if (_selectedImages.isEmpty) {
        _showPreview = false;
      }
    });
  }

  Future<void> _createSelectedReminders() async {
    if (_selectedReminderIndices.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      for (int index in _selectedReminderIndices) {
        final generatedReminder = _aiGeneratedReminders[index];

        // Add pre-selected space to AI-generated reminder
        final reminder = generatedReminder.copyWith(
          spaceId: _selectedSpace?.id,
        );

        debugPrint(
            '💾 Saving AI reminder with space: ${_selectedSpace?.name ?? "none"}');

        await StorageService.addReminder(reminder);

        if (reminder.isNotificationEnabled) {
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
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => _EditReminderSheet(
        reminder: reminder,
        index: index,
        onSave: (updatedReminder) {
          setState(() {
            if (_currentMode == ReminderCreationMode.voice) {
              _voiceGeneratedReminders[index] = updatedReminder;
            } else {
              _aiGeneratedReminders[index] = updatedReminder;
            }
          });
        },
      ),
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
        (_aiInputController.text.trim().isNotEmpty ||
            _selectedImages.isNotEmpty) &&
        _aiServiceReady;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                  child: _buildTabContent(),
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
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: _tabController == null
          ? const SizedBox.shrink()
          : TabBar(
              controller: _tabController!,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              labelPadding: EdgeInsets.zero,
              tabs: [
                // Manual Tab (always enabled)
                const SizedBox(
                  width: double.infinity,
                  child: Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('Manual'),
                      ],
                    ),
                  ),
                ),

                // AI Text Tab (show lock if disabled)
                SizedBox(
                  width: double.infinity,
                  child: Tab(
                    child: Opacity(
                      opacity: _aiServiceReady ? 1.0 : 0.6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _aiServiceReady
                                ? Icons.auto_awesome
                                : Icons.lock_outlined,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text('AI Text'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Voice Tab (show lock if disabled)
                SizedBox(
                  width: double.infinity,
                  child: Tab(
                    child: Opacity(
                      opacity: _aiServiceReady ? 1.0 : 0.6,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _aiServiceReady
                                ? Icons.mic_outlined
                                : Icons.lock_outlined,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          const Text('Voice'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabContent() {
    return _tabController == null
        ? const SizedBox.shrink()
        : TabBarView(
            controller: _tabController!,
            children: [
              _buildManualTab(),
              _buildAITextTab(),
              _buildVoiceTab(),
            ],
          );
  }

  Widget _buildManualTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Current Time Display (unchanged)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
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

                    const SizedBox(height: 24),

                    // Multi-time section
                    MultiTimeSection(
                      timeSlots: _timeSlots,
                      onTimeSlotsChanged: _onTimeSlotsChanged,
                      isMultiTime: _isMultiTime,
                      onMultiTimeToggle: _onMultiTimeToggle,
                      initialSingleTime: _selectedTime,
                      onSingleTimeChanged: _onSingleTimeChanged,
                      singleTimeLabel: 'Time',
                      padding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 24),

                    // Date selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(_isMultiTime ? 'Base Date' : 'Date'),
                        subtitle: Text(
                          _isMultiTime
                              ? '${DateFormat('EEEE, MMMM d, y').format(_selectedDate)} (for all times)'
                              : DateFormat('EEEE, MMMM d, y')
                                  .format(_selectedDate),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: _selectDate,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Repeat selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.repeat),
                        title: const Text('Repeat'),
                        subtitle: Text(
                          _selectedRepeat == RepeatType.custom &&
                                  _customRepeatConfig != null
                              ? _customRepeatConfig!.formatInterval()
                              : getRepeatDisplayName(_selectedRepeat),
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: _showRepeatSelector,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Space selector
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: SpaceSelectorField(
                          selectedSpace: _selectedSpace,
                          availableSpaces: _availableSpaces,
                          onSpaceChanged: (space) {
                            setState(() {
                              _selectedSpace = space;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

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

            // Create button (unchanged)
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
                      : Text(
                          _isMultiTime
                              ? 'CREATE MULTI-TIME REMINDER'
                              : 'CREATE REMINDER',
                          style: const TextStyle(
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (!_showPreview) ...[
            // AI STATUS TAG
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _aiServiceReady
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _aiServiceReady
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _aiServiceReady ? Colors.green : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _aiServiceReady
                            ? _currentAIProvider.toUpperCase()
                            : 'SETUP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _aiServiceReady ? Colors.green : Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (!_aiServiceReady) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            ).then((_) {
                              if (mounted) {
                                _loadAIServiceStatus();
                              }
                            });
                          },
                          child: const Icon(Icons.arrow_forward_ios,
                              size: 12, color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: MediaQuery.of(context).size.height * 0.02),

            // IMAGE PICKER BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _pickImageFromGallery,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label:
                        const Text('Gallery', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isGenerating ? null : _pickImageFromCamera,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),

            // IMAGE PREVIEW - Multiple images in horizontal scroll
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < _selectedImages.length - 1 ? 8 : 0,
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImages[index],
                              height: 120,
                              width: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 12),
                                onPressed: () => _removeImage(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                          // Image number badge
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}/${_selectedImages.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            SizedBox(height: MediaQuery.of(context).size.height * 0.015),

            // TEXT INPUT
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              child: TextField(
                controller: _aiInputController,
                enabled: _aiServiceReady,
                minLines: 3,
                maxLines: 8,
                textAlignVertical: TextAlignVertical.top,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.5, fontSize: 16),
                decoration: InputDecoration(
                  hintText: _selectedImages.isNotEmpty
                      ? 'Optional: Add custom instructions...\n\nExample: "Extract only meetings" or leave empty for automatic analysis'
                      : _aiServiceReady
                          ? 'Describe your reminders here...\n\nExample: Take medicine at 8AM, 2PM, and 8PM daily'
                          : 'Configure AI provider in Settings first...',
                  hintStyle: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                    fontSize: 16,
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            // UNDERLINE
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.0),
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.6),
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),

            SizedBox(height: MediaQuery.of(context).size.height * 0.015),

            // ERROR
            if (_aiError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error generating reminders. Please try again.',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // GENERATE BUTTON
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _canGenerateReminders()
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                color: !_canGenerateReminders()
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _canGenerateReminders() ? _generateReminders : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: _isGenerating
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedImages.isNotEmpty
                                    ? 'ANALYZING...'
                                    : 'GENERATING...',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedImages.isNotEmpty
                                    ? Icons.image_search
                                    : _aiServiceReady
                                        ? Icons.auto_awesome
                                        : Icons.settings_outlined,
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
                                _selectedImages.isNotEmpty
                                    ? (_selectedImages.length > 1
                                        ? 'ANALYZE ${_selectedImages.length} IMAGES'
                                        : 'ANALYZE SCREENSHOT')
                                    : _aiServiceReady
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
            ),
          ] else
            // PREVIEW (unchanged)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Generated Reminders',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                            title: Text(reminder.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reminder.description != null)
                                  Text(reminder.description!),
                                const SizedBox(height: 4),
                                if (reminder.hasMultipleTimes) ...[
                                  Text(
                                    '${reminder.timeSlots.length} times: ${reminder.timeSlots.map((slot) => slot.formattedTime).join(', ')}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ] else ...[
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
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
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
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('EDIT PROMPT',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'CREATE ${_selectedReminderIndices.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show preview if we have voice results (similar to AI text preview)
    if (_showVoicePreview && _voiceGeneratedReminders.isNotEmpty) {
      return _buildVoicePreview();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Status chip with AI provider info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // AI Status chip (like AI text tab)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _aiServiceReady
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _aiServiceReady
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _aiServiceReady ? Icons.smart_toy : Icons.warning_rounded,
                      size: 14,
                      color: _aiServiceReady ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _aiServiceReady
                          ? _currentAIProvider.toUpperCase()
                          : 'NO AI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _aiServiceReady ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              // Your existing voice status chip
              _VoiceStatusChip(state: _voiceState),
            ],
          ),

          const SizedBox(height: 12),

          // Show transcription if available
          if (_voiceTranscription.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I heard:',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"$_voiceTranscription"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ],

          // Show error if any
          if (_voiceError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _voiceError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Your existing beautiful voice UI (keep everything the same!)
          Expanded(
            child: Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Your existing natural rhythm concentric ripples
                    AnimatedBuilder(
                      animation: _ringController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _NaturalRhythmRingsPainter(
                            progress: _rings.value,
                            primaryColor: Theme.of(context).colorScheme.primary,
                            baseOpacity: isDark ? 0.25 : 0.15,
                            state: _voiceState,
                          ),
                          size: const Size(260, 260),
                        );
                      },
                    ),

                    // Your existing main glowing orb
                    AnimatedBuilder(
                      animation: Listenable.merge(
                        [_orbPulseController, _waveformController],
                      ),
                      builder: (context, _) {
                        final p = _pulse.value;
                        final scale = 1.0 + 0.04 * p + 0.15 * _audioLevel;
                        return Transform.scale(
                          scale: scale,
                          child: _AppAlignedGlowingOrb(
                            diameter: 200,
                            primaryColor: Theme.of(context).colorScheme.primary,
                            glowOpacity: isDark ? 0.40 : 0.30,
                            innerStop: 0.55,
                            outerStop: 1.0,
                            state: _voiceState,
                          ),
                        );
                      },
                    ),

                    // Your existing voice-reactive waveform
                    Positioned(
                      bottom: 44,
                      left: 36,
                      right: 36,
                      child: AnimatedBuilder(
                        animation: _waveformController,
                        builder: (context, _) {
                          return _VoiceReactiveWaveform(
                            level: _audioLevel,
                            frequencyBands: _frequencyBands,
                            t: _waveformController.value,
                            barCount: 21,
                            color: Theme.of(context).colorScheme.onPrimary,
                            dimColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.25),
                            isActive: _voiceState ==
                                    VoiceConversationState.listening ||
                                _voiceState == VoiceConversationState.speaking,
                          );
                        },
                      ),
                    ),

                    // Your existing center icon/state text
                    Positioned(
                      bottom: 12,
                      child: Opacity(
                        opacity: 0.9,
                        child: Column(
                          children: [
                            Text(
                              _getVoiceStatusText(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          GestureDetector(
            onLongPressStart: (_) => _startListening(),
            onLongPressEnd: (_) => _stopListening(),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _aiServiceReady
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.85),
                        ],
                      )
                    : null,
                color: !_aiServiceReady
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2)
                    : null,
                boxShadow: _aiServiceReady
                    ? [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _aiServiceReady ? Icons.mic : Icons.settings_outlined,
                      size: 20,
                      color: _aiServiceReady
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _aiServiceReady
                          ? 'PRESS & HOLD TO SPEAK'
                          : 'CONFIGURE AI FIRST',
                      style: TextStyle(
                        color: _aiServiceReady
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Updated helper text
          Text(
            _aiServiceReady
                ? 'While holding, speak naturally. Release to process. Your voice will be processed by ${_currentAIProvider.toUpperCase()}.'
                : 'Configure an AI provider in Settings to enable voice features.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  // Voice status text method
  String _getVoiceStatusText() {
    switch (_voiceState) {
      case VoiceConversationState.idle:
        return _aiServiceReady ? 'Hold to talk' : 'Setup AI first';
      case VoiceConversationState.listening:
        return 'Listening…';
      case VoiceConversationState.thinking:
        return 'Processing…';
      case VoiceConversationState.speaking:
        return 'Generating…';
    }
  }

  Widget _buildVoicePreview() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Voice Reminders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${_voiceGeneratedReminders.length} found',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),

          // Show transcription
          if (_voiceTranscription.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'From: "$_voiceTranscription"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Reminders list (reuse your existing AI preview logic)
          Expanded(
            child: ListView.builder(
              itemCount: _voiceGeneratedReminders.length,
              itemBuilder: (context, index) {
                final reminder = _voiceGeneratedReminders[index];
                final isSelected = _selectedReminderIndices.contains(index);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.surface,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reminder.description != null) ...[
                          Text(reminder.description!),
                          const SizedBox(height: 4),
                        ],
                        // Show timing info
                        if (reminder.hasMultipleTimes) ...[
                          Text(
                            '${reminder.timeSlots.length} times: ${reminder.timeSlots.map((slot) => slot.formattedTime).join(', ')}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          Text(
                            DateFormat('MMM dd • h:mm a')
                                .format(reminder.scheduledTime),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      onPressed: () => _editVoiceReminder(index),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
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
                // Try again button
                // Try again button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showVoicePreview = false;
                        _voiceGeneratedReminders.clear();
                        _selectedReminderIndices.clear();
                        _voiceTranscription = '';
                      });
                      VoiceService.instance.resetState();
                    },
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('TRY AGAIN', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Create reminders button
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedReminderIndices.isEmpty || _isLoading
                        ? null
                        : () async {
                            // Copy voice results to AI reminders for creation
                            setState(() {
                              _aiGeneratedReminders = _voiceGeneratedReminders;
                            });
                            await _createSelectedReminders();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'CREATE ${_selectedReminderIndices.length}',
                              style: const TextStyle(
                                fontSize: 12,
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
        ],
      ),
    );
  }

  void _startListening() async {
    if (!_aiServiceReady) {
      _showAIConfigurationDialog();
      return;
    }

    try {
      HapticFeedback.mediumImpact();

      // Clear previous results
      VoiceService.instance.resetState();
      setState(() {
        _showVoicePreview = false;
        _voiceError = null;
        _voiceTranscription = '';
        _voiceGeneratedReminders.clear();
        _voiceState =
            VoiceConversationState.listening; // Start your UI animation
      });

      // Start real voice recording
      await VoiceService.instance.startRecording();
    } catch (e) {
      setState(() {
        _voiceError = e.toString();
        _voiceState = VoiceConversationState.idle;
      });
    }
  }

  void _stopListening() async {
    try {
      HapticFeedback.selectionClick();
      setState(() => _voiceState = VoiceConversationState.thinking);

      // Stop real voice recording and process
      await VoiceService.instance.stopRecording();
    } catch (e) {
      setState(() {
        _voiceError = e.toString();
        _voiceState = VoiceConversationState.idle;
      });
    }
  }

  void _beginEnhancedMockAudio() {
    final start = DateTime.now();
    _audioMockTimer =
        Timer.periodic(const Duration(milliseconds: 50), (Timer t) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;

      // Base audio level with more natural variation
      double base = 0.08 +
          0.04 * math.sin(elapsed * 1.3) +
          0.03 * math.sin(elapsed * 3.7);

      // State-dependent audio level
      switch (_voiceState) {
        case VoiceConversationState.idle:
          _audioLevel = base * 0.6;
          break;
        case VoiceConversationState.listening:
          _audioLevel =
              (base + 0.35 + 0.30 * math.sin(elapsed * 4.8)).clamp(0.0, 1.0);
          break;
        case VoiceConversationState.thinking:
          _audioLevel = base * 0.4;
          break;
        case VoiceConversationState.speaking:
          _audioLevel =
              (base + 0.25 + 0.25 * math.sin(elapsed * 5.4)).clamp(0.0, 1.0);
          break;
      }

      // Generate individual frequency bands for voice-reactive waveform
      for (int i = 0; i < _frequencyBands.length; i++) {
        final freq = 0.5 + i * 0.8; // Different frequency for each band
        final bandBase = 0.05 + 0.15 * math.sin(elapsed * freq + i * 0.3);

        switch (_voiceState) {
          case VoiceConversationState.idle:
            _frequencyBands[i] = bandBase * 0.4;
            break;
          case VoiceConversationState.listening:
            // Higher reactivity during listening
            _frequencyBands[i] = (bandBase +
                    0.4 *
                        _audioLevel *
                        math.sin(elapsed * (freq * 1.5) + i * 0.2))
                .clamp(0.0, 1.0);
            break;
          case VoiceConversationState.thinking:
            _frequencyBands[i] = bandBase * 0.3;
            break;
          case VoiceConversationState.speaking:
            // Voice-like pattern during speaking
            _frequencyBands[i] = (bandBase +
                    0.3 *
                        _audioLevel *
                        math.sin(elapsed * (freq * 2.0) + i * 0.4))
                .clamp(0.0, 1.0);
            break;
        }
      }

      setState(() {});
    });
  }

  // ==================== Bottom sheets & helpers ====================

  void _showRepeatSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Get screen dimensions for responsive design
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

        // Calculate available height
        final availableHeight = screenHeight -
            MediaQuery.of(context).padding.top -
            MediaQuery.of(context).padding.bottom -
            keyboardHeight -
            32; // margins

        // Determine device size categories
        final isSmallDevice = screenHeight < 700;
        final isVerySmallDevice = screenHeight < 600;

        // Calculate responsive dimensions
        final maxModalHeight = isVerySmallDevice
            ? availableHeight * 0.85
            : isSmallDevice
                ? availableHeight * 0.75
                : availableHeight * 0.6;

        final horizontalMargin = isSmallDevice ? 12.0 : 16.0;
        final verticalPadding = isVerySmallDevice
            ? 12.0
            : isSmallDevice
                ? 16.0
                : 20.0;

        return Container(
          margin: EdgeInsets.only(
            left: horizontalMargin,
            right: horizontalMargin,
            top: 16,
            bottom: 16 + keyboardHeight,
          ),
          constraints: BoxConstraints(
            maxHeight: maxModalHeight,
            minHeight: 200,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Padding(
                padding: EdgeInsets.all(verticalPadding),
                child: Text(
                  'Repeat Options',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (RepeatType repeat in RepeatType.values)
                        ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: isVerySmallDevice ? 4.0 : 8.0,
                          ),
                          title: Text(
                            getRepeatDisplayName(repeat),
                            style: TextStyle(
                              fontSize: isVerySmallDevice
                                  ? 14.0
                                  : isSmallDevice
                                      ? 15.0
                                      : 16.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            getRepeatDescription(repeat),
                            style: TextStyle(
                              fontSize: isVerySmallDevice
                                  ? 11.0
                                  : isSmallDevice
                                      ? 12.0
                                      : 13.0,
                              height: isVerySmallDevice ? 1.3 : 1.4,
                            ),
                            maxLines: isVerySmallDevice ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Radio<RepeatType>(
                            value: repeat,
                            groupValue: _selectedRepeat,
                            onChanged: (value) async {
                              if (value == RepeatType.custom) {
                                Navigator.pop(context);
                                final config =
                                    await showDialog<CustomRepeatConfig>(
                                  context: context,
                                  builder: (context) => CustomRepeatDialog(
                                    initialConfig: _customRepeatConfig,
                                  ),
                                );
                                if (config != null) {
                                  setState(() {
                                    _selectedRepeat = RepeatType.custom;
                                    _customRepeatConfig = config;
                                  });
                                }
                              } else {
                                setState(() {
                                  _selectedRepeat = value!;
                                  _customRepeatConfig = null;
                                });
                                Navigator.pop(context);
                              }
                            },
                          ),
                          onTap: () async {
                            if (repeat == RepeatType.custom) {
                              Navigator.pop(context);
                              final config =
                                  await showDialog<CustomRepeatConfig>(
                                context: context,
                                builder: (context) => CustomRepeatDialog(
                                  initialConfig: _customRepeatConfig,
                                ),
                              );
                              if (config != null) {
                                setState(() {
                                  _selectedRepeat = RepeatType.custom;
                                  _customRepeatConfig = config;
                                });
                              }
                            } else {
                              setState(() {
                                _selectedRepeat = repeat;
                                _customRepeatConfig = null;
                              });
                              Navigator.pop(context);
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isVerySmallDevice ? 10 : 20),
            ],
          ),
        );
      },
    );
  }

  void _editVoiceReminder(int index) {
    final reminder = _voiceGeneratedReminders[index];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) => _EditReminderSheet(
        reminder: reminder,
        index: index,
        onSave: (updatedReminder) {
          setState(() {
            _voiceGeneratedReminders[index] = updatedReminder;
          });
        },
      ),
    );
  }
}

// ==================== ENHANCED Voice UI helper widgets ====================

class _VoiceStatusChip extends StatelessWidget {
  final VoiceConversationState state;
  const _VoiceStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    // Use app-aligned colors instead of hardcoded ones
    final (label, color) = switch (state) {
      VoiceConversationState.idle => (
          'IDLE',
          Theme.of(context).colorScheme.outline
        ),
      VoiceConversationState.listening => (
          'LISTENING',
          Theme.of(context).colorScheme.primary
        ),
      VoiceConversationState.thinking => (
          'THINKING',
          Theme.of(context).colorScheme.secondary
        ),
      VoiceConversationState.speaking => (
          'SPEAKING',
          Theme.of(context).colorScheme.tertiary
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// App-aligned glowing orb with theme colors
class _AppAlignedGlowingOrb extends StatelessWidget {
  final double diameter;
  final Color primaryColor;
  final double glowOpacity;
  final double innerStop;
  final double outerStop;
  final VoiceConversationState state;

  const _AppAlignedGlowingOrb({
    required this.diameter,
    required this.primaryColor,
    required this.glowOpacity,
    required this.innerStop,
    required this.outerStop,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    // Use app theme colors with different variations for each state
    final base = primaryColor;
    final accent = switch (state) {
      VoiceConversationState.idle => base.withValues(alpha: 0.7),
      VoiceConversationState.listening => HSLColor.fromColor(base)
          .withLightness(0.7)
          .toColor()
          .withValues(alpha: 0.8),
      VoiceConversationState.thinking =>
        Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
      VoiceConversationState.speaking =>
        Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
    };

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent,
            base,
          ],
          stops: [innerStop, outerStop],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: glowOpacity),
            blurRadius: 48,
            spreadRadius: 6,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
    );
  }
}

// Natural rhythm rings painter with sequential appearance
class _NaturalRhythmRingsPainter extends CustomPainter {
  final double progress; // 0..1
  final Color primaryColor;
  final double baseOpacity;
  final VoiceConversationState state;

  _NaturalRhythmRingsPainter({
    required this.progress,
    required this.primaryColor,
    required this.baseOpacity,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Natural rhythm - each ring appears every 0.33 of the cycle
    // Ring lifecycle: spawn → grow → fade → disappear
    const ringSpacing = 1.0 / 3.0; // 3 rings, each starts 1/3 cycle apart

    for (int i = 0; i < 3; i++) {
      // Calculate ring's individual progress (0..1 across its full lifecycle)
      final ringStart = i * ringSpacing;
      final ringProgress = ((progress - ringStart) % 1.0);

      // Ring growth: starts small (0.5 of maxR), grows to full size (1.0 of maxR)
      final r = lerpDouble(maxR * 0.55, maxR, ringProgress);

      // Natural fade pattern - strong at start, gentle fade at end
      double opacity;
      if (ringProgress < 0.3) {
        // Growing phase - fade in
        opacity = lerpDouble(0.0, 0.35, ringProgress / 0.3)!;
      } else if (ringProgress < 0.7) {
        // Stable phase - maintain opacity
        opacity = 0.35;
      } else {
        // Fading phase - fade out
        opacity = lerpDouble(0.35, 0.0, (ringProgress - 0.7) / 0.3)!;
      }

      // Apply base opacity and state-based intensity
      final finalOpacity = (opacity + baseOpacity).clamp(0.0, 0.4);

      paint.color = primaryColor.withValues(alpha: finalOpacity);
      if (r! > 0 && finalOpacity > 0.01) {
        canvas.drawCircle(center, r, paint);
      }
    }
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _NaturalRhythmRingsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.state != state;
  }
}

// Voice-reactive waveform with individual frequency bands
class _VoiceReactiveWaveform extends StatelessWidget {
  final double level; // Overall level 0..1
  final List<double> frequencyBands; // Individual bar levels 0..1
  final double t; // time 0..1
  final int barCount;
  final Color color;
  final Color dimColor;
  final bool isActive;

  const _VoiceReactiveWaveform({
    required this.level,
    required this.frequencyBands,
    required this.t,
    required this.barCount,
    required this.color,
    required this.dimColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    // Use individual frequency bands for voice reactivity
    final bars = List.generate(barCount, (i) {
      if (i < frequencyBands.length) {
        // Use real frequency band data
        final bandLevel = frequencyBands[i];
        // Create symmetric profile from center
        final centerDistance =
            (i - (barCount - 1) / 2).abs() / ((barCount - 1) / 2);
        final centerBoost =
            1.0 - centerDistance * 0.3; // Center bars slightly taller
        return (bandLevel * centerBoost).clamp(0.05, 1.0);
      } else {
        // Fallback to original algorithm for remaining bars
        final x = (i / (barCount - 1)) * 2 - 1; // -1..1
        final curve = 1.0 - (x * x); // dome shape
        final jitter = 0.15 * math.sin((i * 0.9) + t * math.pi * 2);
        final h = (0.18 + 0.64 * curve) * (0.35 + 0.65 * level + jitter);
        return h.clamp(0.05, 1.0);
      }
    });

    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final h in bars)
            Container(
              width: 4,
              height: 36 * h,
              decoration: BoxDecoration(
                color: isActive ? color : dimColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

// Edit Reminder Sheet - StatefulWidget to preserve controller state
class _EditReminderSheet extends StatefulWidget {
  final Reminder reminder;
  final int index;
  final Function(Reminder) onSave;

  const _EditReminderSheet({
    required this.reminder,
    required this.index,
    required this.onSave,
  });

  @override
  State<_EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends State<_EditReminderSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late RepeatType _selectedRepeat;
  late bool _isMultiTime;
  late List<TimeSlot> _timeSlots;
  late bool _isNotificationEnabled;
  Space? _selectedSpace;
  List<Space> _availableSpaces = [];

  @override
  void initState() {
    super.initState();

    // DEBUG: Log initialization details
    debugPrint('📝 ========================================');
    debugPrint('📝 INITIALIZING EDIT SHEET');
    debugPrint('📝 Reminder ID: ${widget.reminder.id}');
    debugPrint('📝 Original scheduledTime: ${widget.reminder.scheduledTime}');
    debugPrint('📝 Original snoozedUntil: ${widget.reminder.snoozedUntil}');
    debugPrint('📝 Initializing _selectedDate with scheduledTime');
    debugPrint('📝 ========================================');

    _titleController = TextEditingController(text: widget.reminder.title);
    _descriptionController =
        TextEditingController(text: widget.reminder.description ?? '');
    _selectedDate = widget.reminder.scheduledTime;
    _selectedTime = TimeOfDay.fromDateTime(widget.reminder.scheduledTime);
    _selectedRepeat = widget.reminder.repeatType;
    _isMultiTime = widget.reminder.hasMultipleTimes;
    _timeSlots = [...widget.reminder.timeSlots];
    _isNotificationEnabled = widget.reminder.isNotificationEnabled;

    debugPrint('📝 Initialized _selectedDate: $_selectedDate');
    debugPrint('📝 Initialized _selectedTime: $_selectedTime');

    // Load spaces and set current space
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    try {
      final spaces = await SpacesService.getSpaces();
      if (mounted) {
        setState(() {
          _availableSpaces = spaces;
          // Set the reminder's current space
          if (widget.reminder.spaceId != null) {
            _selectedSpace = spaces.firstWhere(
              (space) => space.id == widget.reminder.spaceId,
              orElse: () => spaces.first,
            );
            debugPrint('📝 Loaded reminder space: ${_selectedSpace?.name}');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading spaces in edit sheet: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    final modalHeight = keyboardHeight > 0
        ? screenHeight - topPadding - keyboardHeight - 40
        : screenHeight * 0.85;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: modalHeight,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: keyboardHeight > 0 ? 10 : 20,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildHeader(keyboardHeight),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(keyboardHeight > 0 ? 12 : 16),
                child: _buildContent(keyboardHeight),
              ),
            ),
            _buildSaveButton(keyboardHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double keyboardHeight) {
    return Container(
      padding: EdgeInsets.all(keyboardHeight > 0 ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Edit Reminder',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: keyboardHeight > 0 ? 18 : 20,
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

  Widget _buildContent(double keyboardHeight) {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'What do you want to be reminded about?',
            prefixIcon: Icon(Icons.title),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Add more details...',
            prefixIcon: Icon(Icons.description_outlined),
            border: OutlineInputBorder(),
          ),
          maxLines: keyboardHeight > 0 ? 2 : 3,
        ),
        const SizedBox(height: 20),
        MultiTimeSection(
          timeSlots: _timeSlots,
          onTimeSlotsChanged: (newTimeSlots) {
            setState(() => _timeSlots = newTimeSlots);
          },
          isMultiTime: _isMultiTime,
          onMultiTimeToggle: (value) {
            setState(() {
              _isMultiTime = value;
              if (!value) _timeSlots.clear();
            });
          },
          initialSingleTime: _selectedTime,
          onSingleTimeChanged: (newTime) {
            setState(() {
              _selectedTime = newTime;
              _selectedDate = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
                newTime.hour,
                newTime.minute,
              );
            });
          },
          singleTimeLabel: 'Time',
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 20),
        _buildDateSelector(),
        const SizedBox(height: 16),
        _buildRepeatSelector(),
        const SizedBox(height: 16),
        _buildNotificationToggle(),
        const SizedBox(height: 16),
        _buildSpaceSelector(),
        SizedBox(height: keyboardHeight > 0 ? 10 : 20),
      ],
    );
  }

  Widget _buildSpaceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: SpaceSelectorField(
          selectedSpace: _selectedSpace,
          availableSpaces: _availableSpaces,
          onSpaceChanged: (space) {
            setState(() {
              _selectedSpace = space;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: Text(_isMultiTime ? 'Base Date' : 'Date'),
        subtitle: Text(
          _isMultiTime
              ? '${DateFormat('EEEE, MMMM d, y').format(_selectedDate)} (for all times)'
              : DateFormat('EEEE, MMMM d, y').format(_selectedDate),
        ),
        trailing: const Icon(Icons.edit),
        onTap: () async {
          final now = DateTime.now();
          final initialDate = _selectedDate.isBefore(now) ? now : _selectedDate;

          final date = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: now,
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
        },
      ),
    );
  }

  Widget _buildRepeatSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.repeat),
        title: const Text('Repeat'),
        subtitle: Text(getRepeatDisplayName(_selectedRepeat)),
        trailing: const Icon(Icons.edit),
        onTap: () => _showRepeatOptions(),
      ),
    );
  }

  void _showRepeatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final availableHeight = screenHeight -
            MediaQuery.of(context).padding.top -
            MediaQuery.of(context).padding.bottom -
            keyboardHeight -
            32;

        final isSmallDevice = screenHeight < 700;
        final isVerySmallDevice = screenHeight < 600;
        final maxModalHeight = isVerySmallDevice
            ? availableHeight * 0.85
            : isSmallDevice
                ? availableHeight * 0.75
                : availableHeight * 0.6;

        return Container(
          margin: EdgeInsets.only(
            left: isSmallDevice ? 12.0 : 16.0,
            right: isSmallDevice ? 12.0 : 16.0,
            top: 16,
            bottom: 16 + keyboardHeight,
          ),
          constraints: BoxConstraints(
            maxHeight: maxModalHeight,
            minHeight: 200,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(isVerySmallDevice
                    ? 12.0
                    : isSmallDevice
                        ? 16.0
                        : 20.0),
                child: Text(
                  'Repeat Options',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: RepeatType.values.map((repeat) {
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isVerySmallDevice ? 4.0 : 8.0,
                        ),
                        title: Text(
                          getRepeatDisplayName(repeat),
                          style: TextStyle(
                            fontSize: isVerySmallDevice
                                ? 14.0
                                : isSmallDevice
                                    ? 15.0
                                    : 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          getRepeatDescription(repeat),
                          style: TextStyle(
                            fontSize: isVerySmallDevice
                                ? 11.0
                                : isSmallDevice
                                    ? 12.0
                                    : 13.0,
                            height: isVerySmallDevice ? 1.3 : 1.4,
                          ),
                          maxLines: isVerySmallDevice ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        leading: Radio<RepeatType>(
                          value: repeat,
                          groupValue: _selectedRepeat,
                          onChanged: (value) {
                            setState(() => _selectedRepeat = value!);
                            Navigator.pop(context);
                          },
                        ),
                        onTap: () {
                          setState(() => _selectedRepeat = repeat);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: isVerySmallDevice ? 10 : 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationToggle() {
    return Card(
      child: SwitchListTile(
        title: const Text('Enable Notifications'),
        subtitle: const Text('Get notified when it\'s time'),
        value: _isNotificationEnabled,
        onChanged: (value) {
          setState(() => _isNotificationEnabled = value);
        },
      ),
    );
  }

  Widget _buildSaveButton(double keyboardHeight) {
    return Container(
      padding: EdgeInsets.all(keyboardHeight > 0 ? 12 : 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            // DEBUG: Log edit details
            debugPrint('📝 ========================================');
            debugPrint('📝 EDITING REMINDER');
            debugPrint(
                '📝 Original scheduledTime: ${widget.reminder.scheduledTime}');
            debugPrint(
                '📝 Original snoozedUntil: ${widget.reminder.snoozedUntil}');
            debugPrint(
                '📝 New scheduledTime (from _selectedDate): $_selectedDate');
            debugPrint('📝 Clearing snooze: true');
            debugPrint('📝 ========================================');

            final updatedReminder = widget.reminder.copyWith(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              scheduledTime: _selectedDate,
              repeatType: _selectedRepeat,
              timeSlots: _timeSlots,
              isMultiTime: _isMultiTime,
              isNotificationEnabled: _isNotificationEnabled,
              spaceId: _selectedSpace?.id,
              clearSnooze: true, // Clear snooze state when editing
            );

            debugPrint(
                '📝 Updated reminder scheduledTime: ${updatedReminder.scheduledTime}');
            debugPrint(
                '📝 Updated reminder snoozedUntil: ${updatedReminder.snoozedUntil}');

            widget.onSave(updatedReminder);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
