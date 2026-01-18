import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/themes/colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/logger.dart';
import '../../providers/auth_provider.dart';
import '../../router/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_textfield.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    final authViewModel = ref.read(authViewModelProvider);
    final result = await authViewModel.resetPassword(email);

    result.fold(
          (error) {
        AppLogger.error('Reset password failed: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() => _isLoading = false);
      },
          (_) {
        AppLogger.info('Reset password email sent to: $email');
        setState(() {
          _isLoading = false;
          _isEmailSent = true;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Reset Password',
          style: TextStyles.h2,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Illustration
              Icon(
                Icons.lock_reset_rounded,
                size: 100,
                color: AppColors.primary,
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Forgot your password?',
                style: TextStyles.h2,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                _isEmailSent
                    ? 'Check your email for a password reset link'
                    : 'Enter your email address and we\'ll send you a link to reset your password',
                style: TextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              if (!_isEmailSent)
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 32),

                      // Reset Button
                      if (_isLoading || authState.isLoading)
                        const CircularProgressIndicator()
                      else
                        AppButton(
                          onPressed: _resetPassword,
                          text: 'Send Reset Link',
                          fullWidth: true,
                        ),
                    ],
                  ),
                ),

              if (_isEmailSent) ...[
                const SizedBox(height: 32),

                // Success Icon
                Icon(
                  Icons.check_circle_rounded,
                  size: 60,
                  color: AppColors.success,
                ),

                const SizedBox(height: 24),

                // Success Message
                Text(
                  'Email sent successfully!',
                  style: TextStyles.h3.copyWith(
                    color: AppColors.success,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Please check your inbox and follow the instructions to reset your password.',
                  style: TextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Back to Login Button
                AppButton(
                  onPressed: () => context.pop(),
                  text: 'Back to Login',
                  fullWidth: true,
                  outlined: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}