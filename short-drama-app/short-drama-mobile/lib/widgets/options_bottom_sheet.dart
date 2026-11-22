import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../core/app_export.dart';
import 'top_toast.dart';

/// Bottom sheet for selecting options (checkboxes)
class OptionsBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String title;
  final String subtitle;

  const OptionsBottomSheet({
    Key? key,
    required this.items,
    required this.title,
    this.subtitle = 'Select the options you want to apply',
  }) : super(key: key);

  @override
  State<OptionsBottomSheet> createState() => _OptionsBottomSheetState();
}

class _OptionsBottomSheetState extends State<OptionsBottomSheet> {
  late List<bool> _selections;

  @override
  void initState() {
    super.initState();
    // Initialize selections based on item_checked
    _selections = widget.items
        .map((item) => item['item_checked'] as bool? ?? false)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 3.h,
        left: 4.w,
        right: 4.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 5.w,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            widget.subtitle,
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 3.5.w,
            ),
          ),
          SizedBox(height: 3.h),

          // Options list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              return _buildOptionItem(index);
            },
          ),

          SizedBox(height: 3.h),

          // Continue button
          GestureDetector(
            onTap: () {
              // Return selected prompts
              final selectedPrompts = <String>[];
              for (int i = 0; i < widget.items.length; i++) {
                if (_selections[i]) {
                  selectedPrompts.add(widget.items[i]['item_prompt'] as String);
                }
              }
              Navigator.pop(context, selectedPrompts);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Continue',
                textAlign: TextAlign.center,
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionItem(int index) {
    final item = widget.items[index];
    final itemText = item['item_text'] as String;
    final isSelected = _selections[index];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selections[index] = !_selections[index];
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 6.w,
              height: 6.w,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.divider,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: AppTheme.onPrimary,
                      size: 4.w,
                    )
                  : null,
            ),
            SizedBox(width: 3.w),

            // Text
            Expanded(
              child: Text(
                itemText.replaceAll('\n', ' '),
                style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for text input
class InputPromptBottomSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String hintText;
  final bool isMandatory;

  const InputPromptBottomSheet({
    Key? key,
    required this.title,
    this.subtitle = 'Describe what you want to do',
    this.hintText = 'Enter your description...',
    this.isMandatory = false,
  }) : super(key: key);

  @override
  State<InputPromptBottomSheet> createState() => _InputPromptBottomSheetState();
}

class _InputPromptBottomSheetState extends State<InputPromptBottomSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 3.h,
        left: 4.w,
        right: 4.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.title,
            style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 5.w,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            widget.subtitle,
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 3.5.w,
            ),
          ),
          SizedBox(height: 3.h),

          // Text field
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.divider,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          SizedBox(height: 3.h),

          // Continue button
          GestureDetector(
            onTap: () {
              final text = _controller.text.trim();
              if (widget.isMandatory && text.isEmpty) {
                showTopToastError(context, 'Please enter a description');
                return;
              }
              Navigator.pop(context, text.isEmpty ? null : text);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: widget.isMandatory && _controller.text.trim().isEmpty
                    ? AppTheme.textSecondary.withOpacity(0.3)
                    : AppTheme.primary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                'Continue',
                textAlign: TextAlign.center,
                style: AppTheme.darkTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

