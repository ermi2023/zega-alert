import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/api.dart';
import '../screens/login_screen.dart';

/// Shows [child] to signed-in users; otherwise a friendly prompt inviting
/// guests to create a free account. Guests can always browse public screens.
class AuthGate extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? message;

  const AuthGate({
    super.key,
    required this.child,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    if (Api.isLoggedIn) return child;
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title ?? loc.authGateTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? loc.authGateMessage,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openAuth(context),
              icon: const Icon(Icons.login),
              label: Text(loc.signInCreateAccount),
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
    MaterialPageRoute(builder: (_) => const LoginScreen()),
  );
}

/// Returns true when the user is authenticated. If not, shows a dialog offering
/// to sign in; the caller should abort its action when this returns false.
Future<bool> ensureAuthed(BuildContext context, {String? reason}) async {
  if (Api.isLoggedIn) return true;
  final loc = AppLocalizations.of(context);
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(loc.signInRequiredTitle),
      content: Text(reason ?? loc.signInRequiredMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(loc.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(loc.signingIn),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) await openAuth(context);
  return false;
}
