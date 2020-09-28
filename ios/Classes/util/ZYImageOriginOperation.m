//
//  ZYImageOriginOperation.m
//  image_picker_controller
//
//  Created by ZhangYu on 2020/9/28.
//

#import "ZYImageOriginOperation.h"
#import <TZImagePickerController/TZImageManager.h>

@implementation ZYImageOriginOperation

- (void)start {
    NSLog(@"ZYImageOriginOperation start");
    self.executing = YES;
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//
//    });
    
    [[TZImageManager manager] getOriginalPhotoWithAsset:self.asset newCompletion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        NSLog(@"completion:=======%d", isDegraded);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!isDegraded) {
                NSLog(@"isDegraded is false: %d", isDegraded);
                if (self.completedBlock) {
                    self.completedBlock(photo, info, isDegraded);
                }
                [self done];
            }
        });
    }];
}

- (void)done {
    [super done];
    NSLog(@"ZYImageOriginOperation done");
}
@end
