// Distinct from GoogleAuthService (login) -- this requests the
// drive.appdata scope specifically and returns a serverAuthCode, the
// one-time code PassVaultapi's POST /vault/auth/drive/connect exchanges for
// a refresh token (see services/vaultDrive.js's connectDriveService).
// Deliberately a separate GoogleSignIn instance/scope set from login's,
// mirroring passvault-client's DriveConnectionStatus: connecting Drive is a
// distinct consent step from signing in, not bundled into it.
import 'package:google_sign_in/google_sign_in.dart';

const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

class GoogleDriveConnectService {
  GoogleDriveConnectService(String serverClientId)
      : _googleSignIn = GoogleSignIn(scopes: [driveAppDataScope], serverClientId: serverClientId);

  final GoogleSignIn _googleSignIn;

  /// Runs the consent screen and returns the one-time server auth code.
  /// Google's own docs for this exact "mobile app calls a backend server"
  /// flow show the exchange with an empty redirect_uri -- see
  /// DriveRepository.connect, which sends redirectUri: '' accordingly.
  Future<String> requestServerAuthCode() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google Drive consent was cancelled.');
    }
    final code = account.serverAuthCode;
    if (code == null) {
      throw Exception('Google did not return a server auth code.');
    }
    return code;
  }
}
