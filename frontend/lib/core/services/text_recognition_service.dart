import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Wraps Google ML Kit's on-device text recognizer for scanning text out of
/// note photos. Keep one instance alive for the lifetime of the screen that
/// uses it and [close] it in dispose() — creating a recognizer per scan is
/// wasteful since it loads a model into memory.
class TextRecognitionService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  void close() {
    _recognizer.close();
  }
}
