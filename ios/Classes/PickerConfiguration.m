//
//  PickerConfiguration.m
//  image_picker_controller
//
//  Created by ZhangYu on 2020/9/29.
//

#import "PickerConfiguration.h"

@implementation PickerConfiguration

+ (PickerConfiguration *)fromDictionary:(NSDictionary *)dict {
    PickerConfiguration *config = [[PickerConfiguration alloc] init];
    if (dict == nil) {
        return config;
    }
    
    if ([dict objectForKey:@"allowCrop"] != nil) {
        config.allowCrop = [dict objectForKey:@"allowCrop"];
    }
    
    if ([dict objectForKey:@"maxImageCount"] != nil) {
        config.maxImageCount = [[dict objectForKey:@"maxImageCount"] intValue];
    }
    if ([dict objectForKey:@"videoMaxDuration"] != nil) {
        config.videoMaxDuration = [[dict objectForKey:@"videoMaxDuration"] doubleValue];
    }
    if ([dict objectForKey:@"allowTakeVideo"] != nil) {
        config.allowTakeVideo = [dict objectForKey:@"allowTakeVideo"];
    }
    if ([dict objectForKey:@"allowTakePicture"] != nil) {
        config.allowTakePicture = [dict objectForKey:@"allowTakePicture"];
    }
    if ([dict objectForKey:@"allowPickingOriginalPhoto"] != nil) {
        config.allowPickingOriginalPhoto = [dict objectForKey:@"allowPickingOriginalPhoto"];
    }
    if ([dict objectForKey:@"allowPickingVideo"] != nil) {
        config.allowPickingVideo = [dict objectForKey:@"allowPickingVideo"];
    }
    if ([dict objectForKey:@"allowPickingImage"] != nil) {
        config.allowPickingImage = [dict objectForKey:@"allowPickingImage"];
    }
    
    return config;
}

@end
