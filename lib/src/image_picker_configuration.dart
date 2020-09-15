class ImagePickerConfiguration {
  ImagePickerConfiguration({
    this.maxImagesCount = 9,
    this.allowPickingOriginalPhoto = true,
    this.allowPickingVideo = true,
    this.allowPickingImage = true,
    this.allowTakePicture = true,
    this.videoMaxDuration = 10 * 60,
  })  : assert(maxImagesCount != null),
        assert(allowPickingImage != null),
        assert(allowPickingOriginalPhoto != null),
        assert(allowPickingVideo != null),
        assert(allowTakePicture != null),
        assert(videoMaxDuration != null);

  /// Default is 9 / 默认最大可选9张图片
  int maxImagesCount;

  /// Default is YES, if set NO, the original photo button will hide. user can't picking original photo.
  /// 默认为YES，如果设置为NO,原图按钮将隐藏，用户不能选择发送原图
  bool allowPickingOriginalPhoto;

  /// Default is YES, if set NO, user can't picking video.
  /// 默认为YES，如果设置为NO,用户将不能选择视频
  bool allowPickingVideo;

  /// Default is YES, if set NO, user can't take video.
  /// 默认为YES，如果设置为NO, 用户将不能拍摄视频
  bool allowTakeVideo;

  /// Default is YES, if set NO, user can't picking image.
  /// 默认为YES，如果设置为NO,用户将不能选择发送图片
  bool allowPickingImage;

  /// Default is YES, if set NO, user can't take picture.
  /// 默认为YES，如果设置为NO, 用户将不能拍摄照片
  bool allowTakePicture;

  /// Default value is 10 minutes / 视频最大拍摄时间，默认是10分钟，单位是秒
  int videoMaxDuration;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maxImageCount': maxImagesCount,
      'videoMaxDuration': videoMaxDuration,
      'allowTakeVideo': allowTakeVideo,
      'allowTakePicture': allowTakePicture,
      'allowPickingOriginalPhoto': allowPickingOriginalPhoto,
      'allowPickingVideo': allowPickingVideo,
      'allowPickingImage': allowPickingImage,
    };
  }
}
