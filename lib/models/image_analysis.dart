import 'dart:convert';

class ImageAnalysis {
  final String imagePath;
  final String fileName;
  final double meanRed;
  final double meanGreen;
  final double meanBlue;
  final double meanRChromaticity;
  final double meanGChromaticity;
  final double stdRChromaticity;
  final double stdGChromaticity;
  final double maxRed;
  final double maxGreen;
  final double maxBlue;
  final Map<String, dynamic> exifData;
  final DateTime analysisDate;
  final String fileSize;
  final String imageFormat;

  // Lamp condition (user selected)
  final String? lampCondition;

  // Photographic calculations
  final double? sV;
  final double? aV;
  final double? tV;
  final double? bV;

  ImageAnalysis({
    required this.imagePath,
    required this.fileName,
    required this.meanRed,
    required this.meanGreen,
    required this.meanBlue,
    required this.meanRChromaticity,
    required this.meanGChromaticity,
    required this.stdRChromaticity,
    required this.stdGChromaticity,
    required this.maxRed,
    required this.maxGreen,
    required this.maxBlue,
    required this.exifData,
    required this.analysisDate,
    required this.fileSize,
    required this.imageFormat,
    this.lampCondition,
    this.sV,
    this.aV,
    this.tV,
    this.bV,
  });

  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'fileName': fileName,
      'meanRed': meanRed,
      'meanGreen': meanGreen,
      'meanBlue': meanBlue,
      'meanRChromaticity': meanRChromaticity,
      'meanGChromaticity': meanGChromaticity,
      'stdRChromaticity': stdRChromaticity,
      'stdGChromaticity': stdGChromaticity,
      'maxRed': maxRed,
      'maxGreen': maxGreen,
      'maxBlue': maxBlue,
      'exifData': exifData,
      'analysisDate': analysisDate.toIso8601String(),
      'fileSize': fileSize,
      'imageFormat': imageFormat,
      'lampCondition': lampCondition,
      'sV': sV,
      'aV': aV,
      'tV': tV,
      'bV': bV,
    };
  }

  factory ImageAnalysis.fromJson(Map<String, dynamic> json) {
    return ImageAnalysis(
      imagePath: json['imagePath'],
      fileName: json['fileName'],
      meanRed: json['meanRed'].toDouble(),
      meanGreen: json['meanGreen'].toDouble(),
      meanBlue: json['meanBlue'].toDouble(),
      meanRChromaticity: json['meanRChromaticity']?.toDouble() ?? 0.0,
      meanGChromaticity: json['meanGChromaticity']?.toDouble() ?? 0.0,
      stdRChromaticity: json['stdRChromaticity']?.toDouble() ?? 0.0,
      stdGChromaticity: json['stdGChromaticity']?.toDouble() ?? 0.0,
      maxRed: json['maxRed']?.toDouble() ?? 0.0,
      maxGreen: json['maxGreen']?.toDouble() ?? 0.0,
      maxBlue: json['maxBlue']?.toDouble() ?? 0.0,
      exifData: Map<String, dynamic>.from(json['exifData']),
      analysisDate: DateTime.parse(json['analysisDate']),
      fileSize: json['fileSize'],
      imageFormat: json['imageFormat'],
      lampCondition: json['lampCondition'],
      sV: json['sV']?.toDouble(),
      aV: json['aV']?.toDouble(),
      tV: json['tV']?.toDouble(),
      bV: json['bV']?.toDouble(),
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  static ImageAnalysis fromJsonString(String jsonString) {
    return ImageAnalysis.fromJson(jsonDecode(jsonString));
  }
}
