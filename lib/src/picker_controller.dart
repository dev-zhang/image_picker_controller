import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker_controller/src/image_picker_configuration.dart';
import 'package:image_picker_controller/src/video_asset_model.dart';

class ImagePickerController {
  static const String _channelName = 'com.xiamijun.image_picker_controller';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static const String _pickImageMethod = 'pickImage';
  // 选择视频
  static const String _pickVideoMethod = 'pickVideo';
  // 拍摄图片方法
  static const String _takeImageMethod = 'take_image';

  /// 相册选择图片
  static Future<List<File>?> pickImage([
    ImagePickerConfiguration? configuration,
  ]) async {
    configuration ??= ImagePickerConfiguration();

    final filePaths = await _channel.invokeListMethod<String>(
      _pickImageMethod,
      configuration.toJson(),
    );
    if (filePaths == null) {
      return null;
    }
    return filePaths.map<File>((e) => File(e)).toList();
  }

  /// 相册选择视频
  static Future<List<VideoAssetModel>?> pickVideo({
    int maxDuration = 10 * 60,
    bool allowTakeVideo = true,
  }) async {
    final configuration = ImagePickerConfiguration();
    configuration
      ..allowTakePicture = false
      ..allowPickingImage = false
      ..allowTakeVideo = false
      ..videoMaxDuration = maxDuration
      ..maxImagesCount = 1;

    final result = await _channel.invokeListMethod<Map>(
      _pickVideoMethod,
      configuration.toJson(),
    );
    if (result == null) {
      return null;
    }
    return result
        .map((e) => VideoAssetModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  // /// 选择单个图片
  // ///
  // /// 支持裁剪
  // static Future<File> pickImage({
  //   bool allowCrop = true,
  //   bool allowTakePicture = true,
  // }) async {
  //   final config = ImagePickerConfiguration();
  //   config
  //     ..allowTakePicture = allowTakePicture
  //     ..maxImagesCount = 1
  //     ..allowCrop = allowCrop;
  //   final String filePath = await _channel.invokeMethod<String>(
  //       _pickSingleImageMethod, config.toJson());
  //   if (filePath == null) {
  //     return null;
  //   }
  //   return File(filePath);
  // }

  /// 拍摄图片
  ///
  /// [allowCrop]: 允许裁剪
  static Future<List<File>?> takeImage({
    bool allowCrop = true,
  }) async {
    final config = ImagePickerConfiguration();
    config..allowCrop = allowCrop;
    final filePaths = await _channel.invokeListMethod<String>(
        _takeImageMethod, config.toJson());
    if (filePaths == null) {
      return null;
    }
    return filePaths.map((path) => File(path)).toList();
  }
}
