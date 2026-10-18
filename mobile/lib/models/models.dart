class Report {
  final String id;
  final String? reporterId;
  final String category;
  final String severity;
  final String status;
  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? addressText;
  final String? region;
  final String? subCity;
  final String? woreda;
  final bool isAnonymous;
  final List<dynamic> evidence;
  final String? assignedTo;
  final int priorityScore;
  final String? reportedAt;
  final String? resolvedAt;
  final String? incidentAt;
  final List<ReportStatusEvent> history;

  Report({
    required this.id,
    this.reporterId,
    required this.category,
    this.severity = 'medium',
    this.status = 'pending',
    required this.title,
    this.description,
    this.latitude,
    this.longitude,
    this.addressText,
    this.region,
    this.subCity,
    this.woreda,
    this.isAnonymous = false,
    this.evidence = const [],
    this.assignedTo,
    this.priorityScore = 0,
    this.reportedAt,
    this.resolvedAt,
    this.incidentAt,
    this.history = const [],
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
    id: json['id'] as String,
    reporterId: json['reporter_id'] as String?,
    category: json['category'] as String? ?? 'other',
    severity: json['severity'] as String? ?? 'medium',
    status: json['status'] as String? ?? 'pending',
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    addressText: json['address_text'] as String?,
    region: json['region'] as String?,
    subCity: json['sub_city'] as String?,
    woreda: json['woreda'] as String?,
    isAnonymous: json['is_anonymous'] as bool? ?? false,
    evidence: json['evidence'] as List<dynamic>? ?? [],
    assignedTo: json['assigned_to'] as String?,
    priorityScore: json['priority_score'] as int? ?? 0,
    reportedAt: json['reported_at'] as String?,
    resolvedAt: json['resolved_at'] as String?,
    incidentAt: json['incident_at'] as String?,
    history: (json['history'] as List<dynamic>? ?? [])
        .map((e) => ReportStatusEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class ReportStatusEvent {
  final String? status;
  final String? notes;
  final String? changedBy;
  final String? changedAt;

  ReportStatusEvent({this.status, this.notes, this.changedBy, this.changedAt});

  factory ReportStatusEvent.fromJson(Map<String, dynamic> json) => ReportStatusEvent(
    status: json['status'] as String?,
    notes: json['notes'] as String?,
    changedBy: json['changed_by'] as String?,
    changedAt: json['changed_at'] as String?,
  );
}

class SosAlert {
  final String id;
  final String? userId;
  final double? latitude;
  final double? longitude;
  final String? addressText;
  final String? description;
  final String status;
  final String? region;
  final String? userName;
  final String? userPhone;
  final String? createdAt;

  SosAlert({
    required this.id,
    this.userId,
    this.latitude,
    this.longitude,
    this.addressText,
    this.description,
    this.status = 'triggered',
    this.region,
    this.userName,
    this.userPhone,
    this.createdAt,
  });

  factory SosAlert.fromJson(Map<String, dynamic> json) => SosAlert(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    addressText: json['address_text'] as String?,
    description: json['description'] as String?,
    status: json['status'] as String? ?? 'triggered',
    region: json['region'] as String?,
    userName: json['user_name'] as String?,
    userPhone: json['user_phone'] as String?,
    createdAt: json['created_at'] as String?,
  );
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? region;
  final String? subCity;
  final String? authorId;
  final String? authorName;
  final String? publishedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    this.category = 'news',
    this.region,
    this.subCity,
    this.authorId,
    this.authorName,
    this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: json['category'] as String? ?? 'news',
    region: json['region'] as String?,
    subCity: json['sub_city'] as String?,
    authorId: json['author_id'] as String?,
    authorName: json['author_name'] as String?,
    publishedAt: json['published_at'] as String?,
  );
}

class MissingPerson {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String? photoUrl;
  final String? description;
  final double? lastSeenLat;
  final double? lastSeenLng;
  final String? lastSeenAddress;
  final String? lastSeenAt;
  final String? reporterId;
  final String? contactPhone;
  final String status;

  MissingPerson({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.photoUrl,
    this.description,
    this.lastSeenLat,
    this.lastSeenLng,
    this.lastSeenAddress,
    this.lastSeenAt,
    this.reporterId,
    this.contactPhone,
    this.status = 'missing',
  });

  factory MissingPerson.fromJson(Map<String, dynamic> json) => MissingPerson(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    age: json['age'] as int?,
    gender: json['gender'] as String?,
    photoUrl: json['photo_url'] as String?,
    description: json['description'] as String?,
    lastSeenLat: (json['last_seen_lat'] as num?)?.toDouble(),
    lastSeenLng: (json['last_seen_lng'] as num?)?.toDouble(),
    lastSeenAddress: json['last_seen_address'] as String?,
    lastSeenAt: json['last_seen_at'] as String?,
    reporterId: json['reporter_id'] as String?,
    contactPhone: json['contact_phone'] as String?,
    status: json['status'] as String? ?? 'missing',
  );
}

class Geofence {
  final String id;
  final String name;
  final String type;
  final String? region;
  final String? subCity;
  final double? centerLat;
  final double? centerLng;
  final double? radiusM;

  Geofence({
    required this.id,
    required this.name,
    this.type = 'zone',
    this.region,
    this.subCity,
    this.centerLat,
    this.centerLng,
    this.radiusM,
  });

  factory Geofence.fromJson(Map<String, dynamic> json) => Geofence(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'zone',
    region: json['region'] as String?,
    subCity: json['sub_city'] as String?,
    centerLat: (json['center_lat'] as num?)?.toDouble(),
    centerLng: (json['center_lng'] as num?)?.toDouble(),
    radiusM: (json['radius_m'] as num?)?.toDouble(),
  );
}

class LegalContent {
  final String id;
  final String title;
  final String body;
  final String? category;
  final String language;

  LegalContent({
    required this.id,
    required this.title,
    required this.body,
    this.category,
    this.language = 'en',
  });

  factory LegalContent.fromJson(Map<String, dynamic> json) => LegalContent(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    category: json['category'] as String?,
    language: json['language'] as String? ?? 'en',
  );
}

class Conversation {
  final String id;
  final String type;
  final String? title;
  final List<String> participantIds;
  final String? createdAt;

  Conversation({
    required this.id,
    this.type = 'direct',
    this.title,
    this.participantIds = const [],
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    type: json['type'] as String? ?? 'direct',
    title: json['title'] as String?,
    participantIds: (json['participant_ids'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: json['created_at'] as String?,
  );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String? senderId;
  final String? senderName;
  final String? body;
  final String messageType;
  final String? createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    this.senderId,
    this.senderName,
    this.body,
    this.messageType = 'text',
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversation_id'] as String,
    senderId: json['sender_id'] as String?,
    senderName: json['sender_name'] as String?,
    body: json['body'] as String?,
    messageType: json['message_type'] as String? ?? 'text',
    createdAt: json['created_at'] as String?,
  );
}

class CallbackRequest {
  final String id;
  final String? reportId;
  final String? reportTitle;
  final String? citizenId;
  final String? officerId;
  final String? requestedSlot;
  final String mode;
  final String status;
  final String? notes;

  CallbackRequest({
    required this.id,
    this.reportId,
    this.reportTitle,
    this.citizenId,
    this.officerId,
    this.requestedSlot,
    this.mode = 'voice',
    this.status = 'pending',
    this.notes,
  });

  factory CallbackRequest.fromJson(Map<String, dynamic> json) => CallbackRequest(
    id: json['id'] as String,
    reportId: json['report_id'] as String?,
    reportTitle: json['report_title'] as String?,
    citizenId: json['citizen_id'] as String?,
    officerId: json['officer_id'] as String?,
    requestedSlot: json['requested_slot'] as String?,
    mode: json['mode'] as String? ?? 'voice',
    status: json['status'] as String? ?? 'pending',
    notes: json['notes'] as String?,
  );
}
