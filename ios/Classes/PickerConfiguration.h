//
//  PickerConfiguration.h
//  image_picker_controller
//
//  Created by ZhangYu on 2020/9/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PickerConfiguration : NSObject

@property(nonatomic, assign) BOOL allowCrop;
@property(nonatomic, assign) int maxImageCount;
@property(nonatomic, assign) NSTimeInterval videoMaxDuration;
@property(nonatomic, assign) BOOL allowTakeVideo;
@property(nonatomic, assign) BOOL allowTakePicture;

@property(nonatomic, assign) BOOL allowPickingOriginalPhoto;
@property(nonatomic, assign) BOOL allowPickingVideo;
@property(nonatomic, assign) BOOL allowPickingImage;

+ (instancetype)fromDictionary:(NSDictionary *)dict;


@end

NS_ASSUME_NONNULL_END
