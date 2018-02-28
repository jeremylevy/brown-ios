//
//  BLYYoutubeExtractor.h
//  Brown
//
//  Created by Jeremy Levy on 03/12/2013.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    BLYYoutubeExtractorErrorCodeForPlayerConfigNotFound,
    BLYYoutubeExtractorErrorCodeForInvalidPlayerConfig,
    BLYYoutubeExtractorErrorCodeForVideoOwnedByCopyrightInfrignement,
    BLYYoutubeExtractorErrorCodeForHTML5FileDoesntContainSignatureMethodCall,
    BLYYoutubeExtractorErrorCodeForInvalidVideoURL
} BLYYoutubeExtractorErrorCode;

@class BLYVideo;

@interface BLYYoutubeExtractor : NSObject

- (void)urlsForVideo:(BLYVideo *)video
        inBackground:(BOOL)inBackground
  andCompletionBlock:(void(^)(NSArray *, NSError *))completionBlock;

@end
