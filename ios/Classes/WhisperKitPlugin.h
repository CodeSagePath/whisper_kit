#import <Flutter/Flutter.h>

#if __has_include(<whisper_kit/whisper_kit-Swift.h>)
#import <whisper_kit/whisper_kit-Swift.h>
#else
// Support project import fallback
#if __has_include("whisper_kit-Swift.h")
#import "whisper_kit-Swift.h"
#else
@import whisper_kit.Swift;
#endif
#endif

@interface WhisperKitPlugin : NSObject<FlutterPlugin>
@end