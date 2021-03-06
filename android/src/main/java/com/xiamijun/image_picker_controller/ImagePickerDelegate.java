// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.xiamijun.image_picker_controller;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Bitmap;
import android.hardware.camera2.CameraCharacteristics;
import android.media.MediaMetadataRetriever;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.provider.MediaStore;
import android.util.Log;

import androidx.annotation.VisibleForTesting;
import androidx.core.app.ActivityCompat;
import androidx.core.content.FileProvider;

import com.luck.picture.lib.PictureSelector;
import com.luck.picture.lib.config.PictureMimeType;
import com.luck.picture.lib.entity.LocalMedia;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

enum CameraDevice {
  REAR,

  FRONT
}

/**
 * A delegate class doing the heavy lifting for the plugin.
 *
 * <p>When invoked, both the {@link #chooseImageFromGallery} and {@link #takeImageWithCamera}
 * methods go through the same steps:
 *
 * <p>1. Check for an existing {@link #pendingResult}. If a previous pendingResult exists, this
 * means that the chooseImageFromGallery() or takeImageWithCamera() method was called at least
 * twice. In this case, stop executing and finish with an error.
 *
 * <p>2. Check that a required runtime permission has been granted. The chooseImageFromGallery()
 * method checks if the {@link Manifest.permission#READ_EXTERNAL_STORAGE} permission has been
 * granted. Similarly, the takeImageWithCamera() method checks that {@link
 * Manifest.permission#CAMERA} has been granted.
 *
 * <p>The permission check can end up in two different outcomes:
 *
 * <p>A) If the permission has already been granted, continue with picking the image from gallery or
 * camera.
 *
 * <p>B) If the permission hasn't already been granted, ask for the permission from the user. If the
 * user grants the permission, proceed with step #3. If the user denies the permission, stop doing
 * anything else and finish with a null result.
 *
 * <p>3. Launch the gallery or camera for picking the image, depending on whether
 * chooseImageFromGallery() or takeImageWithCamera() was called.
 *
 * <p>This can end up in three different outcomes:
 *
 * <p>A) User picks an image. No maxWidth or maxHeight was specified when calling {@code
 * pickImage()} method in the Dart side of this plugin. Finish with full path for the picked image
 * as the result.
 *
 * <p>B) User picks an image. A maxWidth and/or maxHeight was provided when calling {@code
 * pickImage()} method in the Dart side of this plugin. A scaled copy of the image is created.
 * Finish with full path for the scaled image as the result.
 *
 * <p>C) User cancels picking an image. Finish with null result.
 */
