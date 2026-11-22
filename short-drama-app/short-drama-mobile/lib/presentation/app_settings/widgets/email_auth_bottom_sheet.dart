import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import '../../../core/app_export.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import '../../../services/user_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/top_toast.dart';

class EmailAuthBottomSheet extends StatefulWidget {
  const EmailAuthBottomSheet({Key? key}) : super(key: key);

  @override
  State<EmailAuthBottomSheet> createState() => _EmailAuthBottomSheetState();
}

class _EmailAuthBottomSheetState extends State<EmailAuthBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _signInFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final dividerColor = isDark ? AppTheme.dividerDark : AppTheme.dividerLight;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: AppTheme.settingsSheetDecoration(
          isDark: isDark,
          secondaryTextColor: secondaryTextColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: 1.5.h),
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            SizedBox(height: 2.h),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      Icons.email_outlined,
                      color: AppTheme.accentBlue,
                      size: 6.w,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.emailAuthentication,
                          style: GoogleFonts.inter(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          l10n.signInOrCreateNewAccount,
                          style: GoogleFonts.inter(
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: secondaryTextColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 2.h),

            // Tab bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDarkBlue : AppTheme.dividerLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.accentBlue,
                unselectedLabelColor: secondaryTextColor,
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: l10n.signIn.toUpperCase()),
                  Tab(text: l10n.register.toUpperCase()),
                ],
              ),
            ),

            SizedBox(height: 1.h),

            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSignInForm(isDark, textColor, secondaryTextColor),
                  _buildRegisterForm(isDark, textColor, secondaryTextColor),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(color: secondaryTextColor, fontSize: 14),
      hintStyle: GoogleFonts.inter(color: secondaryTextColor.withValues(alpha: 0.6), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: AppTheme.accentBlue, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppTheme.cardDarkBlue : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(
          color: isDark ? AppTheme.dividerDark : AppTheme.dividerLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: AppTheme.accentBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
    );
  }

  ButtonStyle _actionButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.accentBlue,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 1.8.h),
      shape: const StadiumBorder(),
      elevation: 0,
      disabledBackgroundColor: AppTheme.accentBlue.withValues(alpha: 0.5),
    );
  }

  Widget _buildLoadingOrLabel(String label) {
    if (_isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSignInForm(bool isDark, Color textColor, Color secondaryTextColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      child: Form(
        key: _signInFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              cursorColor: AppTheme.accentBlue,
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                label: l10n.email,
                hint: l10n.enterYourEmail,
                prefixIcon: Icons.email_outlined,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.pleaseEnterYourEmail;
                if (!value.contains('@')) return l10n.pleaseEnterValidEmail;
                return null;
              },
            ),

            SizedBox(height: 2.h),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: AppTheme.accentBlue,
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                label: l10n.password,
                hint: l10n.enterYourPassword,
                prefixIcon: Icons.lock_outlined,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.pleaseEnterYourPassword;
                if (value.length < 6) return l10n.passwordMustBeAtLeast6Characters;
                return null;
              },
            ),

            SizedBox(height: 0.5.h),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading ? null : _handleForgotPassword,
                child: Text(
                  l10n.forgotPassword,
                  style: GoogleFonts.inter(
                    color: AppTheme.accentBlue,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            SizedBox(height: 1.h),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignIn,
              style: _actionButtonStyle(),
              child: _buildLoadingOrLabel(l10n.signIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(bool isDark, Color textColor, Color secondaryTextColor) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              cursorColor: AppTheme.accentBlue,
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                label: l10n.email,
                hint: l10n.enterYourEmail,
                prefixIcon: Icons.email_outlined,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.pleaseEnterYourEmail;
                if (!value.contains('@')) return l10n.pleaseEnterValidEmail;
                return null;
              },
            ),

            SizedBox(height: 2.h),

            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              cursorColor: AppTheme.accentBlue,
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                label: l10n.password,
                hint: l10n.createAPassword,
                prefixIcon: Icons.lock_outlined,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return l10n.pleaseEnterAPassword;
                if (value.length < 6) return l10n.passwordMustBeAtLeast6Characters;
                return null;
              },
            ),

            SizedBox(height: 2.h),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              cursorColor: AppTheme.accentBlue,
              style: GoogleFonts.inter(color: textColor, fontSize: 14),
              decoration: _inputDecoration(
                label: l10n.confirmPassword,
                hint: l10n.reEnterYourPassword,
                prefixIcon: Icons.lock_outlined,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please confirm your password';
                if (value != _passwordController.text) return 'Passwords do not match';
                return null;
              },
            ),

            SizedBox(height: 3.h),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: _actionButtonStyle(),
              child: _buildLoadingOrLabel(l10n.register),
            ),

            SizedBox(height: 2.h),

            Text(
              'By creating an account, you agree to our Terms of Service and Privacy Policy',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: secondaryTextColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final userCredential = await AuthService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential != null && mounted) {
        final l10n = AppLocalizations.of(context)!;
        await Provider.of<UserProvider>(context, listen: false)
            .refreshUser(syncProStatus: true);
        Navigator.pop(context);
        showTopToastSuccess(context, l10n.successfullySignedIn);
      } else if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showTopToastError(context, l10n.signInFailed);
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(
          context,
          AuthService.instance.getAuthErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final userCredential = await AuthService.instance.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential != null && mounted) {
        await Provider.of<UserProvider>(context, listen: false)
            .refreshUser(syncProStatus: true);
        _passwordController.clear();
        _confirmPasswordController.clear();
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        }
        showTopToastSuccess(context, 'Account created successfully');
      } else if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showTopToastError(context, l10n.registrationFailed);
      }
    } catch (e) {
      if (mounted) {
        showTopToastError(
          context,
          AuthService.instance.getAuthErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      showTopToastError(context, l10n.pleaseEnterValidEmailAddress);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await AuthService.instance.sendPasswordResetEmail(email);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        if (success) {
          showTopToastSuccess(context, l10n.passwordResetEmailSent);
        } else {
          showTopToastError(context, l10n.failedToSendPasswordResetEmail);
        }
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        showTopToastError(context, l10n.error(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
