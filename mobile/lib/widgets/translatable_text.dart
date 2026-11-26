import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../services/api.dart';
import '../services/database_service.dart';

/// A small inline widget that wraps a piece of translatable text and shows
/// a "Translate" button next to it.
///
/// Behavior:
/// - When the app language is English: a dropdown lets the user pick which
///   language to translate TO (AMH / ORM / TIGIR / SOM).
/// - When the app language is a local language (am/om/ti/so): the button
///   translates the text to English on tap (no dropdown needed).
/// - Tap toggles between "Translate" and "Show original".
/// - Translations are cached in a static map keyed by (target, source-text),
///   so re-rendering a card doesn't re-call the API.
class TranslatableText extends StatefulWidget {
  const TranslatableText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines,
    this.textAlign,
    this.sourceLanguage = 'en',
    this.translateIcon = true,
  });

  /// The source text shown by default.
  final String text;

  /// TextStyle applied to the displayed text (original or translated).
  final TextStyle? style;

  /// Optional maxLines for the text.
  final int? maxLines;

  /// Optional text alignment.
  final TextAlign? textAlign;

  /// Language code the source text is in (default 'en').
  final String sourceLanguage;

  /// Whether to show the translate icon next to the label.
  final bool translateIcon;

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  /// Static cache: (targetLang, sourceText) -> translated text.
  /// Persists across widget instances for the lifetime of the app.
  static final Map<String, String> _cache = {};

  String? _translated;
  String? _translatedTo; // target code of the current translation
  bool _loading = false;
  String? _error;
  String _selectedTarget = 'am'; // dropdown default; only used when app is en

  /// App's current language code (en/am/om/ti/so).
  String get _appLanguage => ZegaAlertApp.of(context)?.languageCode ?? 'en';
  String get _sourceLanguage =>
      widget.sourceLanguage.trim().toLowerCase().split(RegExp('[-_]')).first;

  /// Whether to show the per-card target dropdown (app is English).
  bool get _showDropdown => _appLanguage == 'en';

  /// Short display labels matching the language picker.
  static const List<({String code, String label})> _targets = [
    (code: 'am', label: 'AMH'),
    (code: 'om', label: 'ORM'),
    (code: 'ti', label: 'TIGIR'),
    (code: 'so', label: 'SOM'),
    (code: 'en', label: 'EN'),
  ];

  /// Resolve the target language to translate to.
  /// - App is English -> user-selected from dropdown.
  /// - App is a local language -> translate to the app language.
  String get _effectiveTarget => _showDropdown ? _selectedTarget : _appLanguage;

  String _cacheKey(String target) =>
      '$target::$_sourceLanguage::${widget.text}';

  String _persistentCacheKey(String target) =>
      'translation::$target::$_sourceLanguage::${widget.text}';

  @override
  void initState() {
    super.initState();
    if (_selectedTarget == _sourceLanguage) {
      _selectedTarget = _defaultTarget;
    }
    _loadPersistentCache();
  }

  @override
  void didUpdateWidget(covariant TranslatableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text &&
        oldWidget.sourceLanguage == widget.sourceLanguage) {
      return;
    }
    _translated = null;
    _translatedTo = null;
    _error = null;
    if (_selectedTarget == _sourceLanguage) {
      _selectedTarget = _defaultTarget;
    }
    _loadPersistentCache();
  }

  String get _defaultTarget =>
      _targets.firstWhere((target) => target.code != _sourceLanguage).code;

  Future<void> _loadPersistentCache() async {
    final target = _effectiveTarget;
    final key = _cacheKey(target);
    if (_cache.containsKey(key)) return;
    final value = await DatabaseService.getCachedValue(
      _persistentCacheKey(target),
    );
    if (!mounted || value is! String || value.isEmpty) return;
    _cache[key] = value;
    if (_appLanguage == 'en' ? target == _selectedTarget : target == 'en') {
      setState(() {
        _translated = value;
        _translatedTo = target;
      });
    }
  }

  Future<void> _toggle() async {
    if (_loading) return;

    // Already translated -> revert.
    if (_translated != null && _translatedTo == _effectiveTarget) {
      setState(() {
        _translated = null;
        _translatedTo = null;
      });
      return;
    }

    final target = _effectiveTarget;
    final key = _cacheKey(target);

    // Cache hit.
    final cached = _cache[key];
    if (cached != null) {
      setState(() {
        _translated = cached;
        _translatedTo = target;
        _error = null;
      });
      return;
    }

    // Network call.
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Api.translate(
        widget.text,
        target,
        sourceLanguage: _sourceLanguage,
      );
      final translated = (result['text'] as String?) ?? widget.text;
      _cache[key] = translated;
      await DatabaseService.cacheValue(_persistentCacheKey(target), translated);
      if (mounted) {
        setState(() {
          _translated = translated;
          _translatedTo = target;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = Api.userMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _onTargetChanged(String? code) {
    if (code == null || code == _selectedTarget) return;
    setState(() {
      _selectedTarget = code;
      // If we were already showing a translation, re-translate to the new target.
      if (_translated != null) {
        _translated = null;
        _translatedTo = null;
      }
    });
    // Auto-trigger translation when picking a new target if user had it on.
    _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isTranslated =
        _translated != null && _translatedTo == _effectiveTarget;

    final textWidget = Text(
      isTranslated ? _translated! : widget.text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: widget.textAlign,
    );

    // Don't render the control if the source text is empty.
    if (widget.text.trim().isEmpty) {
      return textWidget;
    }

    // Don't render the control if source === target (nothing to translate).
    if (_sourceLanguage == _effectiveTarget) {
      return textWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        textWidget,
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Per-card target dropdown — only when app is English.
            if (_showDropdown && !isTranslated)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: DropdownButton<String>(
                  value: _selectedTarget,
                  isDense: true,
                  underline: const SizedBox(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                  items: _targets
                      .where((t) => t.code != _sourceLanguage)
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.code,
                          child: Text(t.label),
                        ),
                      )
                      .toList(),
                  onChanged: _onTargetChanged,
                ),
              ),
            // Translate / Show original toggle button.
            InkWell(
              onTap: _loading ? null : _toggle,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.translateIcon) ...[
                      Icon(
                        Icons.translate,
                        size: 14,
                        color: _loading
                            ? theme.colorScheme.outline
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (_loading)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.primary,
                          ),
                        ),
                      )
                    else
                      Text(
                        isTranslated ? loc.showOriginal : loc.translate,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(width: 4),
                      Tooltip(
                        message: _error!,
                        child: Icon(
                          Icons.error_outline,
                          size: 12,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
