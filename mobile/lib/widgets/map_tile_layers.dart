import 'package:flutter_map/flutter_map.dart';

const _streetMapUrl = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
const _satelliteMapUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

TileLayer mapTileLayer({required bool satellite}) => TileLayer(
  urlTemplate: satellite ? _satelliteMapUrl : _streetMapUrl,
  subdomains: satellite ? const [] : const ['a', 'b', 'c'],
  userAgentPackageName: 'com.zega.alert',
);

RichAttributionWidget mapAttribution({required bool satellite}) =>
    RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          satellite
              ? 'Imagery © Esri, Maxar, Earthstar Geographics'
              : '© OpenStreetMap contributors',
        ),
      ],
    );
