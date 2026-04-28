#import "MJPEGClient.h"
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface MJPEGClient () {
    CVPixelBufferPoolRef _pool;
}
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, strong) NSMutableData *buffer;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, assign) CMSampleBufferRef latestSampleBuffer;
@end

@implementation MJPEGClient

- (instancetype)init {
    self = [super init];
    self.buffer = [NSMutableData data];
    return self;
}

- (void)start {
    if (self.running) return;
    self.running = YES;
    
    // Tạo pixel buffer pool (định dạng 32BGRA như camera thật)
    NSDictionary *poolAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(640),
        (id)kCVPixelBufferHeightKey: @(480),
        (id)kCVPixelBufferBytesPerRowAlignmentKey: @(64)
    };
    CVPixelBufferPoolCreate(NULL, NULL, (__bridge CFDictionaryRef)poolAttrs, &_pool);
    
    // Kết nối tới localhost:9999 (iproxy đã chuyển từ máy tính)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self connectAndReceive];
    });
}

- (void)connectAndReceive {
    // Tạo socket TCP đơn giản
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return;
    
    struct sockaddr_in server;
    server.sin_family = AF_INET;
    server.sin_port = htons(9999);
    inet_pton(AF_INET, "127.0.0.1", &server.sin_addr);
    
    if (connect(sock, (struct sockaddr *)&server, sizeof(server)) < 0) {
        close(sock);
        return;
    }
    
    // Gửi yêu cầu HTTP GET
    const char *req = "GET /video.mjpeg HTTP/1.1\r\nHost: 127.0.0.1:9999\r\nConnection: keep-alive\r\n\r\n";
    send(sock, req, strlen(req), 0);
    
    // Đọc dữ liệu từ socket
    uint8_t buf[8192];
    while (self.running) {
        ssize_t len = recv(sock, buf, sizeof(buf), 0);
        if (len <= 0) break;
        @synchronized (self.buffer) {
            [self.buffer appendBytes:buf length:len];
        }
        [self parseBuffer];
    }
    close(sock);
}

#define BOUNDARY "--myboundary"

- (void)parseBuffer {
    NSData *boundaryData = [BOUNDARY dataUsingEncoding:NSUTF8StringEncoding];
    @synchronized (self.buffer) {
        NSRange searchRange = NSMakeRange(0, self.buffer.length);
        while (searchRange.length > 0) {
            NSRange boundaryRange = [self.buffer rangeOfData:boundaryData options:0 range:searchRange];
            if (boundaryRange.location == NSNotFound) break;
            
            // Tìm vị trí bắt đầu JPEG sau header
            NSRange headerEnd = [self.buffer rangeOfData:[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:0
                                                    range:NSMakeRange(boundaryRange.location, self.buffer.length - boundaryRange.location)];
            if (headerEnd.location == NSNotFound) break;
            
            // Đọc Content-Length
            NSString *header = [[NSString alloc] initWithData:[self.buffer subdataWithRange:NSMakeRange(boundaryRange.location, headerEnd.location - boundaryRange.location)]
                                                     encoding:NSUTF8StringEncoding];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Content-Length: (\\d+)" options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:header options:0 range:NSMakeRange(0, header.length)];
            if (!match) {
                // không có Content-Length → bỏ qua chunk này
                NSUInteger consumed = boundaryRange.location + boundaryRange.length;
                [self.buffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
                searchRange = NSMakeRange(0, self.buffer.length);
                continue;
            }
            NSInteger contentLength = [[header substringWithRange:[match rangeAtIndex:1]] integerValue];
            NSUInteger jpegStart = headerEnd.location + headerEnd.length;
            if (jpegStart + contentLength > self.buffer.length) break; // chưa đủ dữ liệu
            
            NSData *jpegData = [self.buffer subdataWithRange:NSMakeRange(jpegStart, contentLength)];
            // Xóa phần đã xử lý
            NSUInteger consumed = jpegStart + contentLength;
            [self.buffer replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
            
            // Chuyển JPEG → CIImage → CVPixelBuffer → CMSampleBuffer
            CIImage *ciImage = [CIImage imageWithData:jpegData];
            if (ciImage) {
                [self updateSampleBufferWithCIImage:ciImage];
            }
            
            searchRange = NSMakeRange(0, self.buffer.length);
        }
    }
}

- (void)updateSampleBufferWithCIImage:(CIImage *)ciImage {
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _pool, &pixelBuffer);
    if (!pixelBuffer) return;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CIContext *context = [CIContext context];
    [context render:ciImage toCVPixelBuffer:pixelBuffer];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Tạo CMSampleBuffer từ pixel buffer
    CMSampleTimingInfo timing = { .duration = kCMTimeInvalid, .presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock()), .decodeTimeStamp = kCMTimeInvalid };
    CMVideoFormatDescriptionRef formatDesc;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &formatDesc);
    
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreateReadyWithImageBuffer(NULL, pixelBuffer, formatDesc, &timing, &sampleBuffer);
    
    CFRelease(formatDesc);
    CVPixelBufferRelease(pixelBuffer);
    
    // Cập nhật latestSampleBuffer (thread an toàn)
    @synchronized (self) {
        if (self.latestSampleBuffer) {
            CFRelease(self.latestSampleBuffer);
        }
        self.latestSampleBuffer = sampleBuffer;
    }
}

- (void)stop {
    self.running = NO;
    @synchronized (self) {
        if (self.latestSampleBuffer) {
            CFRelease(self.latestSampleBuffer);
            self.latestSampleBuffer = NULL;
        }
    }
}

- (void)dealloc {
    [self stop];
    if (_pool) CVPixelBufferPoolRelease(_pool);
}
@end