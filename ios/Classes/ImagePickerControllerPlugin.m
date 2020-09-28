#import "ImagePickerControllerPlugin.h"
#import "TZImagePickerController.h"
#import <Photos/Photos.h>
#import <MobileCoreServices/MobileCoreServices.h>

static NSString *kPickImageMethod = @"pickImage";
static NSString *kPickVideoMethod = @"pickVideo";
// 选择单个图片
static NSString *kPickSingleImageMethod = @"pick_single_image";
// 拍摄图片
static NSString *kTakeImageMethod = @"take_image";

@interface ImagePickerControllerPlugin() <TZImagePickerControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property(nonatomic, copy) FlutterResult flutterResult;
@property(nonatomic, strong) FlutterMethodCall *flutterCall;
@property(nonatomic, assign) NSTimeInterval videoMaxDuration;
@property(nonatomic, assign) BOOL isSinglePickMode;
@property(nonatomic, strong) UIImagePickerController *imagePickerVc;
@property(nonatomic, strong) CLLocation *location;

@end


@implementation ImagePickerControllerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"com.xiamijun.image_picker_controller"
                                     binaryMessenger:[registrar messenger]];
    ImagePickerControllerPlugin* instance = [[ImagePickerControllerPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    self.flutterResult = result;
    self.flutterCall = call;
    self.isSinglePickMode = false;
    if ([kPickImageMethod isEqualToString:call.method]) {
        [self pickImages:call];
    } else if ([kPickVideoMethod isEqualToString:call.method]) {
        [self pickVideo:call];
    } else if ([kPickSingleImageMethod isEqualToString:call.method]) {
        // 选择单个图片
        self.isSinglePickMode = true;
        [self pickImages:call];
    } else if ([kTakeImageMethod isEqualToString:call.method]) {
        // 拍摄照片
        self.isSinglePickMode = true;
        [self takePhoto];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (void)pickImages:(FlutterMethodCall *)call {
    int maxImageCount = 1;
    if (call.arguments != nil && call.arguments[@"maxImageCount"] != nil) {
        maxImageCount = [call.arguments[@"maxImageCount"] intValue];
    }
    
    TZImagePickerController *imagePickerVC = [[TZImagePickerController alloc] initWithMaxImagesCount:maxImageCount delegate:self];
    imagePickerVC.allowPickingVideo = false;
    imagePickerVC.allowTakeVideo = false;
    
    BOOL allowCrop = false;
    if (call.arguments != nil && call.arguments[@"allowCrop"] != nil) {
        allowCrop = [call.arguments[@"allowCrop"] boolValue];
    }
    
    imagePickerVC.allowCrop = allowCrop;
    
    if (@available(iOS 13.0, *)) {
        imagePickerVC.modalInPresentation = true;
    }
    imagePickerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *topVC = [self topViewController:nil];
    [topVC presentViewController:imagePickerVC animated:true completion:nil];
}


- (void)pickVideo:(FlutterMethodCall *)call {
    int maxImageCount = 1;
    NSTimeInterval videoMaxDuration = 10 * 60;
    if (call.arguments != nil && call.arguments[@"videoMaxDuration"] != nil) {
        videoMaxDuration = [call.arguments[@"videoMaxDuration"] doubleValue];
    }
    self.videoMaxDuration = videoMaxDuration;
    
    BOOL allowTakeVideo = true;
    if (call.arguments != nil && call.arguments[@"allowTakePicture"] != nil) {
        allowTakeVideo = [call.arguments[@"allowTakePicture"] boolValue];
    }
    
    
    TZImagePickerController *imagePickerVC = [[TZImagePickerController alloc] initWithMaxImagesCount:maxImageCount delegate:self];
    
    imagePickerVC.videoMaximumDuration = videoMaxDuration;
    imagePickerVC.allowPickingImage = false;
    imagePickerVC.allowTakeVideo = allowTakeVideo;
    imagePickerVC.allowPickingVideo = true;
    [imagePickerVC setUiImagePickerControllerSettingBlock:^(UIImagePickerController *imagePickerController) {
        // 视频拍摄的质量
        imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
    }];
    
    if (@available(iOS 13.0, *)) {
        imagePickerVC.modalInPresentation = true;
    }
    imagePickerVC.modalPresentationStyle = UIModalPresentationFullScreen;
    UIViewController *topVC = [self topViewController:nil];
    [topVC presentViewController:imagePickerVC animated:true completion:nil];
}

- (BOOL)isAssetCanSelect:(PHAsset *)asset {
    if (asset.mediaType != PHAssetMediaTypeVideo) {
        return true;
    }
    // 根据视频时长，过滤视频资源
    if (self.videoMaxDuration != 0 && asset.duration > self.videoMaxDuration) {
        return false;
    }
    return true;
}

- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingPhotos:(NSArray<UIImage *> *)photos sourceAssets:(NSArray *)assets isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto {
    [picker showProgressHUD];
    NSMutableArray<NSString *> *filePathArray = [NSMutableArray array];
    if (isSelectOriginalPhoto) {
        // 原图
        dispatch_group_t group = dispatch_group_create();
        for (int i = 0; i < assets.count; i++) {
            [filePathArray addObject:@""];
            dispatch_group_enter(group);
            [[TZImageManager manager] getOriginalPhotoWithAsset:assets[i] newCompletion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
                if (!isDegraded) {
                    // 原图
                    NSString *path = [self saveImage:photo];
                    // 修复顺序问题
                    //                    [filePathArray addObject:path];
                    filePathArray[i] = path;
                    dispatch_group_leave(group);
                }
            }];
        }
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            [picker hideProgressHUD];
            if (self.isSinglePickMode) {
                self.flutterResult(filePathArray.firstObject);
            } else {
                self.flutterResult(filePathArray);
            }
        });
    } else {
        for (UIImage *image in photos) {
            NSString *path = [self saveImage:image];
            [filePathArray addObject: path];
        }
        [picker hideProgressHUD];
        if (self.isSinglePickMode) {
            self.flutterResult(filePathArray.firstObject);
        } else {
            self.flutterResult(filePathArray);
        }
    }
}

- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(PHAsset *)asset {
    [picker showProgressHUD];
    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetHighestQuality success:^(NSString *outputPath) {
        NSLog(@"视频导出到本地已完成：%@", outputPath);
        NSString *coverPath = [self saveImage:coverImage];
        NSDictionary *dict = @{
            @"videoPath": outputPath,
            @"coverPath": coverPath,
        };
        [picker hideProgressHUD];
        self.flutterResult(dict);
    } failure:^(NSString *errorMessage, NSError *error) {
        NSLog(@"视频导出到本地失败：%@, %@", errorMessage, error);
        [picker hideProgressHUD];
    }];
}

#pragma mark - UIImagePickerController

- (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
        // 无相机权限 做一个友好的提示
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        [[self topViewController:nil] presentViewController:alertController animated:YES completion:nil];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self takePhoto];
                });
            }
        }];
        // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }]];
        UIViewController *topVC = [self topViewController:nil];
        [topVC presentViewController:alertController animated:YES completion:nil];
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
        [[TZImageManager manager] requestAuthorizationWithCompletion:^{
            [self takePhoto];
        }];
    } else {
        [self pushImagePickerController];
    }
}

// 调用相机
- (void)pushImagePickerController {
    // 提前定位
    __weak typeof(self) weakSelf = self;
    [[TZLocationManager manager] startLocationWithSuccessBlock:^(NSArray<CLLocation *> *locations) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.location = [locations firstObject];
    } failureBlock:^(NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.location = nil;
    }];
    
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
        self.imagePickerVc.sourceType = sourceType;
        NSMutableArray *mediaTypes = [NSMutableArray array];
        [mediaTypes addObject:(NSString *)kUTTypeImage];
        if (mediaTypes.count) {
            _imagePickerVc.mediaTypes = mediaTypes;
        }
        UIViewController *topVC = [self topViewController:nil];
        [topVC presentViewController:_imagePickerVc animated:YES completion:nil];
    } else {
        NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
}

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    
    TZImagePickerController *tzImagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:self];
    [tzImagePickerVc showProgressHUD];
    if ([type isEqualToString:@"public.image"]) {
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSDictionary *meta = [info objectForKey:UIImagePickerControllerMediaMetadata];
        // save photo and get asset / 保存图片，获取到asset
        [[TZImageManager manager] savePhotoWithImage:image meta:meta location:self.location completion:^(PHAsset *asset, NSError *error){
            [tzImagePickerVc hideProgressHUD];
            if (error) {
                NSLog(@"图片保存失败 %@",error);
            } else {
                TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
                
                BOOL allowCrop = false;
                FlutterMethodCall *call = self.flutterCall;
                if (call.arguments != nil && call.arguments[@"allowCrop"] != nil) {
                    allowCrop = [call.arguments[@"allowCrop"] boolValue];
                }

                if (allowCrop) { // 允许裁剪,去裁剪
                    TZImagePickerController *imagePicker = [[TZImagePickerController alloc] initCropTypeWithAsset:assetModel.asset photo:image completion:^(UIImage *cropImage, id asset) {
                        NSString *path = [self saveImage:cropImage];
                        self.flutterResult(path);
                    }];
                    imagePicker.allowPickingImage = YES;
//                    UIViewController *topVC = [self topViewController:nil];
                    UIViewController *topVC = [UIApplication sharedApplication].delegate.window.rootViewController;
                    [topVC presentViewController:imagePicker animated:YES completion:nil];
                } else {
                    NSString *path = [self saveImage:image];
                    self.flutterResult(path);
                }
            }
        }];
    } else if ([type isEqualToString:@"public.movie"]) {
        NSURL *videoUrl = [info objectForKey:UIImagePickerControllerMediaURL];
        if (videoUrl) {
            [[TZImageManager manager] saveVideoWithUrl:videoUrl location:self.location completion:^(PHAsset *asset, NSError *error) {
                [tzImagePickerVc hideProgressHUD];
                if (!error) {
                    TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
                    [[TZImageManager manager] getPhotoWithAsset:assetModel.asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
                        if (!isDegraded && photo) {
                            // TODO:
                        }
                    }];
                }
            }];
        }
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if ([picker isKindOfClass:[UIImagePickerController class]]) {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

- (NSString *)saveImage:(UIImage *)image {
    NSData *data = UIImagePNGRepresentation(image);
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy-MM-dd-HH-mm-ss-SSS"];
    NSString *outputPath = [NSHomeDirectory() stringByAppendingFormat:@"/tmp/image-%@.jpg", [formater stringFromDate:[NSDate date]]];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[NSHomeDirectory() stringByAppendingFormat:@"/tmp"] withIntermediateDirectories:YES attributes:nil error:nil];
    }
    bool result = [data writeToFile:outputPath atomically:true];
    if (result) {
        return  outputPath;
    } else {
        return nil;
    }
}

- (UIViewController *)topViewController:(UIViewController *)base {
    if (!base) {
        base = [UIApplication sharedApplication].keyWindow.rootViewController;
    }
    if (base.presentedViewController) {
        return [self topViewController:base.presentedViewController];
    }
    return base;
}

- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
        // set appearance / 改变相册选择页的导航栏外观
        UIViewController *topVC = [self topViewController:nil];
        _imagePickerVc.navigationBar.barTintColor = topVC.navigationController.navigationBar.barTintColor;
        _imagePickerVc.navigationBar.tintColor = topVC.navigationController.navigationBar.tintColor;
        UIBarButtonItem *tzBarItem, *BarItem;
        if (@available(iOS 9, *)) {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[TZImagePickerController class]]];
            BarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIImagePickerController class]]];
        } else {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedIn:[TZImagePickerController class], nil];
            BarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
        }
        NSDictionary *titleTextAttributes = [tzBarItem titleTextAttributesForState:UIControlStateNormal];
        [BarItem setTitleTextAttributes:titleTextAttributes forState:UIControlStateNormal];
 
    }
    return _imagePickerVc;
}

@end
