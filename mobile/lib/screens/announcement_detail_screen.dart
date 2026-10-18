import 'package:flutter/material.dart';
import '../services/api.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item['title'] ?? 'Announcement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(item['title'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            Chip(label: Text(item['category'] ?? 'news')),
            if (item['region'] != null) Chip(label: Text(item['region'])),
            if (item['published_at'] != null) Chip(label: Text(item['published_at'].toString().substring(0, 10))),
          ]),
          const SizedBox(height: 12),
          Text(item['body'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
          if (item['image_url'] != null) ...[
            const SizedBox(height: 12),
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['image_url'], fit: BoxFit.cover)),
          ],
        ],
      ),
    );
  }
}
