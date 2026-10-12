import 'package:geolocator/geolocator.dart';

/// Thrown when a real fix can't be obtained -- message matches what
/// PassVaultapi's requireGeolocation would reject the request with anyway,
/// so surfacing it directly keeps the local and server-side stories consistent.
class LocationRequiredException implements Exception {
  final String message;
  const LocationRequiredException(this.message);
  @override
  String toString() => message;
}

class LocationCoordinates {
  final double latitude;
  final double longitude;
  const LocationCoordinates(this.latitude, this.longitude);
}

/// login/register/google-sign-in on PassVaultapi hard-reject a request with
/// no coordinates (services/vaultAuth.js's requireGeolocation) -- unlike
/// passvault-client's browser geolocation prompt (LocationRequiredModal),
/// this has to explicitly request the OS permission first.
class LocationService {
  Future<LocationCoordinates> requireCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationRequiredException(
        'Location services are turned off. Please enable location and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const LocationRequiredException(
        'Location access is required to continue -- please enable location and try again',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      return LocationCoordinates(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationRequiredException(
        'Location access is required to continue -- please enable location and try again',
      );
    }
  }

  /// Best-effort variant for PUT /vault/data and the reveal step-up's
  /// activity-log tagging -- mirrors passvault-client's getCurrentCoords:
  /// never throws or blocks the caller, just resolves null if a fix can't
  /// be read (permission not yet granted, GPS off, timeout, ...).
  Future<LocationCoordinates?> tryGetCurrentLocation() async {
    try {
      return await requireCurrentLocation();
    } catch (_) {
      return null;
    }
  }
}
