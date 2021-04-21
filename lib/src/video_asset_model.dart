import 'dart:io';

/// 视频资源模型
class VideoAssetModel {
  VideoAssetModel();

  /// 视频文件
  File? video;

  /// 视频封面
  File? coverImage;

  factory VideoAssetModel.fromJson(Map<String, dynamic> json) {
    final model = VideoAssetModel();
    if (json['videoPath'] != null) {
      model.video = File(json['videoPath']);
    }
    if (json['coverPath'] != null) {
      model.coverImage = File(json['coverPath']);
    }
    return model;
  }

  @override
  String toString() {
    return 'video file: $video, cover image: $coverImage';
  }
}
