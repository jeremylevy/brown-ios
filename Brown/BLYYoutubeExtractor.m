//
//  BLYYoutubeExtractor.m
//  Brown
//
//  Created by Jeremy Levy on 03/12/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <JavaScriptCore/JavaScriptCore.h>
#import <XCDYouTubeKit/XCDYouTubeClient.h>
#import "BLYYoutubeExtractor.h"
#import "BLYHTTPConnection.h"
#import "NSString+Escaping.h"
#import "NSString+Matching.h"
#import "NSString+Sizing.h"
#import "BLYStore.h"
#import "BLYVideo.h"
#import "BLYVideoStore.h"
#import "BLYFileManager.h"
#import "BLYHTTPConnection.h"

NSString * const BLYYoutubeExtractorWatchURLPattern = @"http://www.youtube.com/watch?v=%@";
NSString * const BLYYoutubeExtractorGetVideoInfoURLPattern = @"https://www.youtube.com/get_video_info?&video_id=%@&el=embedded&ps=default&eurl=";
NSString * const BLYYoutubeExtractorWatchURLUserAgent = @"Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)";
NSString * const BLYYoutubeExtractorLastCachedJsFile = @"BLYYoutubeExtractorLastCachedJsFile";
NSString * const BLYYoutubeExtractorLastDecodeSigFuncName = @"BLYYoutubeExtractorLastDecodeSigFuncName";

@implementation NSString (NSString_Extended)

- (NSString *)urlencode {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    unsigned long sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

- (NSString *)urldecode
{
    NSString *result = [(NSString *)self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByRemovingPercentEncoding];
    return result;
}

@end

@interface BLYYoutubeExtractor ()

@property (strong, nonatomic) NSArray *supportedItags;

@end

@implementation BLYYoutubeExtractor

- (id)init
{
    self = [super init];
    
    if (self) {
        _supportedItags = [[BLYVideoStore sharedStore] supportedItags];
    }
    
    return self;
}

- (NSURL *)watchURLForVideoWithID:(NSString *)videoID
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYYoutubeExtractorWatchURLPattern, videoID];
    
    return [NSURL URLWithString:url];
}

- (NSURL *)videoInfoUrlForVideoWithID:(NSString *)videoID
{
    videoID = [videoID bly_stringByAddingPercentEscapesForQuery];
    
    NSString *url = [NSString stringWithFormat:BLYYoutubeExtractorGetVideoInfoURLPattern, videoID];
    
    return [NSURL URLWithString:url];
}

- (void)urlsForVideo:(BLYVideo *)video
        inBackground:(BOOL)inBackground
  andCompletionBlock:(void(^)(NSArray *, NSError *))completionBlock
{
    NSURL *watchURL = [self watchURLForVideoWithID:video.sid];
    
    void(^extractPlayerConfigCompletionBlock)(NSDictionary*, NSError*) = ^(NSDictionary *playerConfig, NSError *error) {
        if (error) {
            return completionBlock(nil, error);
        }
        
        NSArray *URLs = playerConfig[@"URLs"];
        
        completionBlock(URLs, nil);
    };
    
    [self extractPlayerConfigArgumentsForVideo:video
                                  withWatchUrl:watchURL
                                  inBackground:inBackground
                            andCompletionBlock:extractPlayerConfigCompletionBlock];
}

