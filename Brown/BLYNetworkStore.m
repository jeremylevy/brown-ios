//
//  BLYNetworkStore.m
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "BLYNetworkStore.h"
#import "Reachability.h"

NSString * const BLYNetworkStoreDidDetectThatNetworkIsNotReachable = @"BLYNetworkStoreDidDetectThatNetworkIsNotReachable";
NSString * const BLYNetworkStoreDidDetectThatNetworkIsReachable = @"BLYNetworkStoreDidDetectThatNetworkIsReachable";
NSString * const BLYNetworkStoreDidDetectThatNetworkTypeHasChanged = @"BLYNetworkStoreDidDetectThatNetworkTypeHasChanged";

@interface BLYNetworkStore ()

@property (strong, nonatomic) Reachability *hostReachability;
@property (strong, nonatomic) Reachability *internetReachability;
@property (strong, nonatomic) Reachability *wifiReachability;
@property (nonatomic) NetworkStatus networkStatus;
@property (strong, nonatomic) NSString *currentRadioAccessTechnology;

@end

@implementation BLYNetworkStore

+ (BLYNetworkStore *)sharedStore
{
    static BLYNetworkStore *network = nil;
    
    if (!network) {
        network = [[BLYNetworkStore alloc] init];
    }
    
    return network;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        _networkStatus = NotReachable;
    }
    
    return self;
}

- (void)startNotifier
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleReachabilityChange:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    CTTelephonyNetworkInfo *telephonyInfo = [[CTTelephonyNetworkInfo alloc] init];
    __weak BLYNetworkStore *weakSelf = self;
    
    [NSNotificationCenter.defaultCenter addObserverForName:CTRadioAccessTechnologyDidChangeNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *note) {
        NSString *currentRadioAccessTechnology = [telephonyInfo currentRadioAccessTechnology];
        
        if (!currentRadioAccessTechnology) {
            return;
        }
        
        [weakSelf setCurrentRadioAccessTechnology:currentRadioAccessTechnology];
                                                    
        [[NSNotificationCenter defaultCenter] postNotificationName:BLYNetworkStoreDidDetectThatNetworkTypeHasChanged
                                                            object:self];
    }];
    
    [self setCurrentRadioAccessTechnology:[telephonyInfo currentRadioAccessTechnology]];
    
    // Change the host name here to change the server you want to monitor.
    NSString *remoteHostName = @"www.apple.com";
    
    self.hostReachability = [Reachability reachabilityWithHostName:remoteHostName];
    [self.hostReachability startNotifier];
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    self.wifiReachability = [Reachability reachabilityForLocalWiFi];
    [self.wifiReachability startNotifier];
}

- (void)handleReachabilityChange:(NSNotification *)n
{
    Reachability *reachability = [n object];
    NSString *notificationName = [self networkIsReachable]
        ? BLYNetworkStoreDidDetectThatNetworkIsReachable
        : BLYNetworkStoreDidDetectThatNetworkIsNotReachable;
    
    [self setNetworkStatus:[reachability currentReachabilityStatus]];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self];
}

- (BLYNetworkStoreNetworkType)networkType
{
    if ([self networkIsReachableViaWifi]) {
        return BLYNetworkStoreNetworkTypeWIFI;
    }
    
    if (![self networkIsReachable]) {
        return BLYNetworkStoreNetworkTypeAIRPLANE;
    }
    
    // https://stackoverflow.com/questions/25405566/mapping-ios-7-constants-to-2g-3g-4g-lte-etc
    if ([_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
        return BLYNetworkStoreNetworkTypeGPRS;
    } else if ([_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
        return BLYNetworkStoreNetworkTypeEDGE;
    } else if ([_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
        return BLYNetworkStoreNetworkType3G;
    } else if ([_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]
               || [_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
        return BLYNetworkStoreNetworkType3G5;
    } else if ([_currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
        return BLYNetworkStoreNetworkType4G;
    }
    
    return BLYNetworkStoreNetworkTypeUNKNOWN;
}

- (BOOL)networkIsReachable
{
    return [self networkStatus] != NotReachable;
}

- (BOOL)networkIsReachableViaCellularNetwork
{
    return [self networkStatus] == ReachableViaWWAN;
}

- (BOOL)networkIsReachableViaWifi
{
    return [self networkStatus] == ReachableViaWiFi;
}

- (BOOL)networkIsDataNetwork
{
    return [self networkType] == BLYNetworkStoreNetworkType3G
        || [self networkType] == BLYNetworkStoreNetworkType3G5
        || [self networkType] == BLYNetworkStoreNetworkType4G
        || [self networkType] == BLYNetworkStoreNetworkTypeWIFI;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
