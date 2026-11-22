import 'package:flutter/material.dart';

import '../../models/user/user_model.dart';
import '../../services/account_service.dart';
import '../../widgets/top_toast.dart';
import 'account_helpers.dart';

/// Edit profile: display name + bundled avatar picker.
/// Persists through [AccountServiceBase.updateProfile] (PATCH /auth/me).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.user,
    this.service,
    this.provider,
  });

  final UserModel user;

  /// Injectable seam for tests; defaults to the real [AccountService].
  final AccountServiceBase? service;

  /// Provider label override (tests / callers that already resolved it).
  final String? provider;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late String? _selectedAvatar;
  bool _saving = false;

  AccountServiceBase get _service => widget.service ?? AccountService.instance;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.user.displayName ?? '');
    _selectedAvatar =
        isBundledAvatar(widget.user.photoUrl) ? widget.user.photoUrl : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 60) {
      showTopToastError(context, 'Name must be 1–60 characters.');
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await _service.updateProfile(
        name: name,
        image: _selectedAvatar,
      );
      if (!mounted) return;
      showTopToastSuccess(context, 'Profile saved');
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (mounted) showTopToastError(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final provider = widget.provider ?? providerLabel(user);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: accountAvatar(
              user: user.copyWith(photoUrl: _selectedAvatar ?? user.photoUrl),
              displayName: _nameController.text.isNotEmpty
                  ? _nameController.text
                  : (user.displayName ?? 'Guest'),
              size: 88,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('edit_name_field'),
            controller: _nameController,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Text('Choose an avatar',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: kAvatarAssets.length,
            itemBuilder: (context, i) {
              final path = kAvatarAssets[i];
              final selected = _selectedAvatar == path;
              return GestureDetector(
                key: ValueKey('avatar_option_$i'),
                onTap: () => setState(() => _selectedAvatar = path),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(child: Image.asset(path, fit: BoxFit.cover)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email ?? 'Guest account'),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Sign-in provider'),
            subtitle: Text(provider),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const ValueKey('edit_save_button'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