- (void)extractPlayerConfigArgumentsForVideo:(BLYVideo *)video
                                withWatchUrl:(NSURL *)watchURL
                                inBackground:(BOOL)inBackground
                          andCompletionBlock:(void(^)(NSDictionary *, NSError *))completionBlock
{
//    NSString *finalWatchURL = [@"https://app-7d6f71f6-b0cd-47aa-9f16-7de290b81ef0.cleverapps.io/video-info?url=" stringByAppendingString:[[watchURL absoluteString] bly_stringByAddingPercentEscapesForQuery]];
//    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:finalWatchURL]
//                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
//                                                   timeoutInterval:[[BLYVideoStore sharedStore] fetchVideoRequestTimeout] * 1.0];
//
//    // Set user agent to avoid redirection to YouTube mobile site
//    //[req setValue:BLYYoutubeExtractorWatchURLUserAgent forHTTPHeaderField:@"User-Agent"];
//
//    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:[req copy]];
//
//    connection.displayActivityIndicator = !inBackground;
//
//    if (!inBackground) {
//        // Add to shared connection list to display ui activity indicator
//        [connection addSharedConnection:connection];
//    }
    
    [[XCDYouTubeClient defaultClient] getVideoWithIdentifier:video.sid completionHandler:^(XCDYouTubeVideo *video, NSError *error) {
        
        NSMutableDictionary *playerConfig = [[NSMutableDictionary alloc] init];
        
        if (!error) {
            [playerConfig setObject:[[NSMutableDictionary alloc] init]
                             forKey:@"URLs"];
            
            NSDictionary *videoUrls = video.streamURLs;
            NSMutableArray *URLs = [[NSMutableArray alloc] init];
            
            for (NSNumber *itag in videoUrls) {
                if (![self.supportedItags containsObject:itag]) {
                    continue;
                }

                [URLs addObject:[videoUrls[itag] absoluteString]];
            }
            
            playerConfig[@"URLs"] = URLs;
        }
        
        completionBlock([playerConfig copy], error);
        
//        if (!inBackground) {
//            [connection destroyCurrentConnection];
//        }
    }];
    
    // In order to keep Youtube extractor object alive don't use weakSelf in this block !
//    [connection setCompletionBlock:^(NSData *obj, NSError *error) {
//        NSMutableDictionary *playerConfig = [[NSMutableDictionary alloc] init];
//        
//        if (!error) {
//            NSDictionary *info = [NSJSONSerialization JSONObjectWithData:obj
//                                                                  options:0
//                                                                    error:&error];
//            
//            if (error) {
//                return completionBlock(nil, error);
//            }
//            
//            [playerConfig setObject:[[NSMutableDictionary alloc] init]
//                             forKey:@"URLs"];
//            
////            NSDictionary * (^parseQueryString)(NSString *, BOOL) = ^ NSDictionary * (NSString *URL, BOOL removePercentEscape){
////                NSMutableDictionary *URLArgs = [[NSMutableDictionary alloc] init];
////                
////                for (NSString *arg in [[URL componentsSeparatedByString:@"?"][1] componentsSeparatedByString:@"&"]) {
////                    NSMutableArray *args = [[arg componentsSeparatedByString:@"="] mutableCopy];
////                    id key = [args objectAtIndex:0];
////                    
////                    if ([args count] != 2) {
////                        continue;
////                    }
////                    
////                    id value = [args objectAtIndex:1];
////                    
////                    if ([value isKindOfClass:[NSString class]]) {
////                        value = [value bly_stringByRemovingPercentEscapes];
////                    }
////                    
////                    [URLArgs setObject:value forKey:key];
////                }
////                
////                return [URLArgs copy];
////            };
//            
////            void(^parseEncodedFmtStreamMap)(void) = ^{
////                NSArray *videoFormats = d[@"info"][@"formats"];
////                NSMutableArray *URLs = [[NSMutableArray alloc] init];
////                
////                for (NSDictionary *videoFormat in videoFormats) {
////                    NSNumber *itagAsNumber = [NSNumber numberWithInt:[videoFormat[@"format_id"] intValue]];
////                    
////                    if (![self.supportedItags containsObject:itagAsNumber]) {
////                        continue;
////                    }
////                    
////                    [URLs addObject:[@"https://peaceful-tor-37353.herokuapp.com/proxy?url=" stringByAppendingString: [[videoFormat[@"url"] urldecode] urlencode]]];
////                }
////                
////                playerConfig[@"URLs"] = URLs;
////                
////                if (info[@"uploader"]
////                    && [info[@"uploader"] isKindOfClass:[NSString class]]) {
////                    
////                    BOOL isVevo = [info[@"uploader"] hasSuffix:@"VEVO"] || [info[@"uploader"] hasSuffix:@"vevo"];
////                    
////                    [[BLYVideoStore sharedStore] setIsVevo:isVevo
////                                                  forVideo:video];
////                }
////            };
//            
//            playerConfig[@"URLs"] = info[@"urls"];
//            
//            if (info[@"uploader"]
//                && [info[@"uploader"] isKindOfClass:[NSString class]]) {
//                
//                BOOL isVevo = [info[@"uploader"] hasSuffix:@"VEVO"] || [info[@"uploader"] hasSuffix:@"vevo"];
//                
//                [[BLYVideoStore sharedStore] setIsVevo:isVevo
//                                              forVideo:video];
//            }
//            
//            // parseEncodedFmtStreamMap();
//        }
//        
//        completionBlock([playerConfig copy], error);
//    }];
//    
//    //[self cleanYoutubeWebsiteCookies];
//    
//    [connection start];
}

