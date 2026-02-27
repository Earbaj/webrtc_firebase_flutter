import 'package:googleapis_auth/auth_io.dart';

/// A class responsible for obtaining an OAuth2 access token to authenticate
/// with the Firebase Cloud Messaging (FCM) HTTP v1 API.
/// 
/// IMPORTANT NOTE: In a production environment, you should NEVER include 
/// your service account's private key directly in the client app code. 
/// This should ideally be done on a secure backend server.
class GetApiServerKeyFCM {
  
  /// Authenticates with Google APIs using service account credentials 
  /// and returns a valid access token.
  Future<String> getServerKey() async {
    // These scopes define the permissions the access token will have.
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging'
    ];

    try {
      // Create a Google Auth client using the service account JSON credentials.
      final client = await clientViaServiceAccount(
          ServiceAccountCredentials.fromJson({
            "your service keys"
          }), scopes
      );

      // Extract the bearer token from the client credentials once authenticated.
      final accessServerKey = client.credentials.accessToken.data;
      return accessServerKey;
    } catch (e) {
      print("Error fetching server key: $e");
      return "";
    }
  }
}