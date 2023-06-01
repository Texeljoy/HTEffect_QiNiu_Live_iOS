//
//  PLPanelDelegateGenerator.m
//  PLCameraStreamingKitDemo
//
//  Created by TaoZeyu on 16/5/30.
//  Copyright © 2016年 Pili. All rights reserved.
//

#import "PLPanelDelegateGenerator.h"
#import "PLStreamingKitDemoUtils.h"
#import <BlocksKit/NSObject+A2DynamicDelegate.h>

//todo --- HTEffect start4 ---
#import <HTEffect/HTEffectInterface.h>
//todo --- HTEffect end ---

@implementation PLPanelDelegateGenerator
{
    PLMediaStreamingSession *_streamingSession;
    int _count;
    //todo --- HTEffect start ---
    BOOL _isRenderInit;
    //todo --- HTEffect end ---
}

- (instancetype)initWithMediaStreamingSession:(PLMediaStreamingSession *)streamingSession
{
    if (self = [self init]) {
        _streamingSession = streamingSession;
        _isDynamicWatermark = NO;
        _count = 1;
    }
    return self;
}

- (void)generate
{
    __weak typeof(self) wSelf = self;
    
    NSDictionary *streamStateDictionary = @{@(PLStreamStateUnknow):             @"Unknow",
                                            @(PLStreamStateConnecting):         @"Connecting",
                                            @(PLStreamStateConnected):          @"Connected",
                                            @(PLStreamStateDisconnecting):      @"Disconnecting",
                                            @(PLStreamStateDisconnected):       @"Disconnected",
                                            @(PLStreamStateAutoReconnecting):   @"AutoReconnecting",
                                            @(PLStreamStateError):              @"Error",
                                            };
    NSDictionary *authorizationDictionary = @{@(PLAuthorizationStatusNotDetermined):    @"NotDetermined",
                                              @(PLAuthorizationStatusRestricted):       @"Restricted",
                                              @(PLAuthorizationStatusDenied):           @"Denied",
                                              @(PLAuthorizationStatusAuthorized):       @"Authorized",
                                              };
    [PLDelgateHelper bindTarget:_streamingSession property:@"delegate" block:^(A2DynamicDelegate *d) {
        
        [d implementMethod:@selector(mediaStreamingSession:streamStateDidChange:) withBlock:^(PLMediaStreamingSession *session, PLStreamState state) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wSelf) strongSelf = wSelf;
                NSLog(@"%@", [NSString stringWithFormat:@"session state changed%@", streamStateDictionary[@(state)]]);
                if ([strongSelf.delegate respondsToSelector:@selector(panelDelegateGenerator:streamStateDidChange:)]) {
                    [strongSelf.delegate panelDelegateGenerator:strongSelf streamStateDidChange:state];
                }
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didDisconnectWithError:) withBlock:^(PLMediaStreamingSession *session, NSError *error){
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(wSelf) strongSelf = wSelf;
                NSLog(@"%@", [NSString stringWithFormat:@"session disconnected due to error %@", error]);
                if ([strongSelf.delegate respondsToSelector:@selector(panelDelegateGenerator:streamDidDisconnectWithError:)]) {
                    [strongSelf.delegate panelDelegateGenerator:strongSelf streamDidDisconnectWithError:error];
                }
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:streamStatusDidUpdate:) withBlock:^(PLMediaStreamingSession *session, PLStreamStatus *status){
            dispatch_async(dispatch_get_main_queue(), ^{
//                NSLog(@"%@", [NSString stringWithFormat:@"session status %@", status]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didGetCameraAuthorizationStatus:) withBlock:^(PLMediaStreamingSession *session, PLAuthorizationStatus authorizationStatus){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", [NSString stringWithFormat:@"camera authorization status changed %@", authorizationDictionary[@(authorizationStatus)]]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:didGetMicrophoneAuthorizationStatus:) withBlock:^(PLMediaStreamingSession *session, PLAuthorizationStatus authorizationStatus){
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"%@", [NSString stringWithFormat:@"microphone  authorization status changed %@", authorizationDictionary[@(authorizationStatus)]]);
            });
        }];
        [d implementMethod:@selector(mediaStreamingSession:cameraSourceDidGetPixelBuffer:) withBlock:^CVPixelBufferRef(PLMediaStreamingSession *session, CVPixelBufferRef pixelBuffer) {
              
            //todo --- HTEffect start6 ---
            CVPixelBufferLockBaseAddress(pixelBuffer, 0);
            unsigned char *baseAddress = (unsigned char *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            
            // 视频帧格式
            HTFormatEnum format;
            switch (CVPixelBufferGetPixelFormatType(pixelBuffer)) {
                case kCVPixelFormatType_32BGRA:
                    format = HTFormatBGRA;
                    break;
                case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
                case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                    format = HTFormatNV12;
                    break;
                default:
                    NSLog(@"错误的视频帧格式！");
                    format = HTFormatBGRA;
                    break;
            }
            
            int imageWidth, imageHeight;
            if (format == HTFormatBGRA) {
                imageWidth = (int)CVPixelBufferGetBytesPerRow(pixelBuffer) / 4;
                imageHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
            } else {
                imageWidth = (int)CVPixelBufferGetWidthOfPlane(pixelBuffer , 0);
                imageHeight = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer , 0);
            }
            
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            
            if (!_isRenderInit) {
                [[HTEffect shareInstance] releaseBufferRenderer];
                _isRenderInit = [[HTEffect shareInstance] initBufferRenderer:format width:imageWidth height:imageHeight rotation:HTRotationClockwise90 isMirror:YES maxFaces:5];
            }
            
            [[HTEffect shareInstance] processBuffer:baseAddress];
            //todo --- HTEffect end ---
            
            
            if (_isDynamicWatermark) {
                ++_count;
                if (_count == 9) {
                    _count = 1;
                }
                NSString *name = [NSString stringWithFormat:@"ear_00%d.png", _count];
                UIImage *waterMark = [UIImage imageNamed:name];
                [session clearWaterMark];
                [session setWaterMarkWithImage:waterMark position:CGPointMake(10, 100)];
            }
            
            return pixelBuffer;
        }];
    }];
}



@end
