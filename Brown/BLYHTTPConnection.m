//
//  BLYHTTPConnection.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYHTTPConnection.h"

const int BLYHTTPConnectionHTTPErrorCode = 0;

// Keep strong reference to all connections
static NSMutableArray *sharedConnectionList = nil;

@interface BLYHTTPConnection ()

@property (strong, nonatomic) NSMutableData *container;
@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (strong, nonatomic) NSURLRequest *request;
@property (weak, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSURLConnection *internalConnection;
@property (strong, nonatomic) NSString *tmpPath;
@property (nonatomic) NSInteger HTTPStatusCode;
@property (nonatomic) long long expectedContentLength;

@end

@implementation BLYHTTPConnection

- (id)initWithRequest:(NSURLRequest *)req
{
    self = [super init];
    
    if (self) {
        _request = req;
        _displayActivityIndicator = YES;
        _containerType = BLYHTTPConnectionContainerTypeMemory;
    }
    
    return self;
}

- (void)start
{
    // First started connection -> create array
    if (!sharedConnectionList) {
        sharedConnectionList = [[NSMutableArray alloc] init];
    }
    
    if (self.containerType == BLYHTTPConnectionContainerTypeMemory) {
        self.container = [[NSMutableData alloc] init];
    } else {
        self.tmpPath = [self createTemporaryFileInTemporaryDirectory];
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tmpPath];
    }
    
    // Add connection to shared list so it doesn't get destroyed
    [self addSharedConnection:self];
    
    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:self.request];
    
    [dataTask resume];
    
    [session finishTasksAndInvalidate];
    
    self.session = session;
    self.request = nil;
    
    // Spawn connection
//    self.internalConnection = [[NSURLConnection alloc] initWithRequest:self.request
//                                                              delegate:self
//                                                      startImmediately:YES];
    
    if (!self.displayActivityIndicator) {
        return;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (NSString *)createTemporaryFileInTemporaryDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *fileName = @"blyhttpconnection_XXXXXX";
    
    const char *fileNameAsCStringConst = [fileName cStringUsingEncoding:NSUTF8StringEncoding];
    char *fileNameAsCString = malloc(strlen(fileNameAsCStringConst) + 1);
    
    if (fileNameAsCString) {
        strcpy(fileNameAsCString, fileNameAsCStringConst);
    } else {
        [NSException raise:@"BLYHTTPConnection encounter a malloc error"
                    format:@"BLYHTTPConnection encounter a malloc error when creating temporary file"];
    }
    
    mkstemp(fileNameAsCString);
    
    fileName = [NSString stringWithCString:fileNameAsCString
                                  encoding:NSUTF8StringEncoding];
    
    free(fileNameAsCString);
    
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingString:fileName];
    
    [fileManager createFileAtPath:tmpPath
                         contents:nil
                       attributes:nil];
    
    return tmpPath;
}

- (void)removeTemporaryFileAtPath:(NSString *)tmpPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    if (![fileManager fileExistsAtPath:tmpPath]) {
        return;
    }
    
    [fileManager removeItemAtPath:tmpPath
                            error:&error];
    
    if (error) {
        [NSException raise:@"BLYHTTPConnection was unable to remove temporary file"
                    format:@"Reason: %@", error.localizedDescription];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if (self.containerType == BLYHTTPConnectionContainerTypeMemory) {
        [self.container appendData:data];
        
        self.requestProgress = (float)[self.container length] / (float)self.expectedContentLength;
        
        return;
    }
    
    [self.fileHandle writeData:data];
    
    // Get filesize after data were written
    unsigned long long filesize = [self.fileHandle seekToEndOfFile];
    
    self.requestProgress = (float)filesize / (float)self.expectedContentLength;
}

//- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
//{
//    if (self.containerType == BLYHTTPConnectionContainerTypeMemory) {
//        [self.container appendData:data];
//
//        self.requestProgress = (float)[self.container length] / (float)self.expectedContentLength;
//
//        return;
//    }
//
//    [self.fileHandle writeData:data];
//
//    // Get filesize after data were written
//    unsigned long long filesize = [self.fileHandle seekToEndOfFile];
//
//    self.requestProgress = (float)filesize / (float)self.expectedContentLength;
//}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = [httpResponse statusCode];
    
    self.HTTPStatusCode = statusCode;
    self.expectedContentLength = [httpResponse expectedContentLength];
    
    completionHandler(NSURLSessionResponseAllow);
}

//- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
//{
//    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//    NSInteger statusCode = [httpResponse statusCode];
//
//    self.HTTPStatusCode = statusCode;
//    self.expectedContentLength = [httpResponse expectedContentLength];
//}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        // Pass the error from the connection to the completionBlock
        if (self.completionBlock) {
            self.completionBlock(nil, error);
        }
        
        [self destroyCurrentConnection];
        
        return;
    }
    
    
    NSError *err = nil;
    
    if (self.HTTPStatusCode >= 400) {
        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
        
        [userInfo setValue:[NSString stringWithFormat:@"HTTP error (%ld).", (long)self.HTTPStatusCode]
                    forKey:NSLocalizedDescriptionKey];
        
        [userInfo setValue:[NSNumber numberWithLong:self.HTTPStatusCode]
                    forKey:@"HTTPStatusCode"];
        
        err = [NSError errorWithDomain:@"com.brown.blyhttpconnection"
                                  code:BLYHTTPConnectionHTTPErrorCode
                              userInfo:userInfo];
    }
    
    if (self.completionBlock) {
        NSData *data = nil;
        
        if (self.containerType == BLYHTTPConnectionContainerTypeMemory) {
            data = [self.container copy];
        } else {
            data = [self.tmpPath dataUsingEncoding:NSUTF8StringEncoding];
        }
        
        self.completionBlock(data, err);
    }
    
    [self destroyCurrentConnection];
}

//- (void)connectionDidFinishLoading:(NSURLConnection *)connection
//{
//    NSError *err = nil;
//
//    if (self.HTTPStatusCode >= 400) {
//        NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
//
//        [userInfo setValue:[NSString stringWithFormat:@"HTTP error (%ld).", (long)self.HTTPStatusCode]
//                    forKey:NSLocalizedDescriptionKey];
//
//        [userInfo setValue:[NSNumber numberWithLong:self.HTTPStatusCode]
//                    forKey:@"HTTPStatusCode"];
//
//        err = [NSError errorWithDomain:@"com.brown.blyhttpconnection"
//                                  code:BLYHTTPConnectionHTTPErrorCode
//                              userInfo:userInfo];
//    }
//
//    if (self.completionBlock) {
//        NSData *data = nil;
//
//        if (self.containerType == BLYHTTPConnectionContainerTypeMemory) {
//            data = [self.container copy];
//        } else {
//            data = [self.tmpPath dataUsingEncoding:NSUTF8StringEncoding];
//        }
//
//        self.completionBlock(data, err);
//    }
//
//    [self destroyCurrentConnection];
//}

- (void)addSharedConnection:(BLYHTTPConnection *)connection
{
    [sharedConnectionList addObject:connection];
}

- (void)destroyCurrentConnection
{
    [sharedConnectionList removeObject:self];
    
    BOOL hideNetworkActivityIndicator = YES;
    
    for (BLYHTTPConnection *conn in sharedConnectionList) {
        if (!conn.displayActivityIndicator) {
            continue;
        }
        
        hideNetworkActivityIndicator = NO;
        
        break;
    }
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:!hideNetworkActivityIndicator];
    
    if (self.containerType != BLYHTTPConnectionContainerTypeFile) {
        return;
    }
    
    [self removeTemporaryFileAtPath:self.tmpPath];
}

//- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
//{
//    // Pass the error from the connection to the completionBlock
//    if (self.completionBlock) {
//        self.completionBlock(nil, error);
//    }
//
//    [self destroyCurrentConnection];
//}

- (void)cancel
{
    [self.session invalidateAndCancel];
    
    // [self.internalConnection cancel];
    
    [self destroyCurrentConnection];
}

@end
