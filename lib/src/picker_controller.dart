import 'package:flutter/services.dart';
import 'package:image_picker_controller/src/image_picker_configuration.dart';

class ImagePickerController {
  static const String _channelName = 'image_picker_controller';
  static const MethodChannel _channel = const MethodChannel(_channelName);

  static const String _pickImageMethod = 'pickImage';

  static Future<List<String>> pickImages({
    ImagePickerConfiguration configuration,
  }) async {
    configuration ??= ImagePickerConfiguration();
    // final Map<String, dynamic> params = <String, dynamic>{};

    final filePaths = await _channel.invokeListMethod<String>(
      _pickImageMethod,
      configuration.toJson(),
    );
    print(
        '=====ImagePickerController==invoke list method: ${filePaths.runtimeType}');
    return filePaths;
  }
}
