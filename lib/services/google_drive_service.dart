import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/image_analysis.dart';

class GoogleDriveService {
  static const String _datasetFolderName = 'UVSN Json Dataset';
  
  // OAuth Client IDs from Google Cloud Console
  static const String _webClientId = '843540546414-kd8jb440kcgovhf4p94tsl7pri8sre8d.apps.googleusercontent.com';
  
  static GoogleSignIn? _googleSignIn;
  static drive.DriveApi? _driveApi;
  static String? _datasetFolderId;

  /// Initialize Google Sign-In with required scopes
  static GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      clientId: _webClientId,
      scopes: [
        'email',
        drive.DriveApi.driveFileScope,
      ],
    );
    return _googleSignIn!;
  }

  /// Check if user is signed in
  static Future<bool> isSignedIn() async {
    return await googleSignIn.isSignedIn();
  }

  /// Get current user info
  static GoogleSignInAccount? get currentUser => googleSignIn.currentUser;

  /// Sign in to Google
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await googleSignIn.signIn();
      if (account != null) {
        await _initDriveApi();
      }
      return account;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      rethrow;
    }
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    await googleSignIn.signOut();
    _driveApi = null;
    _datasetFolderId = null;
  }

  /// Initialize Drive API with authenticated client
  static Future<void> _initDriveApi() async {
    try {
      final httpClient = await googleSignIn.authenticatedClient();
      if (httpClient != null) {
        _driveApi = drive.DriveApi(httpClient);
      }
    } catch (e) {
      debugPrint('Failed to initialize Drive API: $e');
      rethrow;
    }
  }

  /// Ensure Drive API is initialized
  static Future<drive.DriveApi> _getDriveApi() async {
    if (_driveApi == null) {
      // Try to sign in silently first
      final account = await googleSignIn.signInSilently();
      if (account != null) {
        await _initDriveApi();
      }
      
      if (_driveApi == null) {
        throw Exception('Not signed in to Google. Please sign in first.');
      }
    }
    return _driveApi!;
  }

  /// Find or create the UVSN Json Dataset folder
  static Future<String> _getOrCreateDatasetFolder() async {
    if (_datasetFolderId != null) {
      return _datasetFolderId!;
    }

    final driveApi = await _getDriveApi();

    // Search for existing folder
    try {
      final query = "name = '$_datasetFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false";
      final result = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (result.files != null && result.files!.isNotEmpty) {
        _datasetFolderId = result.files!.first.id;
        debugPrint('Found existing folder: $_datasetFolderName (ID: $_datasetFolderId)');
        return _datasetFolderId!;
      }
    } catch (e) {
      debugPrint('Error searching for folder: $e');
    }

    // Create new folder if not found
    final folderMetadata = drive.File()
      ..name = _datasetFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final folder = await driveApi.files.create(folderMetadata);
    _datasetFolderId = folder.id;
    debugPrint('Created new folder: $_datasetFolderName (ID: $_datasetFolderId)');
    return _datasetFolderId!;
  }

  /// Upload a single analysis to Google Drive
  static Future<String> uploadAnalysis(ImageAnalysis analysis) async {
    final driveApi = await _getDriveApi();
    final folderId = await _getOrCreateDatasetFolder();

    // Create file name with timestamp to avoid duplicates
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${analysis.fileName}_${timestamp}.json';

    // Prepare JSON content
    final jsonContent = analysis.toJsonString();
    final bytes = utf8.encode(jsonContent);

    // Create file metadata
    final fileMetadata = drive.File()
      ..name = fileName
      ..parents = [folderId]
      ..mimeType = 'application/json';

    // Upload file
    final media = drive.Media(
      Stream.fromIterable([bytes]),
      bytes.length,
    );

    final uploadedFile = await driveApi.files.create(
      fileMetadata,
      uploadMedia: media,
    );

    debugPrint('Uploaded to Google Drive: ${uploadedFile.name} (ID: ${uploadedFile.id})');
    return 'Added to "$_datasetFolderName": $fileName';
  }

  /// Upload multiple analyses to Google Drive
  static Future<String> uploadBulkAnalyses(
    List<ImageAnalysis> analyses, {
    void Function(int current, int total)? onProgress,
  }) async {
    final driveApi = await _getDriveApi();
    final folderId = await _getOrCreateDatasetFolder();

    int successCount = 0;
    final errors = <String>[];

    for (int i = 0; i < analyses.length; i++) {
      try {
        final analysis = analyses[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${analysis.fileName}_${timestamp}.json';

        final jsonContent = analysis.toJsonString();
        final bytes = utf8.encode(jsonContent);

        final fileMetadata = drive.File()
          ..name = fileName
          ..parents = [folderId]
          ..mimeType = 'application/json';

        final media = drive.Media(
          Stream.fromIterable([bytes]),
          bytes.length,
        );

        await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
        );

        successCount++;
        onProgress?.call(i + 1, analyses.length);
      } catch (e) {
        errors.add(analyses[i].fileName);
        debugPrint('Failed to upload ${analyses[i].fileName}: $e');
      }
    }

    if (errors.isNotEmpty) {
      return 'Added $successCount/${analyses.length} files. Failed: ${errors.join(", ")}';
    }
    return 'Added $successCount files to "$_datasetFolderName"';
  }

  /// List files in the dataset folder
  static Future<List<drive.File>> listDatasetFiles() async {
    final driveApi = await _getDriveApi();
    final folderId = await _getOrCreateDatasetFolder();

    final query = "'$folderId' in parents and trashed = false";
    final result = await driveApi.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name, createdTime, size)',
      orderBy: 'createdTime desc',
    );

    return result.files ?? [];
  }
}
