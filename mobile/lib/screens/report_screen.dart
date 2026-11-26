import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../screens/report_detail_screen.dart';
import '../screens/communication_screen.dart';
import '../services/api.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

String _localizedCrimeCategory(String? value, AppLocalizations loc) =>
    switch (value) {
      'theft' => loc.crimeTheft,
      'robbery' => loc.crimeRobbery,
      'assault' => loc.crimeAssault,
      'burglary' => loc.crimeBurglary,
      'vandalism' => loc.crimeVandalism,
      'fraud' => loc.crimeFraud,
      'harassment' => loc.crimeHarassment,
      'drug' => loc.crimeDrug,
      'traffic' => loc.crimeTraffic,
      'domestic' => loc.crimeDomesticViolence,
      'kidnapping' => loc.crimeKidnapping,
      'murder' => loc.crimeMurder,
      'other' => loc.crimeOther,
      _ => value ?? '',
    };

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _mine = [];
  String? _loadError;
  bool _loading = true;
  bool _offline = false;
  String _query = '';
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loc = AppLocalizations.of(context);
    if (!Api.isLoggedIn) {
      setState(() {
        _loading = false;
        _mine = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
      _offline = false;
    });
    try {
      final mine = await Api.get('/reports/mine');
      await DatabaseService.cacheList('reports', mine);
      setState(() => _mine = mine is List ? mine : []);
    } catch (e) {
      final mine = await DatabaseService.getCachedList('reports');
      if (mine.isNotEmpty) {
        setState(() {
          _mine = mine;
          _offline = true;
        });
      } else {
        setState(
          () =>
              _loadError = Api.userMessage(e, fallback: loc.reportsLoadFailed),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openSubmission() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CrimeReportScreen(onDone: _load)));
  }

  Future<void> _rate(dynamic r) async {
    final id = r['id']?.toString();
    if (id == null || id.isEmpty) return;
    final loc = AppLocalizations.of(context);
    final comment = TextEditingController();
    int rating = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(loc.rateResponse),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: () => setLocal(() => rating = i + 1),
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: loc.commentOptional,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.submitReport),
            ),
          ],
        ),
      ),
    );
    if (submitted != true) return;
    try {
      await Api.post('/feedback/$id/feedback', {
        'rating': rating,
        'comment': comment.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.thanksFeedback)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Api.userMessage(e, fallback: loc.couldNotSubmitFeedback),
            ),
          ),
        );
      }
    }
  }

  String _statusLabel(String s, AppLocalizations loc) => switch (s) {
    'draft' => loc.reportFilterDrafts,
    'pending' => loc.reportStatusPending,
    'submitted' => loc.reportStatusSubmitted,
    'in_review' => loc.reportStatusInReview,
    'investigating' => loc.reportStatusInvestigating,
    'assigned' => loc.reportStatusAssigned,
    'resolved' => loc.reportFilterResolved,
    'rejected' => loc.reportStatusRejected,
    'closed' => loc.reportStatusClosed,
    _ => s.replaceAll('_', ' ').toUpperCase(),
  };

  Color _statusColor(String s) => switch (s) {
    'resolved' => Colors.green,
    'rejected' => Colors.red,
    'closed' => Colors.grey,
    _ => Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = _mine.where((r) {
      final status = (r['status'] ?? '').toString();
      final matchesFilter = switch (_filter) {
        'draft' => status == 'draft',
        'active' => [
          'pending',
          'submitted',
          'under_review',
          'assigned',
          'in_progress',
        ].contains(status),
        'resolved' => ['resolved', 'closed'].contains(status),
        _ => true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final title = (r['title'] ?? '').toString().toLowerCase();
      final category = (r['category'] ?? '').toString().toLowerCase();
      return title.contains(query) ||
          category.contains(query) ||
          status.contains(query);
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF0F172A),
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: [
              Tab(
                iconMargin: EdgeInsets.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.assignment_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(loc.myReports),
                  ],
                ),
              ),
              Tab(
                iconMargin: EdgeInsets.zero,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.forum_outlined, size: 18),
                    SizedBox(width: 8),
                    Text(loc.reportsFollowUpChat),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  loc.reportACrime,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  loc.yourReportGoesTo,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: loc.newCrimeReport,
                  child: SizedBox(
                    height: 72,
                    child: FilledButton.icon(
                      onPressed: _openSubmission,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        Icons.edit_note,
                        size: 28,
                        color: Colors.white,
                      ),
                      label: Text(
                        loc.newCrimeReport,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_offline)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: Colors.amber.shade100,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc.offlineMode,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_loadError != null)
                  Card(
                    color: Colors.blueGrey.shade50,
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loadError!,
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                Text(
                  loc.myReports,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: loc.reportsSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in [
                        ('all', loc.reportFilterAll),
                        ('active', loc.reportFilterActive),
                        ('resolved', loc.reportFilterResolved),
                        ('draft', loc.reportFilterDrafts),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(entry.$2),
                            selected: _filter == entry.$1,
                            onSelected: (_) =>
                                setState(() => _filter = entry.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        _mine.isEmpty
                            ? loc.noReportsYet
                            : loc.noReportsMatchFilter,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ...filtered
                    .take(20)
                    .map(
                      (r) => Semantics(
                        label:
                            '${loc.title}: ${r['title'] ?? loc.untitledReport}. '
                            '${loc.crimeCategoryField}: ${_localizedCrimeCategory(r['category']?.toString(), loc)}. '
                            '${_statusLabel((r['status'] ?? '').toString(), loc)}.',
                        child: Card(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.assignment_outlined,
                                  color: _statusColor(
                                    (r['status'] ?? '').toString(),
                                  ),
                                ),
                                title: Text(r['title'] ?? loc.untitledReport),
                                subtitle: Text(
                                  '${_localizedCrimeCategory(r['category']?.toString(), loc)} · ${_shortDate(r['reported_at']?.toString())}',
                                ),
                                trailing: Text(
                                  _statusLabel(
                                    (r['status'] ?? '').toString(),
                                    loc,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _statusColor(
                                      (r['status'] ?? '').toString(),
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  final id = r['id']?.toString();
                                  if (id != null && id.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ReportDetailScreen(id: id),
                                      ),
                                    );
                                  }
                                },
                              ),
                              if (r['status'] == 'resolved')
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    8,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Semantics(
                                      button: true,
                                      label: loc.rateResponseForReport(
                                        r['title'] ?? loc.untitledReport,
                                      ),
                                      child: TextButton.icon(
                                        onPressed: () => _rate(r),
                                        icon: const Icon(
                                          Icons.star_outline,
                                          size: 18,
                                        ),
                                        label: Text(loc.rateThisResponse),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),

          // Tab 2: Follow-up with Admin (Chat / Message System)
          const CommunicationScreen(),
        ],
      ),
    );
  }

  String _shortDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class CrimeReportScreen extends StatefulWidget {
  const CrimeReportScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  @override
  State<CrimeReportScreen> createState() => _CrimeReportScreenState();
}

class _CrimeReportScreenState extends State<CrimeReportScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'theft';
  String _severity = 'medium';
  bool _anonymous = false;
  bool _busy = false;
  String? _status;
  final List<Map<String, String>> _evidence = [];
  DateTime _incidentAt = DateTime.now();
  bool _useManualLocation = false;
  final _manualAddress = TextEditingController();
  final _manualLat = TextEditingController();
  final _manualLng = TextEditingController();

  List<({String value, String label})> _categories(AppLocalizations loc) => [
    (value: 'theft', label: _localizedCrimeCategory('theft', loc)),
    (value: 'robbery', label: _localizedCrimeCategory('robbery', loc)),
    (value: 'assault', label: _localizedCrimeCategory('assault', loc)),
    (value: 'burglary', label: _localizedCrimeCategory('burglary', loc)),
    (value: 'vandalism', label: _localizedCrimeCategory('vandalism', loc)),
    (value: 'fraud', label: _localizedCrimeCategory('fraud', loc)),
    (value: 'harassment', label: _localizedCrimeCategory('harassment', loc)),
    (value: 'drug', label: _localizedCrimeCategory('drug', loc)),
    (value: 'traffic', label: _localizedCrimeCategory('traffic', loc)),
    (value: 'domestic', label: _localizedCrimeCategory('domestic', loc)),
    (value: 'kidnapping', label: _localizedCrimeCategory('kidnapping', loc)),
    (value: 'murder', label: _localizedCrimeCategory('murder', loc)),
    (value: 'other', label: _localizedCrimeCategory('other', loc)),
  ];

  String _severityLabel(String value, AppLocalizations loc) => switch (value) {
    'low' => loc.severityLow,
    'medium' => loc.severityMedium,
    'high' => loc.severityHigh,
    'critical' => loc.severityCritical,
    _ => value,
  };

  String _evidenceLabel(String value, AppLocalizations loc) =>
      switch (value.toLowerCase()) {
        'photo' => loc.photo,
        'video' => loc.video,
        'audio' => loc.audio,
        'sign language' ||
        'sign_language' ||
        'sign_language_video' => loc.signLanguage,
        'link' => loc.link,
        'file' => loc.file,
        _ => value,
      };

  String _fmtDt(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit({bool draft = false}) async {
    final loc = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      Position? pos;
      try {
        if (_useManualLocation) {
          final lat = double.tryParse(_manualLat.text.trim());
          final lng = double.tryParse(_manualLng.text.trim());
          if (lat != null && lng != null) {
            pos = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 100,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
        } else {
          pos = await LocationService.gps();
        }
      } catch (_) {}
      final result = await Api.postOrQueue('/reports', {
        'category': _category,
        'severity': _severity,
        'status': draft ? 'draft' : 'pending',
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'incident_at': _incidentAt.toUtc().toIso8601String(),
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
        'address_text': _useManualLocation ? _manualAddress.text.trim() : null,
        'region': Api.region,
        'sub_city': Api.subCity,
        'is_anonymous': _anonymous,
        'evidence': _evidence,
      });
      final dispatchMessage = result['dispatch_recipient_count'] == 0
          ? 'Report saved, but no station officers or central dispatch recipients are available. Please contact emergency services directly.'
          : result['dispatch_route'] == 'central_dispatch'
          ? result['station_name'] != null
                ? 'Nearest station has no assigned officers. Report sent to central dispatch.'
                : 'Report submitted to central dispatch because no nearby registered station/location was available.'
          : 'Report submitted to ${result['station_name'] ?? 'the nearest police station'}. Thank you.';
      setState(
        () => _status = result['queued'] == true
            ? 'You are offline. ${draft ? 'Draft' : 'Report'} saved and will be synced automatically when back online.'
            : (draft
                  ? 'Draft saved. You can submit it later from My Reports.'
                  : dispatchMessage),
      );
      _title.clear();
      _desc.clear();
      _manualAddress.clear();
      _manualLat.clear();
      _manualLng.clear();
      _evidence.clear();
      widget.onDone?.call();
      if (!mounted) return;
      final queued = result['queued'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Saved offline. ${draft ? 'Your draft' : 'Your report'} will sync automatically when you are back online.'
                : (draft
                      ? 'Draft saved. You can finish and submit it from My Reports.'
                      : dispatchMessage),
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(
        () =>
            _status = Api.userMessage(e, fallback: loc.reportSubmissionFailed),
      );
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _addEvidence(String type) async {
    final loc = AppLocalizations.of(context);
    if (type == 'Link') {
      final value = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.addType(_evidenceLabel(type, loc))),
          content: TextField(
            controller: value,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: loc.url,
              hintText: 'https://',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, value.text.trim().isNotEmpty),
              child: Text(loc.add),
            ),
          ],
        ),
      );
      if (ok == true) {
        setState(
          () => _evidence.add({'type': 'link', 'value': value.text.trim()}),
        );
      }
      return;
    }

    if (type == 'Audio' || type == 'File') {
      try {
        final picked = await FilePicker.platform.pickFiles(
          type: type == 'Audio' ? FileType.audio : FileType.any,
          withData: kIsWeb, // On web, we need the bytes
        );
        final file = picked?.files.single;
        if (file != null) {
          if (kIsWeb) {
            // On web, file is XFile with bytes
            await _uploadEvidence(file, type.toLowerCase());
          } else {
            final path = file.path;
            if (path != null) await _uploadEvidence(path, type.toLowerCase());
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.uploadFailed(Api.userMessage(e)))),
          );
        }
      }
      return;
    }

    // Photo, Video and People of Determination sign-language video.
    final isVideo = type == 'Video' || type == 'Sign language';
    final source = type == 'Sign language'
        ? ImageSource.camera
        : await _pickSource();
    if (source == null) return;
    setState(() => _busy = true);
    try {
      if (!isVideo && source == ImageSource.gallery) {
        // Multi-image selection from gallery
        final files = await ImagePicker().pickMultiImage(
          maxWidth: 1600,
          imageQuality: 80,
        );
        for (final file in files) {
          await _uploadEvidence(file, 'photo');
        }
      } else {
        final file = isVideo
            ? await ImagePicker().pickVideo(
                source: source,
                maxDuration: Duration(
                  seconds: type == 'Sign language' ? 90 : 120,
                ),
              )
            : await ImagePicker().pickImage(
                source: source,
                maxWidth: 1600,
                imageQuality: 80,
              );
        if (file != null) {
          await _uploadEvidence(
            file,
            type == 'Sign language'
                ? 'sign_language_video'
                : type.toLowerCase(),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.uploadFailed(Api.userMessage(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadEvidence(dynamic file, String type) async {
    final loc = AppLocalizations.of(context);
    try {
      String? url;
      if (kIsWeb) {
        // On web, file is XFile - read bytes and use uploadBytes
        final bytes = await file.readAsBytes();
        final res = await Api.uploadBytes(
          '/upload/single',
          [MapEntry('file', bytes)],
          filenames: {'file': file.name},
        );
        url = Api.assetUrl(res['url']?.toString());
      } else {
        // On mobile/desktop, file is a path string
        final res = await Api.upload('/upload/single', [
          MapEntry('file', file as String),
        ]);
        url = Api.assetUrl(res['url']?.toString());
      }
      if (url == null || url.isEmpty) {
        throw Exception('Upload did not return a file URL');
      }
      if (mounted) setState(() => _evidence.add({'type': type, 'value': url!}));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.evidenceAttached(_evidenceLabel(type, loc))),
          ),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<ImageSource?> _pickSource() async {
    final loc = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(loc.photoCameraRecord),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(loc.chooseFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final categories = _categories(loc);
    return Scaffold(
      appBar: AppBar(title: Text(loc.newCrimeReport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_status != null)
            Card(
              color: Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _status!,
                  style: const TextStyle(color: Colors.blueGrey),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: '${loc.title}. ${loc.required}',
                  child: TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: loc.title,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? loc.required : null,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: '${loc.description}. ${loc.required}',
                  child: TextFormField(
                    controller: _desc,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: loc.description,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? loc.required : null,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: loc.crimeCategoryField,
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: loc.crimeCategoryField,
                      border: const OutlineInputBorder(),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.value,
                            child: Text(c.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _category = v ?? 'other'),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: loc.incidentDateTime,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(loc.incidentDateTime),
                    subtitle: Text(_fmtDt(_incidentAt)),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _incidentAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d == null || !context.mounted) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_incidentAt),
                      );
                      if (t == null || !context.mounted) return;
                      setState(
                        () => _incidentAt = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          t.hour,
                          t.minute,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.enterLocationManually),
                  subtitle: Text(loc.otherwiseUseGps),
                  value: _useManualLocation,
                  onChanged: (v) => setState(() => _useManualLocation = v),
                ),
                if (_useManualLocation) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualAddress,
                    decoration: InputDecoration(
                      labelText: loc.addressLabel,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualLat,
                          decoration: InputDecoration(
                            labelText: loc.latitudeLabel,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _manualLng,
                          decoration: InputDecoration(
                            labelText: loc.longitudeLabel,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Semantics(
                  label: '${loc.severity}: ${_severityLabel(_severity, loc)}',
                  child: DropdownButtonFormField<String>(
                    initialValue: _severity,
                    decoration: InputDecoration(
                      labelText: loc.severity,
                      border: const OutlineInputBorder(),
                    ),
                    items: ['low', 'medium', 'high', 'critical']
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(_severityLabel(s, loc)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _severity = v!),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: loc.reportAnonymously,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.reportAnonymously),
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.evidenceOptional,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(loc.photo),
                      onPressed: () => _addEvidence('Photo'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.videocam_outlined, size: 18),
                      label: Text(loc.video),
                      onPressed: () => _addEvidence('Video'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.mic_none, size: 18),
                      label: Text(loc.audio),
                      onPressed: () => _addEvidence('Audio'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.sign_language, size: 18),
                      label: Text(loc.signLanguage),
                      onPressed: () => _addEvidence('Sign language'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.link, size: 18),
                      label: Text(loc.link),
                      onPressed: () => _addEvidence('Link'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.attach_file, size: 18),
                      label: Text(loc.file),
                      onPressed: () => _addEvidence('File'),
                    ),
                  ],
                ),
                if (_evidence.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._evidence.map(
                    (e) => Card(
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.cloud_upload_outlined),
                        title: Text(
                          _evidenceLabel(e['type']?.toString() ?? '', loc),
                        ),
                        subtitle: Text(e['value'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _evidence.remove(e)),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: _busy ? loc.submitting : loc.submitReport,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? loc.submitting : loc.submitReport),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _submit(draft: true),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(loc.saveAsDraft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
