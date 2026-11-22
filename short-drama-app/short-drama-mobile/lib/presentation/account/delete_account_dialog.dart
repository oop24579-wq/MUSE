import 'package:flutter/material.dart';

/// Type-to-confirm delete-account dialog.
///
/// The confirm button stays disabled until the user types `DELETE`.
/// Email/password users also get an optional password field (forwarded to
/// the backend/Firebase re-auth via [onConfirm]).
/// Returns `true` via [onConfirm] invocation — the dialog pops itself after
/// a successful confirm tap; deletion itself is the caller's job.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.onConfirm,
    this.showPasswordField = false,
    this.busy = false,
  });

  /// Called with the entered password (null when not applicable/empty)
  /// once the user has typed DELETE and tapped confirm.
  final Future<void> Function(String? password) onConfirm;
  final bool showPasswordField;
  final bool busy;

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String? password) onConfirm,
    bool showPasswordField = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => DeleteAccountDialog(
        onConfirm: onConfirm,
        showPasswordField: showPasswordField,
      ),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;

  bool get _canConfirm =>
      _confirmController.text.trim() == 'DELETE' && !_busy && !widget.busy;

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _busy = true);
    final password = _passwordController.text.isEmpty
        ? null
        : _passwordController.text;
    await widget.onConfirm(password);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935)),
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This permanently deletes your account, coins, watch history '
            'and subscription data. This cannot be undone.\n\n'
            'Type DELETE to confirm.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('delete_confirm_field'),
            controller: _confirmController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DELETE',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.showPasswordField) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('delete_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password (email accounts)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey('delete_confirm_button'),
          onPressed: _canConfirm ? _confirm : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
