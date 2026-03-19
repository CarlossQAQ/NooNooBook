import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'dart:convert';

class AudioService {
  final AudioRecorder _record = AudioRecorder();

  Future<bool> checkPermission() async {
    return await _record.hasPermission();
  }

  Future<void> startRecording(String fileName) async {
    final hasPermission = await _record.hasPermission();
    if (!hasPermission) return;

    final Directory tempDir = await getTemporaryDirectory();
    final String path = '${tempDir.path}/$fileName.wav';

    await _record.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path
    );
  }

  Future<String?> stopRecording() async {
    return await _record.stop();
  }

  void dispose() {
    _record.dispose();
  }

  /// 发送音频到后端做 STT（只返回识别文本）
  Future<String?> uploadAudio(String filePath, {String? direction}) async {
    try {
      final uri = Uri.parse('http://localhost:8000/transcribe');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(await http.MultipartFile.fromPath('audio', filePath));
      if (direction != null) {
        request.fields['direction'] = direction;
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        return response.body;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 发送文本到后端做翻译
  Future<String?> translateText(String text, {String? direction}) async {
    try {
      final uri = Uri.parse('http://localhost:8000/translate');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'direction': direction ?? 'EN_ZH'}),
      );
      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      return null;
    }
  }

  /// 通知后端清空翻译上下文
  Future<void> resetContext() async {
    try {
      final uri = Uri.parse('http://localhost:8000/reset');
      await http.post(uri);
    } catch (_) {}
  }

  /// 发送文本做 AI 总结
  Future<String?> summarizeAudio(String text) async {
    try {
      final uri = Uri.parse('http://localhost:8000/summarize');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      return null;
    }
  }
}
