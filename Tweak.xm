#import <AVFoundation/AVFoundation.h>
#import <substrate.h>
#import <notify.h>
#import "MJPEGClient.h"

static MJPEGClient *mjpegClient = nil;
static BOOL virtualCamEnabled = NO;

// Hàm nhận lệnh bật/tắt từ app
static void handleToggle(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    virtualCamEnabled = !virtualCamEnabled;
    if (virtualCamEnabled) {
        if (!mjpegClient) mjpegClient = [[MJPEGClient alloc] init];
        [mjpegClient start];
    } else {
        [mjpegClient stop];
    }
}

// Hook vào phương thức delegate của AVCaptureVideoDataOutput
// Chúng ta sẽ hook setSampleBufferDelegate:queue: để bắt delegate gốc, sau đó hook callback của delegate đó.

static void (*original_setDelegate)(id, SEL, id, dispatch_queue_t);
static void replaced_setDelegate(id self, SEL _cmd, id delegate, dispatch_queue_t queue) {
    // Gọi gốc
    original_setDelegate(self, _cmd, delegate, queue);
    
    // Nếu virtualCamEnabled và delegate tồn tại, ta hook callback của nó
    if (virtualCamEnabled && delegate) {
        // Kiểm tra xem delegate có phương thức captureOutput:didOutputSampleBuffer:fromConnection: không
        if ([delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            // Lưu lại implementation gốc nếu chưa hook
            // Sử dụng MSHookMessageEx để hook instance method của delegate
            static void (*orig_callback)(id, SEL, AVCaptureOutput *, CMSampleBufferRef, AVCaptureConnection *);
            if (!orig_callback) {
                MSHookMessageEx([delegate class], @selector(captureOutput:didOutputSampleBuffer:fromConnection:),
                                (IMP)&replaced_callback, (IMP*)&orig_callback);
            }
        }
    }
}

// Callback thay thế
static void replaced_callback(id self, SEL _cmd, AVCaptureOutput *output, CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection) {
    if (virtualCamEnabled) {
        // Thay sampleBuffer bằng frame mới nhất từ MJPEGClient
        CMSampleBufferRef newBuffer = nil;
        @synchronized (mjpegClient) {
            newBuffer = mjpegClient.latestSampleBuffer;
            if (newBuffer) CFRetain(newBuffer);
        }
        if (newBuffer) {
            sampleBuffer = newBuffer; // ghi đè
        }
    }
    // Gọi callback gốc với sampleBuffer (có thể đã thay đổi)
    if (orig_callback) {
        orig_callback(self, _cmd, output, sampleBuffer, connection);
    }
}

%ctor {
    // Đăng ký Darwin notification từ app
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    handleToggle,
                                    CFSTR("com.yourcompany.cam2obs.vcam.toggle"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    // Hook setSampleBufferDelegate:queue: của AVCaptureVideoDataOutput
    MSHookMessageEx([AVCaptureVideoDataOutput class], @selector(setSampleBufferDelegate:queue:),
                    (IMP)&replaced_setDelegate, (IMP*)&original_setDelegate);
    
    // Khởi tạo client (chưa start)
    mjpegClient = [[MJPEGClient alloc] init];
}