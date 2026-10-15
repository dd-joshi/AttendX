import 'package:flutter/services.dart';

abstract interface class DriveAuthorizationClient {
  Future<String> authorize(String? email);

  Future<void> disconnect(String email);
}

/// Google manages account selection and permission grants on Android.
/// No server code, refresh token, or client secret is needed by AttendX.
class DriveAuthorization implements DriveAuthorizationClient {
  const DriveAuthorization();

  static const _channel = MethodChannel('attendx/drive');

  @override
  Future<void> disconnect(String email) =>
      _channel.invokeMethod<void>('disconnect', {'email': email});

  @override
  Future<String> authorize(String? email) async {
    final token = await _channel.invokeMethod<String>('authorize', {
      'email': email,
    });
    if (token == null || token.isEmpty) {
      throw PlatformException(code: 'authorization');
    }
    return token;
  }
}
