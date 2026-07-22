#import <Foundation/Foundation.h>
#import <Sparkle/Sparkle.h>

@class SPUAppcastItemStateResolver;

@interface SUAppcast (CopyLassoArchitectureProof)
- (nullable instancetype)initWithXMLData:(NSData *)xmlData
                           relativeToURL:(nullable NSURL *)relativeURL
                           stateResolver:(nullable SPUAppcastItemStateResolver *)stateResolver
                 signingValidationStatus:(SPUAppcastSigningValidationStatus)signingValidationStatus
                                   error:(NSError *_Nullable *_Nullable)error;
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            return 64;
        }

        NSString *expectation = [NSString stringWithUTF8String:argv[1]];
        BOOL shouldParse = [expectation isEqualToString:@"accept"];
        if (!shouldParse && ![expectation isEqualToString:@"reject"]) {
            return 64;
        }

        NSString *path = [NSString stringWithUTF8String:argv[2]];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data == nil) {
            return 66;
        }

        NSError *error = nil;
        SUAppcast *appcast = [[SUAppcast alloc]
            initWithXMLData:data
              relativeToURL:[NSURL fileURLWithPath:path]
              stateResolver:nil
    signingValidationStatus:SPUAppcastSigningValidationStatusSucceeded
                      error:&error];
        if (shouldParse) {
            return appcast != nil && error == nil ? 0 : 1;
        }
        return appcast == nil && error != nil ? 0 : 1;
    }
}
