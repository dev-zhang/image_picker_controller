#import "ImagePickerControllerPlugin.h"
#import "TZImagePickerController.h"

static NSString *kPickImageMethod = @"pickImage";
static NSString *kPickVideoMethod = @"pickVideo";

@interface ImagePickerControllerPlugin() <TZImagePickerControllerDelegate>

@property(nonatomic, copy) FlutterResult flutterResult;
@property(nonatomic, assign) NSTimeInterval videoMaxDuration;

@end


@implementation ImagePickerControllerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"image_picker_controller"
                                     binaryMessenger:[registrar messenger]];
    ImagePickerControllerPlugin* instance = [[ImagePickerControllerPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    self.flutterResult = result;
    if ([kPickImageMethod isEqualToString:call.method]) {
        [self pickImages:call];
    } else if ([kPickVideoMethod isEqualToString:call.method]) {
        [self pickVideo:call];
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
    NSMutableArray<NSString *> *filePathArray = [NSMutableArray array];
    for (UIImage *image in photos) {
        NSString *path = [self saveImage:image];
        [filePathArray addObject: path];
    }
    self.flutterResult(filePathArray);
}

- (void)imagePickerController:(TZImagePickerController *)picker didFinishPickingVideo:(UIImage *)coverImage sourceAssets:(PHAsset *)asset {
    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetLowQuality success:^(NSString *outputPath) {
        NSLog(@"视频导出到本地已完成：%@", outputPath);
        self.flutterResult(outputPath);
    } failure:^(NSString *errorMessage, NSError *error) {
        NSLog(@"视频导出到本地失败：%@, %@", errorMessage, error);
    }];
}

- (NSString *)saveImage:(UIImage *)image {
    NSData *data = UIImagePNGRepresentation(image);
    NSDateFormatter *formater = [[NSDateFormatter alloc] init];
    [formater setDateFormat:@"yyyy-MM-dd-HH:mm:ss-SSS"];
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

@end
