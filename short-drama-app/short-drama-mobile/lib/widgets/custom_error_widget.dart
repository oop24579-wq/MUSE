import 'package:flutter/material.dart';

import '../core/app_export.dart';
import '../theme/app_theme.dart';

// custom_error_widget.dart

class CustomErrorWidget extends StatelessWidget {
  final FlutterErrorDetails? errorDetails;
  final String? errorMessage;

  const CustomErrorWidget({Key? key, this.errorDetails, this.errorMessage})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, // Dark theme background
      body: Container(), // Empty container for blank screen
    );
  }
}
