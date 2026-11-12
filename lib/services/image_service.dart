import 'package:image_picker/image_picker.dart';

class ImageException implements Exception {
  ImageException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ImageService {
  ImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickAttachment() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1400,
      );
      return file?.path;
    } catch (error) {
      throw ImageException('Gagal memilih lampiran: $error');
    }
  }

  Future<String> takeSelfie() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 60,
        maxWidth: 900,
      );
      if (file == null) {
        throw ImageException('Foto tidak diambil.');
      }
      return file.path;
    } catch (error) {
      if (error is ImageException) rethrow;
      throw ImageException('Gagal membuka kamera: $error');
    }
  }
}