public class ImagePickerDelegate
        implements PluginRegistry.ActivityResultListener,
        PluginRegistry.RequestPermissionsResultListener {
  @VisibleForTesting
  static final int REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY = 2342;
  @VisibleForTesting
  static final int REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA = 2343;
  @VisibleForTesting
  static final int REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION = 2344;
  @VisibleForTesting
  static final int REQUEST_CAMERA_IMAGE_PERMISSION = 2345;
  @VisibleForTesting
  static final int REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY = 2352;
  @VisibleForTesting
  static final int REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA = 2353;
  @VisibleForTesting
  static final int REQUEST_EXTERNAL_VIDEO_STORAGE_PERMISSION = 2354;
  @VisibleForTesting
  static final int REQUEST_CAMERA_VIDEO_PERMISSION = 2355;


  @VisibleForTesting
  final String fileProviderName;

  private final Activity activity;
  private final File externalFilesDirectory;
  private final ImageResizer imageResizer;
  private final ImagePickerCache cache;
  private final PermissionManager permissionManager;
  private final IntentResolver intentResolver;
  private final FileUriResolver fileUriResolver;
  private final FileUtils fileUtils;
  private CameraDevice cameraDevice;

  interface PermissionManager {
    boolean isPermissionGranted(String permissionName);

    void askForPermission(String permissionName, int requestCode);

    boolean needRequestCameraPermission();
  }

  interface IntentResolver {
    boolean resolveActivity(Intent intent);
  }

  interface FileUriResolver {
    Uri resolveFileProviderUriForFile(String fileProviderName, File imageFile);

    void getFullImagePath(Uri imageUri, OnPathReadyListener listener);
  }

  interface OnPathReadyListener {
    void onPathReady(String path);
  }

  private Uri pendingCameraMediaUri;
  private MethodChannel.Result pendingResult;
  private MethodCall methodCall;

  public ImagePickerDelegate(
      final Activity activity,
      final File externalFilesDirectory,
      final ImageResizer imageResizer,
      final ImagePickerCache cache) {
    this(
        activity,
        externalFilesDirectory,
        imageResizer,
        null,
        null,
        cache,
        new PermissionManager() {
          @Override
          public boolean isPermissionGranted(String permissionName) {
            return ActivityCompat.checkSelfPermission(activity, permissionName)
                == PackageManager.PERMISSION_GRANTED;
          }

          @Override
          public void askForPermission(String permissionName, int requestCode) {
            ActivityCompat.requestPermissions(activity, new String[] {permissionName}, requestCode);
          }

          @Override
          public boolean needRequestCameraPermission() {
            return ImagePickerUtils.needRequestCameraPermission(activity);
          }
        },
        new IntentResolver() {
          @Override
          public boolean resolveActivity(Intent intent) {
            return intent.resolveActivity(activity.getPackageManager()) != null;
          }
        },
        new FileUriResolver() {
          @Override
          public Uri resolveFileProviderUriForFile(String fileProviderName, File file) {
            return FileProvider.getUriForFile(activity, fileProviderName, file);
          }

          @Override
          public void getFullImagePath(final Uri imageUri, final OnPathReadyListener listener) {
            MediaScannerConnection.scanFile(
                activity,
                new String[] {(imageUri != null) ? imageUri.getPath() : ""},
                null,
                new MediaScannerConnection.OnScanCompletedListener() {
                  @Override
                  public void onScanCompleted(String path, Uri uri) {
                    listener.onPathReady(path);
                  }
                });
          }
        },
        new FileUtils());
  }

  /**
   * This constructor is used exclusively for testing; it can be used to provide mocks to final
   * fields of this class. Otherwise those fields would have to be mutable and visible.
   */
  @VisibleForTesting
  ImagePickerDelegate(
      final Activity activity,
      final File externalFilesDirectory,
      final ImageResizer imageResizer,
      final MethodChannel.Result result,
      final MethodCall methodCall,
      final ImagePickerCache cache,
      final PermissionManager permissionManager,
      final IntentResolver intentResolver,
      final FileUriResolver fileUriResolver,
      final FileUtils fileUtils) {
    this.activity = activity;
    this.externalFilesDirectory = externalFilesDirectory;
    this.imageResizer = imageResizer;
    this.fileProviderName = activity.getPackageName() + ".flutter.image_provider";
    this.pendingResult = result;
    this.methodCall = methodCall;
    this.permissionManager = permissionManager;
    this.intentResolver = intentResolver;
    this.fileUriResolver = fileUriResolver;
    this.fileUtils = fileUtils;
    this.cache = cache;
  }

  void setCameraDevice(CameraDevice device) {
    cameraDevice = device;
  }

  CameraDevice getCameraDevice() {
    return cameraDevice;
  }

  // Save the state of the image picker so it can be retrieved with `retrieveLostImage`.
  void saveStateBeforeResult() {
    if (methodCall == null) {
      return;
    }

    cache.saveTypeWithMethodCallName(methodCall.method);
    cache.saveDimensionWithMethodCall(methodCall);
    if (pendingCameraMediaUri != null) {
      cache.savePendingCameraMediaUriPath(pendingCameraMediaUri);
    }
  }

  void retrieveLostImage(MethodChannel.Result result) {
    Map<String, Object> resultMap = cache.getCacheMap();
    String path = (String) resultMap.get(cache.MAP_KEY_PATH);
    if (path != null) {
      Double maxWidth = (Double) resultMap.get(cache.MAP_KEY_MAX_WIDTH);
      Double maxHeight = (Double) resultMap.get(cache.MAP_KEY_MAX_HEIGHT);
      int imageQuality =
          resultMap.get(cache.MAP_KEY_IMAGE_QUALITY) == null
              ? 100
              : (int) resultMap.get(cache.MAP_KEY_IMAGE_QUALITY);

      String newPath = imageResizer.resizeImageIfNeeded(path, maxWidth, maxHeight, imageQuality);
      resultMap.put(cache.MAP_KEY_PATH, newPath);
    }
    if (resultMap.isEmpty()) {
      result.success(null);
    } else {
      result.success(resultMap);
    }
    cache.clear();
  }

  public void chooseVideoFromGallery(MethodCall methodCall, MethodChannel.Result result) {
    if (!setPendingMethodCallAndResult(methodCall, result)) {
      finishWithAlreadyActiveError(result);
      return;
    }

    if (!permissionManager.isPermissionGranted(Manifest.permission.READ_EXTERNAL_STORAGE)) {
      permissionManager.askForPermission(
          Manifest.permission.READ_EXTERNAL_STORAGE, REQUEST_EXTERNAL_VIDEO_STORAGE_PERMISSION);
      return;
    }

    launchPickVideoFromGalleryIntent();
  }

  private void launchPickVideoFromGalleryIntent() {
//    Intent pickVideoIntent = new Intent(Intent.ACTION_GET_CONTENT);
//    pickVideoIntent.setType("video/*");
//
//    activity.startActivityForResult(pickVideoIntent, REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY);


    PickerConfiguration config = PickerConfiguration.fromMap((Map) methodCall.arguments());
//    Log.d("config===", "===" + config);
    PictureSelector.create(activity)
            .openGallery(PictureMimeType.ofVideo())
            .imageEngine(GlideEngine.createGlideEngine())
            .isGif(false) // 是否显示GIF图片
            .isAndroidQTransform(true) // 是否需要处理Android Q 拷贝至应用沙盒的操作，只针对compress(false); && .isEnableCrop(false);有效,默认处理
            .maxSelectNum(config.maxImageCount) // 最大图片选择数量
            .isOriginalImageControl(config.allowPickingOriginalPhoto) // 是否显示原图控制按钮，如果设置为true则用户可以自由选择是否使用原图，压缩、裁剪功能将会失效
            .isCamera(config.allowTakeVideo) // 是否显示拍照按钮
            .isEnableCrop(config.allowCrop) // 是否裁剪
            .withAspectRatio(1, 1) // 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
//            .freeStyleCropEnabled(false) // 裁剪框是否可以拖拽
//            .circleDimmedLayer(false) // 是否圆形裁剪
//            .showCropGrid(false) // 是否显示裁剪矩形网格 圆形裁剪时建议设为false
            .isCompress(false) // 是否压缩
//            .compressQuality(80) // 图片压缩后输出质量 0 ~ 100
            .maxVideoSelectNum(config.maxImageCount) // 视频最大选择数量
            .videoMaxSecond(config.videoMaxDuration) // 查询多少秒以内的视频
            .recordVideoSecond(config.videoMaxDuration) // 录制视频秒数
//            .videoQuality(1) // 视频录制的质量 0 or 1
            .cutOutQuality(100) // 裁剪输出质量
            .minimumCompressSize(100) // 小于多少kb的图片不压缩
            .forResult(REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY);
  }

  public void takeVideoWithCamera(MethodCall methodCall, MethodChannel.Result result) {
    if (!setPendingMethodCallAndResult(methodCall, result)) {
      finishWithAlreadyActiveError(result);
      return;
    }

    if (needRequestCameraPermission()
        && !permissionManager.isPermissionGranted(Manifest.permission.CAMERA)) {
      permissionManager.askForPermission(
          Manifest.permission.CAMERA, REQUEST_CAMERA_VIDEO_PERMISSION);
      return;
    }

    launchTakeVideoWithCameraIntent();
  }

  private void launchTakeVideoWithCameraIntent() {
    Intent intent = new Intent(MediaStore.ACTION_VIDEO_CAPTURE);
    if (this.methodCall != null && this.methodCall.argument("maxDuration") != null) {
      int maxSeconds = this.methodCall.argument("maxDuration");
      intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, maxSeconds);
    }
    if (cameraDevice == CameraDevice.FRONT) {
      useFrontCamera(intent);
    }

    boolean canTakePhotos = intentResolver.resolveActivity(intent);

    if (!canTakePhotos) {
      finishWithError("no_available_camera", "No cameras available for taking pictures.");
      return;
    }

    File videoFile = createTemporaryWritableVideoFile();
    pendingCameraMediaUri = Uri.parse("file:" + videoFile.getAbsolutePath());

    Uri videoUri = fileUriResolver.resolveFileProviderUriForFile(fileProviderName, videoFile);
    intent.putExtra(MediaStore.EXTRA_OUTPUT, videoUri);
    grantUriPermissions(intent, videoUri);

    activity.startActivityForResult(intent, REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA);
  }

  public void chooseImageFromGallery(MethodCall methodCall, MethodChannel.Result result) {
    if (!setPendingMethodCallAndResult(methodCall, result)) {
      finishWithAlreadyActiveError(result);
      return;
    }

    if (!permissionManager.isPermissionGranted(Manifest.permission.READ_EXTERNAL_STORAGE)) {
      permissionManager.askForPermission(
          Manifest.permission.READ_EXTERNAL_STORAGE, REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION);
      return;
    }

    launchPickImageFromGalleryIntent();
  }

  private void launchPickImageFromGalleryIntent() {
//    Intent pickImageIntent = new Intent(Intent.ACTION_GET_CONTENT);
//    pickImageIntent.setType("image/*");
//
//    activity.startActivityForResult(pickImageIntent, REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY);


    PickerConfiguration config = PickerConfiguration.fromMap((Map) methodCall.arguments());
//    Log.d("config===", "===" + config);
    PictureSelector.create(activity)
            .openGallery(PictureMimeType.ofImage())
            .imageEngine(GlideEngine.createGlideEngine())
            .isGif(false) // 是否显示GIF图片
            .isAndroidQTransform(true) // 是否需要处理Android Q 拷贝至应用沙盒的操作，只针对compress(false); && .isEnableCrop(false);有效,默认处理
            .maxSelectNum(config.maxImageCount) // 最大图片选择数量
            .isOriginalImageControl(config.allowPickingOriginalPhoto) // 是否显示原图控制按钮，如果设置为true则用户可以自由选择是否使用原图，压缩、裁剪功能将会失效
            .isCamera(config.allowTakePicture) // 是否显示拍照按钮
            .isEnableCrop(config.allowCrop) // 是否裁剪
            .withAspectRatio(1, 1) // 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
//            .cropImageWideHigh(40, 40) // 裁剪宽高，设置如果大于图片本身宽高则无效
            .freeStyleCropEnabled(true) // 裁剪框是否可以拖拽
//            .circleDimmedLayer(false) // 是否圆形裁剪
//            .showCropGrid(false) // 是否显示裁剪矩形网格 圆形裁剪时建议设为false
            .scaleEnabled(true) // 裁剪是否可放大缩小图片
            .rotateEnabled(false) // 裁剪是否可旋转图片
            .isCompress(false) // 是否压缩
//            .compressQuality(80) // 图片压缩后输出质量 0 ~ 100
            .maxVideoSelectNum(config.maxImageCount) // 视频最大选择数量
            .videoMaxSecond(config.videoMaxDuration) // 查询多少秒以内的视频
            .recordVideoSecond(config.videoMaxDuration) // 录制视频秒数
//            .videoQuality(1) // 视频录制的质量 0 or 1
            .cutOutQuality(100) // 裁剪输出质量
            .minimumCompressSize(100) // 小于多少kb的图片不压缩
            .forResult(REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY);
  }

  public void takeImageWithCamera(MethodCall methodCall, MethodChannel.Result result) {
    if (!setPendingMethodCallAndResult(methodCall, result)) {
      finishWithAlreadyActiveError(result);
      return;
    }

    if (needRequestCameraPermission()
            && !permissionManager.isPermissionGranted(Manifest.permission.CAMERA)) {
      permissionManager.askForPermission(
              Manifest.permission.CAMERA, REQUEST_CAMERA_IMAGE_PERMISSION);
      return;
    }
    launchTakeImageWithCameraIntent();
  }

  private boolean needRequestCameraPermission() {
    if (permissionManager == null) {
      return false;
    }
    return permissionManager.needRequestCameraPermission();
  }

  private void launchTakeImageWithCameraIntent() {
    Intent intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
    if (cameraDevice == CameraDevice.FRONT) {
      useFrontCamera(intent);
    }

    boolean canTakePhotos = intentResolver.resolveActivity(intent);

    if (!canTakePhotos) {
      finishWithError("no_available_camera", "No cameras available for taking pictures.");
      return;
    }


    PickerConfiguration config = PickerConfiguration.fromMap((Map) methodCall.arguments());
//    Log.d("config===", "===" + config);
    // 单独拍照
    PictureSelector.create(activity)
            .openCamera(PictureMimeType.ofImage())
            .imageEngine(GlideEngine.createGlideEngine())
            .isGif(false) // 是否显示GIF图片
            .isAndroidQTransform(true) // 是否需要处理Android Q 拷贝至应用沙盒的操作，只针对compress(false); && .isEnableCrop(false);有效,默认处理
            .maxSelectNum(config.maxImageCount) // 最大图片选择数量
            .isOriginalImageControl(config.allowPickingOriginalPhoto) // 是否显示原图控制按钮，如果设置为true则用户可以自由选择是否使用原图，压缩、裁剪功能将会失效
            .isCamera(config.allowTakePicture) // 是否显示拍照按钮
            .isEnableCrop(config.allowCrop) // 是否裁剪
            .withAspectRatio(1, 1) // 裁剪比例 如16:9 3:2 3:4 1:1 可自定义
//            .cropImageWideHigh(100, 100) // 裁剪宽高，设置如果大于图片本身宽高则无效
            .freeStyleCropEnabled(true) // 裁剪框是否可以拖拽
//            .circleDimmedLayer(false) // 是否圆形裁剪
//            .showCropGrid(false) // 是否显示裁剪矩形网格 圆形裁剪时建议设为false
            .scaleEnabled(true) // 裁剪是否可放大缩小图片
            .rotateEnabled(false) // 裁剪是否可旋转图片
            .isCompress(false) // 是否压缩
//            .compressQuality(80) // 图片压缩后输出质量 0 ~ 100
            .maxVideoSelectNum(config.maxImageCount) // 视频最大选择数量
            .videoMaxSecond(config.videoMaxDuration) // 查询多少秒以内的视频
            .recordVideoSecond(config.videoMaxDuration) // 录制视频秒数
//            .videoQuality(1) // 视频录制的质量 0 or 1
            .cutOutQuality(100) // 裁剪输出质量
            .minimumCompressSize(100) // 小于多少kb的图片不压缩
            .forResult(REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA);
  }

  private File createTemporaryWritableImageFile() {
    return createTemporaryWritableFile(".jpg");
  }

  private File createTemporaryWritableVideoFile() {
    return createTemporaryWritableFile(".mp4");
  }

  private File createTemporaryWritableFile(String suffix) {
    String filename = UUID.randomUUID().toString();
    File image;

    try {
      image = File.createTempFile(filename, suffix, externalFilesDirectory);
    } catch (IOException e) {
      throw new RuntimeException(e);
    }

    return image;
  }

  private void grantUriPermissions(Intent intent, Uri imageUri) {
    PackageManager packageManager = activity.getPackageManager();
    List<ResolveInfo> compatibleActivities =
        packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY);

    for (ResolveInfo info : compatibleActivities) {
      activity.grantUriPermission(
          info.activityInfo.packageName,
          imageUri,
          Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
    }
  }

  @Override
  public boolean onRequestPermissionsResult(
      int requestCode, String[] permissions, int[] grantResults) {
    boolean permissionGranted =
        grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;

    switch (requestCode) {
      case REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION:
        if (permissionGranted) {
          launchPickImageFromGalleryIntent();
        }
        break;
      case REQUEST_EXTERNAL_VIDEO_STORAGE_PERMISSION:
        if (permissionGranted) {
          launchPickVideoFromGalleryIntent();
        }
        break;
      case REQUEST_CAMERA_IMAGE_PERMISSION:
        if (permissionGranted) {
          launchTakeImageWithCameraIntent();
        }
        break;
      case REQUEST_CAMERA_VIDEO_PERMISSION:
        if (permissionGranted) {
          launchTakeVideoWithCameraIntent();
        }
        break;
      default:
        return false;
    }

    if (!permissionGranted) {
      switch (requestCode) {
        case REQUEST_EXTERNAL_IMAGE_STORAGE_PERMISSION:
        case REQUEST_EXTERNAL_VIDEO_STORAGE_PERMISSION:
          finishWithError("photo_access_denied", "The user did not allow photo access.");
          break;
        case REQUEST_CAMERA_IMAGE_PERMISSION:
        case REQUEST_CAMERA_VIDEO_PERMISSION:
          finishWithError("camera_access_denied", "The user did not allow camera access.");
          break;
      }
    }

    return true;
  }

  @Override
  public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
    switch (requestCode) {
      case REQUEST_CODE_CHOOSE_IMAGE_FROM_GALLERY:
        handleChooseImageResult(resultCode, data);
        break;
      case REQUEST_CODE_TAKE_IMAGE_WITH_CAMERA:
        handleCaptureImageResult(resultCode, data);
        break;
      case REQUEST_CODE_CHOOSE_VIDEO_FROM_GALLERY:
        handleChooseVideoResult(resultCode, data);
        break;
      case REQUEST_CODE_TAKE_VIDEO_WITH_CAMERA:
        handleCaptureVideoResult(resultCode);
        break;
      default:
        return false;
    }

    return true;
  }

  private void handleChooseImageResult(int resultCode, Intent data) {
    if (resultCode == Activity.RESULT_OK && data != null) {
//      String path = fileUtils.getPathFromUri(activity, data.getData());
//      handleImageResult(path, false);

        List<LocalMedia> selectList = PictureSelector.obtainMultipleResult(data);
        handleImageResults(selectList);
      return;
    }

    // User cancelled choosing a picture.
    finishWithSuccessPaths(null);
  }

  private void handleChooseVideoResult(int resultCode, Intent data) {
    if (resultCode == Activity.RESULT_OK && data != null) {
//      String path = fileUtils.getPathFromUri(activity, data.getData());
//      handleVideoResult(path);


      List<LocalMedia> selectList = PictureSelector.obtainMultipleResult(data);
      handleVideoResults(selectList);

      return;
    }

    // User cancelled choosing a picture.
    finishWithSuccessPaths(null);
  }

  private void handleCaptureImageResult(int resultCode, Intent data) {
    if (resultCode == Activity.RESULT_OK && data != null) {
      // 处理拍摄照片结果

      List<LocalMedia> selectList = PictureSelector.obtainMultipleResult(data);
      handleImageResults(selectList);
      return;
    }

    // User cancelled taking a picture.
    finishWithSuccessPaths(null);
  }

  private void handleCaptureVideoResult(int resultCode) {
    if (resultCode == Activity.RESULT_OK) {
      fileUriResolver.getFullImagePath(
          pendingCameraMediaUri != null
              ? pendingCameraMediaUri
              : Uri.parse(cache.retrievePendingCameraMediaUriPath()),
          new OnPathReadyListener() {
            @Override
            public void onPathReady(String path) {
//              handleVideoResult(path);
            }
          });
      return;
    }

    // User cancelled taking a picture.
    finishWithSuccessPaths(null);
  }

  private boolean setPendingMethodCallAndResult(
      MethodCall methodCall, MethodChannel.Result result) {
    if (pendingResult != null) {
      return false;
    }

    this.methodCall = methodCall;
    pendingResult = result;

    // Clean up cache if a new image picker is launched.
    cache.clear();

    return true;
  }

  private void finishWithAlreadyActiveError(MethodChannel.Result result) {
    result.error("already_active", "Image picker is already active", null);
  }

  private void finishWithError(String errorCode, String errorMessage) {
    if (pendingResult == null) {
      cache.saveResult(null, errorCode, errorMessage);
      return;
    }
    pendingResult.error(errorCode, errorMessage, null);
    clearMethodCallAndResult();
  }

  private void clearMethodCallAndResult() {
    methodCall = null;
    pendingResult = null;
  }

  private void useFrontCamera(Intent intent) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
      intent.putExtra(
          "android.intent.extras.CAMERA_FACING", CameraCharacteristics.LENS_FACING_FRONT);
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        intent.putExtra("android.intent.extra.USE_FRONT_CAMERA", true);
      }
    } else {
      intent.putExtra("android.intent.extras.CAMERA_FACING", 1);
    }
  }

  // 新增
  private void handleImageResults(List<LocalMedia> mediaList) {
//    Log.i("===handleImageResults", "====准备开始遍历======paths: " + mediaList);


    List<String> paths = new ArrayList<>();
    for (LocalMedia media : mediaList) {
      String path = media.getPath();
      if (media.isCompressed()) {
        path = media.getCompressPath();
      } else if (media.isCut()) {
        path = media.getCutPath();
      } else if (media.isOriginal()) {
        path = media.getOriginalPath();
      } else if (media.getAndroidQToPath() != null) {
        path = media.getAndroidQToPath();
      }
      Log.i("选择照片", "输出的路径==" + path);
      paths.add(path);
//      Log.i("选择照片", "是否压缩:" + media.isCompressed());
//      Log.i("选择照片", "压缩:" + media.getCompressPath());
//      Log.i("选择照片", "原图:" + media.getPath());
//      Log.i("选择照片", "是否裁剪:" + media.isCut());
//      Log.i("选择照片", "裁剪:" + media.getCutPath());
//      Log.i("选择照片", "是否开启原图:" + media.isOriginal());
//      Log.i("选择照片", "原图路径:" + media.getOriginalPath());
//      Log.i("选择照片", "Android Q 特有Path:" + media.getAndroidQToPath());
//      Log.i("选择照片", "宽高: " + media.getWidth() + "x" + media.getHeight());
//      Log.i("选择照片", "Size: " + media.getSize());
    }
    finishWithSuccessPaths(paths);
  }

  // 新增，用于处理Matisse返回的path数组
  private void finishWithSuccessPaths(List<String> imagePaths) {
//    if (imagePaths == null) {
//      return;
//    }
//    Log.i("=finishWithSuccessPaths", "=====准备开始判断=====imagePaths: " + imagePaths + "===pendingResult: " + pendingResult);

    if (pendingResult == null) {
//      Log.i("=finishWithSuccessPaths", "=====准备开始遍历=====imagePaths: " + imagePaths);

      for (String imagePath: imagePaths) {
//        Log.i("=finishWithSuccessPaths", "=====正在遍历=====imagePath: " + imagePath);

        cache.saveResult(imagePath, null, null);
      }
      return;
    }
//    Log.i("=finishWithSuccessPaths", "=====准备开始执行pendingResult.success=====imagePaths: " + imagePaths);

    pendingResult.success(imagePaths);
    clearMethodCallAndResult();
  }

  // 新增
  private void handleVideoResults(final List<LocalMedia> mediaList) {
//    Log.i("===handleImageResults", "====准备开始遍历======paths: " + mediaList);

        final List<Map> paths = new ArrayList<Map>();
        for (LocalMedia media : mediaList) {
          String path = media.getPath();
          if (media.isCompressed()) {
            path = media.getCompressPath();
          } else if (media.isCut()) {
            path = media.getCutPath();
          } else if (media.isOriginal()) {
            path = media.getOriginalPath();
          } else if (media.getAndroidQToPath() != null) {
            path = media.getAndroidQToPath();
          }
          Log.i("选择视频", "输出的路径==" + path);
          final Map asset = new HashMap();
          asset.put("videoPath", path);
          // 视频封面
          MediaMetadataRetriever mediaRetriever = new MediaMetadataRetriever();
          mediaRetriever.setDataSource(path);
          Bitmap bitmap = mediaRetriever.getFrameAtTime();
          String cover = imageResizer.resizeImageFromBitmap(bitmap);
          asset.put("coverPath", cover);
          paths.add(asset);
//      Log.i("选择照片", "是否压缩:" + media.isCompressed());
//      Log.i("选择照片", "压缩:" + media.getCompressPath());
//      Log.i("选择照片", "原图:" + media.getPath());
//      Log.i("选择照片", "是否裁剪:" + media.isCut());
//      Log.i("选择照片", "裁剪:" + media.getCutPath());
//      Log.i("选择照片", "是否开启原图:" + media.isOriginal());
//      Log.i("选择照片", "原图路径:" + media.getOriginalPath());
//      Log.i("选择照片", "Android Q 特有Path:" + media.getAndroidQToPath());
//      Log.i("选择照片", "宽高: " + media.getWidth() + "x" + media.getHeight());
//      Log.i("选择照片", "Size: " + media.getSize());

        }
        finishWithSuccessVideo(paths);
  }

  // 新增，用于处理Matisse返回的path数组
  private void finishWithSuccessVideo(List<Map> videoAssets) {
//    if (videoAssets == null) {
//      return;
//    }

    if (pendingResult == null) {
//      for (String imagePath: imagePaths) {
////        Log.i("=finishWithSuccessPaths", "=====正在遍历=====imagePath: " + imagePath);
//
//        cache.saveResult(imagePath, null, null);
//      }
      return;
    }

    pendingResult.success(videoAssets);
    clearMethodCallAndResult();
  }
}
