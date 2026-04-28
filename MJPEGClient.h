#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface MJPEGClient : NSObject
@property (nonatomic, readonly) CMSampleBufferRef latestSampleBuffer; // luôn có frame mới nhất
- (void)start;
- (void)stop;
@end