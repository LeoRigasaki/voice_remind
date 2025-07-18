// lib/widgets/search_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchWidget extends StatefulWidget {
  final Function(String) onSearchChanged;
  final VoidCallback onClose;
  final String hintText;

  const SearchWidget({
    super.key,
    required this.onSearchChanged,
    required this.onClose,
    this.hintText = 'Search reminders...',
  });

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _controller.addListener(() {
      widget.onSearchChanged(_controller.text);
      setState(() {}); // Rebuild to show/hide clear button
    });

    // Auto-focus and animate in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    HapticFeedback.lightImpact();
    _controller.clear();
  }

  void _closeSearch() {
    HapticFeedback.lightImpact();
    _focusNode.unfocus();
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            hintText: widget.hintText,
            backgroundColor: WidgetStateProperty.all(Colors.transparent),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            elevation: WidgetStateProperty.all(0),
            side: WidgetStateProperty.all(BorderSide.none),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            leading: Icon(
              Icons.search,
              color: colorScheme.onSurfaceVariant,
              size: 24,
            ),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  onPressed: _clearSearch,
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: 'Clear',
                ),
              IconButton(
                onPressed: _closeSearch,
                icon: Icon(
                  Icons.arrow_back,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                tooltip: 'Close search',
              ),
            ],
            textStyle: WidgetStateProperty.all(
              theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            hintStyle: WidgetStateProperty.all(
              theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Clean highlighting widget following Material Design
class HighlightedText extends StatelessWidget {
  final String text;
  final String searchTerm;
  final TextStyle? defaultStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.searchTerm,
    this.defaultStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (searchTerm.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final highlightStyle = defaultStyle?.copyWith(
          backgroundColor: colorScheme.primaryContainer,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          backgroundColor: colorScheme.primaryContainer,
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        );

    final spans = <TextSpan>[];
    final searchLower = searchTerm.toLowerCase();
    final textLower = text.toLowerCase();

    int currentIndex = 0;
    while (currentIndex < text.length) {
      final index = textLower.indexOf(searchLower, currentIndex);

      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: defaultStyle,
        ));
        break;
      }

      if (index > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, index),
          style: defaultStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + searchTerm.length),
        style: highlightStyle,
      ));

      currentIndex = index + searchTerm.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

// Search results summary widget
class SearchResultsSummary extends StatelessWidget {
  final int resultCount;
  final String searchQuery;

  const SearchResultsSummary({
    super.key,
    required this.resultCount,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            resultCount > 0 ? Icons.search : Icons.search_off,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              resultCount > 0
                  ? '$resultCount result${resultCount == 1 ? '' : 's'} for "$searchQuery"'
                  : 'No results for "$searchQuery"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
