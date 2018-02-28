//
//  BLYHTTPConnection.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const int BLYHTTPConnectionHTTPErrorCode;

typedef enum {
    BLYHTTPConnectionContainerTypeMemory,
    BLYHTTPConnectionContainerTypeFile
} BLYHTTPConnectionContainerType;

@interface BLYHTTPConnection : NSObject <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (nonatomic, copy) void (^completionBlock)(NSData *obj, NSError *err);
@property (nonatomic) BOOL displayActivityIndicator;
@property (nonatomic) BLYHTTPConnectionContainerType containerType;
@property (nonatomic) float requestProgress;

- (id)initWithRequest:(NSURLRequest *)req;
- (void)start;
- (void)cancel;
- (void)addSharedConnection:(BLYHTTPConnection *)connection;
- (void)destroyCurrentConnection;

@end
