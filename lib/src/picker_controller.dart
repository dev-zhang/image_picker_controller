import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker_controller/src/image_picker_configuration.dart';

class ImagePickerController {
  static const String _channelName = 'com.xiamijun.image_picker_controller';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static const String _pickImageMethod = 'pickImage';
  // 选择视频
  static const String _pickVideoMethod = 'pickVideo';
  // 选择单个图片方法
  static const String _pickSingleImageMethod = 'pick_single_image';
  // 拍摄图片方法
  static const String _takeImageMethod = 'take_image';

  /// 相册选择图片
  static Future<List<String>> pickImages({
    ImagePickerConfiguration configuration,
  }) async {
    configuration ??= ImagePickerConfiguration();

    final filePaths = await _channel.invokeListMethod<String>(
      _pickImageMethod,
      configuration.toJson(),
    );
    print(
        '=====ImagePickerController==invoke list method: ${filePaths.runtimeType}');
    return filePaths;
  }

  /// 相册选择视频
  static Future<String> pickVideo({
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

    final filePath = await _channel.invokeMethod<String>(
      _pickVideoMethod,
      configuration.toJson(),
    );
    print('=====ImagePickerController==invoke method: ${filePath.runtimeType}');
    return filePath;
  }

  /// 选择单个图片
  ///
  /// 支持裁剪
  static Future<File> pickImage({
    bool allowCrop = true,
    bool allowTakePicture = true,
  }) async {
    final config = ImagePickerConfiguration();
    config
      ..allowTakePicture = allowTakePicture
      ..maxImagesCount = 1
      ..allowCrop = allowCrop;
    final String filePath = await _channel.invokeMethod<String>(
        _pickSingleImageMethod, config.toJson());
    if (filePath == null) {
      return null;
    }
    return File(filePath);
  }

  /// 拍摄图片
  ///
  /// [allowCrop]: 允许裁剪
  static Future<File> takeImage({
    bool allowCrop = true,
  }) async {
    final config = ImagePickerConfiguration();
    config..allowCrop = allowCrop;
    final String filePath =
        await _channel.invokeMethod<String>(_takeImageMethod, config.toJson());
    if (filePath == null) {
      return null;
    }
    return File(filePath);
  }
}