- (void)cleanYoutubeWebsiteCookies
{
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = cookieStorage.cookies;
    
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.domain rangeOfString:@"youtube"].location == NSNotFound) {
            continue;
        }
        
        [cookieStorage deleteCookie:cookie];
    }
}

- (void)decodeSignatures:(NSMutableArray *)signatures
            forHTML5File:(NSString *)HTML5File
            inBackground:(BOOL)inBackground
     withCompletionBlock:(void(^)(NSMutableArray *, NSError *))completionBlock
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *cacheDirectory = [[BLYStore sharedStore] cacheDirectory];
    
    NSArray *HTML5FileURLParts = [HTML5File componentsSeparatedByString:@"/"];
    NSString *HTML5Filename = [HTML5FileURLParts lastObject];
    NSString *HTML5FilePath = [cacheDirectory stringByAppendingString:[NSString stringWithFormat:@"/%@", HTML5Filename]];
    
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    
    NSString *lastCachedJSFile = [userDefaults stringForKey:BLYYoutubeExtractorLastCachedJsFile];
    BOOL HTML5FileIsCached = [defaultFileManager fileExistsAtPath:HTML5FilePath];
    
    // App installed before 1.01 update
    BOOL installedBeforeUpdate = HTML5FileIsCached && !lastCachedJSFile;
    
    if (installedBeforeUpdate) {
        HTML5FileIsCached = NO;
        lastCachedJSFile = HTML5FilePath;
    }
    
    void(^HTML5FileCompletion)(NSData *, NSError *) = ^(NSData *obj, NSError *error) {
        NSMutableArray *_signatures = [signatures mutableCopy];
        void(^hookedCompletionBlock)(NSMutableArray *, NSError *) = ^(NSMutableArray *a, NSError *e){
            if (!inBackground) {
                return completionBlock(a, e);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(a, e);
            });
        };
        
        if (!error) {
            NSString *data = [[NSString alloc] initWithData:obj
                                                   encoding:NSUTF8StringEncoding];
            
            if (data) {
                NSString *decodeFunctionName = [userDefaults stringForKey:BLYYoutubeExtractorLastDecodeSigFuncName];
                NSArray *matches = nil;
                
                if (!decodeFunctionName) {
                    NSRegularExpression *decodeFunctionNameReg = [[NSRegularExpression alloc] initWithPattern:@"signature=([$A-Z_][0-9A-Z_$]*)"
                                                                                                      options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                                                        error:nil];
                    
                    matches = [decodeFunctionNameReg matchesInString:data
                                                             options:0
                                                               range:[data bly_fullRange]];
                }
                
                if (decodeFunctionName || [matches count] > 0) {
                    NSTextCheckingResult *result = nil;
                    
                    if (!decodeFunctionName) {
                        result = [matches objectAtIndex:0];
                    }
                    
                    if (decodeFunctionName || [result numberOfRanges] >= 2) {
                        if (!decodeFunctionName) {
                            NSRange r = [result rangeAtIndex:1];
                            
                            decodeFunctionName = [data substringWithRange:r];
                        }
                        
                        if (!HTML5FileIsCached) {
                            // Remove IIFE (Immediately-Invoked Function Expression) to populate global context
                            data = [data bly_stringByReplacingPattern:@"^\\s*(\\(|!)\\s*function\\s*\\(\\s*\\)\\s*\\{"
                                                           withString:@""];
                            data = [data bly_stringByReplacingPattern:@"\\}\\s*\\)\\s*\\(\\s*\\)\\s*;?\\s*$"
                                                           withString:@""];
                            
                            [data writeToFile:HTML5FilePath
                                   atomically:YES
                                     encoding:NSUTF8StringEncoding
                                        error:&error];
                            
                            if (error) {
                                return completionBlock(nil, error);
                            }
                            
                            [userDefaults setObject:HTML5FilePath
                                             forKey:BLYYoutubeExtractorLastCachedJsFile];
                            [userDefaults setObject:decodeFunctionName
                                             forKey:BLYYoutubeExtractorLastDecodeSigFuncName];
                            [userDefaults synchronize];
                        }
                        
                        JSContext *context = [[JSContext alloc] init];
                        
                        // UIWebView *webView = [[UIWebView alloc] init];
                        // NSString *webViewJSCall = [NSString stringWithFormat:@"%@;%@(\"%@\");", data, decodeFunctionName, signature];
                        
                        // _signature = [webView stringByEvaluatingJavaScriptFromString:webViewJSCall];
                        
                        [context evaluateScript:@"var window = {}; var document = {};"];
                        [context evaluateScript:data];
                        
                        JSValue *decodeFunction = context[decodeFunctionName];
                        int index = 0;
                        
                        for (NSArray *signature in signatures) {
                            NSString *urlAsString = [signature objectAtIndex:0];
                            NSString *signatureAsString = [signature objectAtIndex:1];
                            
                            JSValue *decodedSignature = [decodeFunction callWithArguments:@[signatureAsString]];
                            
                            signatureAsString = [decodedSignature toString];
                            
                            [_signatures replaceObjectAtIndex:index
                                                   withObject:@[urlAsString, signatureAsString]];
                            
                            index++;
                        }
                    }
                } else {
                    error = [self errorWithCode:BLYYoutubeExtractorErrorCodeForHTML5FileDoesntContainSignatureMethodCall
                        andLocalizedDescription:@"HTML5 JS file doesn't contain a 'signature=()' method call."];
                    
                    return hookedCompletionBlock(nil, error);
                }
            }
        }
        
        hookedCompletionBlock(_signatures, error);
    };
    
    void(^HTML5FileHookedCompletion)(NSData *, NSError *) = ^(NSData *d, NSError *e){
        if (!inBackground) {
            return HTML5FileCompletion(d, e);
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            HTML5FileCompletion(d, e);
        });
    };
    
    if (HTML5FileIsCached) {
        NSData *HTML5FileContent = [NSData dataWithContentsOfFile:HTML5FilePath];
        
        if (HTML5FileContent) {
            return HTML5FileHookedCompletion(HTML5FileContent, nil);
        }
    }
    
    if (lastCachedJSFile) {
        NSError *removeJsFileError = nil;
        
        [[NSFileManager defaultManager] removeItemAtPath:lastCachedJSFile
                                                   error:&removeJsFileError];
        
        if (!removeJsFileError && !installedBeforeUpdate) {
            [userDefaults removeObjectForKey:BLYYoutubeExtractorLastCachedJsFile];
            [userDefaults removeObjectForKey:BLYYoutubeExtractorLastDecodeSigFuncName];
            
            [userDefaults synchronize];
        }
    }
    
    NSURL *HTML5FileUrl = [NSURL URLWithString:HTML5File];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:HTML5FileUrl
                                                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                   timeoutInterval:[[BLYVideoStore sharedStore] fetchVideoRequestTimeout] * 1.0];
    
    // Set user agent to avoid redirection to YouTube mobile site
    [req setValue:BLYYoutubeExtractorWatchURLUserAgent
forHTTPHeaderField:@"User-Agent"];
    
    BLYHTTPConnection *connection = [[BLYHTTPConnection alloc] initWithRequest:[req copy]];
    
    connection.completionBlock = HTML5FileHookedCompletion;
    connection.displayActivityIndicator = !inBackground;
    
    [connection start];
}

- (NSError *)errorWithCode:(BLYYoutubeExtractorErrorCode)errorCode
   andLocalizedDescription:(NSString *)localDesc
{
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    
    [userInfo setValue:localDesc
                forKey:NSLocalizedDescriptionKey];
    
    return  [NSError errorWithDomain:@"com.brown.blyyoutubeextractor"
                                code:errorCode
                            userInfo:userInfo];
}

@end
