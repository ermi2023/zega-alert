import 'package:flutter/material.dart';
import '../services/api.dart';
import '../screens/auth_screen.dart';

/// Shows [child] to signed-in users; otherwise a friendly prompt inviting
/// guests to create a free account. Guests can always browse public screens.
class AuthGate extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;

  const AuthGate({
    super.key,
    required this.child,
    this.title = 'Sign in to continue',
    this.message =
        'Create a free ZEGA-ALERT account or sign in to use this feature.',
  });

  @override
  Widget build(BuildContext context) {
    if (Api.isLoggedIn) return child;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openAuth(context),
              icon: const Icon(Icons.login),
              label: const Text('Sign in / Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Push the auth screen (used to upgrade a guest to a signed-in user).
Future<void> openAuth(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
  );
}

/// Returns true when the user is authenticated. If not, shows a dialog offering
/// to sign in; the caller should abort its action when this returns false.
Future<bool> ensureAuthed(BuildContext context, {String? reason}) async {
  if (Api.isLoggedIn) return true;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign in required'),
      content: Text(reason ?? 'Please sign in or create a free account to continue.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign in')),
      ],
    ),
  );
  if (go == true && context.mounted) await openAuth(context);
  return false;
}
