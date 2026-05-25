import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Fetches the current location coordinates.
  /// Falls back to a simulated position or returns null if permissions are denied
  /// or geolocator service is not active.
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled.
        return null;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (e) {
      // Return a simulated Position on exception (e.g. testing in headless mode/emulators)
      print("Location service exception (falling back): $e");
      return null;
    }
  }

  /// Helper to get a simulated position for fallback/testing
  static Position getMockPosition() {
    return Position(
      latitude: 37.7749, // San Francisco
      longitude: -122.4194,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }
}
