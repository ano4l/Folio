import 'dart:io';
import 'package:flutter/services.dart';
import 'word_pdf_converter.dart';

class DocumentScanner {
  static const _channel = MethodChannel('folio/documents');
  static Future<String?> scan() => _channel.invokeMethod<String>('scan');

  static Future<String> mergePdfs(List<String> paths) async =>
      (await _channel.invokeMethod<String>('mergePdf', {'paths': paths}))!;

  static Future<String> imagesToPdf(List<String> paths) async =>
      (await _channel.invokeMethod<String>('imagesToPdf', {'paths': paths}))!;

  static Future<String> extractPages(String path, String pages) async =>
      (await _channel.invokeMethod<String>('extractPages', {
        'path': path,
        'pages': pages,
      }))!;

  static Future<String> wordToPdf(String path) =>
      WordPdfConverter.convert(path);
  static Future<List<Map<String, dynamic>>> extract(String path) async {
    if ((!Platform.isAndroid && !Platform.isIOS) ||
        path.toLowerCase().endsWith('.docx')) {
      return [];
    }
    final pages = await _channel.invokeListMethod<dynamic>('extract', {
      'path': path,
    });
    return (pages ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }
}
