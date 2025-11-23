#import "WhisperKitPlugin.h"
#import "../src/main.h"
#import <Foundation/Foundation.h>

@interface WhisperKitPlugin (CPPIntegration)
@end

@implementation WhisperKitPlugin (CPPIntegration)

- (NSString *)processAudioWithModel:(NSString *)audioPath modelPath:(NSString *)modelPath options:(NSDictionary *)options {
    // Convert NSString to C strings
    const char *audioPathCStr = [audioPath UTF8String];
    const char *modelPathCStr = [modelPath UTF8String];

    // Create JSON request
    NSMutableDictionary *request = [NSMutableDictionary dictionary];
    request[@"model"] = modelPath;
    request[@"audio"] = audioPath;
    request[@"threads"] = options[@"threads"] ?: @(4);
    request[@"language"] = options[@"language"] ?: @"auto";
    request[@"is_verbose"] = options[@"isVerbose"] ?: @(NO);
    request[@"is_translate"] = options[@"isTranslate"] ?: @(NO);
    request[@"is_no_timestamps"] = options[@"isNoTimestamps"] ?: @(NO);
    request[@"is_special_tokens"] = options[@"isSpecialTokens"] ?: @(NO);
    request[@"split_on_word"] = options[@"splitOnWord"] ?: @(NO);

    // Convert to JSON string
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:request options:0 error:&jsonError];
    if (jsonError) {
        NSLog(@"JSON serialization error: %@", jsonError.localizedDescription);
        return nil;
    }

    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    const char *jsonCStr = [jsonString UTF8String];

    // Make a mutable copy for the C function
    char *jsonMutable = strdup(jsonCStr);

    // Call the C++ function
    char *result = request(jsonMutable);

    // Convert result back to NSString
    NSString *resultString = nil;
    if (result) {
        resultString = [NSString stringWithUTF8String:result];
        free(result); // Don't forget to free the allocated memory
    }

    free(jsonMutable);
    return resultString;
}

@end