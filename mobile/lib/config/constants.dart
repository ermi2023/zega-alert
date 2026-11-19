import 'package:flutter/material.dart';

/// Official Brand Colors
/// Deep Royal Blue #00338D
const Color kBrandColor = Color(0xFF00338D);
const Color kBrandColorDark = Color(0xFF00225E);
const Color kBrandColorLight = Color(0xFF1A4FA8);

const String kAppLogo = 'assets/images/efp_logo.png';

const List<String> ethiopianRegions = [
  'Addis Ababa',
  'Afar',
  'Amhara',
  'Benishangul-Gumuz',
  'Dire Dawa',
  'Gambela',
  'Harari',
  'Oromia',
  'Sidama',
  'SNNPR',
  'Somali',
  'South West Ethiopia',
  'Tigray',
];

const Map<String, List<String>> subCitiesByRegion = {
  'Dire Dawa': ['Addis Ketema', 'Ashewa', 'Biyo Awr', 'Chenti', 'Ganda Gara', 'Goro', 'Legehare', 'Melka Jebdu', 'Wahil'],
  'Amhara': ['Debark', 'Gondar', 'Bahir Dar', 'Dessie', 'Kombolcha', 'Woldia', 'Axum'],
  'Addis Ababa': ['Arada', 'Addis Ketema', 'Yeka', 'Kolfe Keranio', 'Lideta', 'Nifas Silk-Lafto', 'Akaki Kality'],
  'Tigray': ['Mekelle', 'Shire', 'Axum', 'Adwa', 'Humera'],
  'Oromia': ['Adama', 'Jimma', 'Shashamane', 'Ambo', 'Nekemte'],
  'SNNPR': ['Hawassa', 'Wolkite', 'Dilla', 'Arba Minch'],
};
