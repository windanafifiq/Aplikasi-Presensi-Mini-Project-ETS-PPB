import 'package:geolocator/geolocator.dart';

class LocationService {
  // Koordinat Gedung Teknik Informatika ITS
  static const double itLatitude = -7.282540;
  static const double itLongitude = 112.794680;
  static const double allowedRadiusMeters = 300;

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  bool isWithinCampus(double lat, double lng) {
    final distance = Geolocator.distanceBetween(
      itLatitude, itLongitude, lat, lng,
    );
    return distance <= allowedRadiusMeters;
  }

  double getDistance(double lat, double lng) {
    return Geolocator.distanceBetween(itLatitude, itLongitude, lat, lng);
  }
}