import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Firebase Storage service for uploading and managing files
class StorageService {
  static final StorageService _instance = StorageService._internal();
  static StorageService get instance => _instance;

  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Initialize Storage service
  Future<void> initialize() async {
    try {
      debugPrint('📦 Initializing Storage Service...');
      debugPrint('✅ Storage Service initialized');
    } catch (e) {
      debugPrint('❌ Storage Service initialization error: $e');
    }
  }

  /// Upload a file to Firebase Storage
  /// Returns the download URL
  Future<String> uploadFile({
    required String userId,
    required String chatId,
    required Uint8List fileBytes,
    required String fileName,
    String? contentType,
  }) async {
    final path = 'users/$userId/chats/$chatId/$fileName';
    try {
      debugPrint('📤 Uploading file to: $path (size: ${fileBytes.length} bytes)');
      
      final ref = _storage.ref().child(path);

      final metadata = SettableMetadata(
        contentType: contentType ?? 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = ref.putData(
        fileBytes,
        metadata,
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        debugPrint('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ File uploaded successfully: $path');
      debugPrint('🔗 Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading file to $path: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload a File object to Firebase Storage
  Future<String> uploadFileFromPath({
    required String userId,
    required String chatId,
    required File file,
    String? fileName,
    String? contentType,
  }) async {
    try {
      final fileBytes = await file.readAsBytes();
      final name = fileName ?? file.path.split('/').last;
      
      return await uploadFile(
        userId: userId,
        chatId: chatId,
        fileBytes: fileBytes,
        fileName: name,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('❌ Error uploading file from path: $e');
      rethrow;
    }
  }

  /// Delete a file from Firebase Storage
  Future<void> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('✅ File deleted: $downloadUrl');
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      // Don't rethrow - file might already be deleted
    }
  }

  /// Delete all files for a chat
  Future<void> deleteChatFiles(String userId, String chatId) async {
    try {
      final path = 'users/$userId/chats/$chatId';
      final ref = _storage.ref().child(path);
      
      final listResult = await ref.listAll();
      
      await Future.wait(
        listResult.items.map((item) => item.delete()),
      );
      
      debugPrint('✅ Chat files deleted: $path');
    } catch (e) {
      debugPrint('❌ Error deleting chat files: $e');
      // Don't rethrow - files might already be deleted
    }
  }
}

