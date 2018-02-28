//
//  BLYNetworkStore.h
//  Brown
//
//  Created by Jeremy Levy on 01/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    BLYNetworkStoreNetworkTypeWIFI,
    BLYNetworkStoreNetworkTypeGPRS,
    BLYNetworkStoreNetworkTypeEDGE,
    BLYNetworkStoreNetworkType3G,
    BLYNetworkStoreNetworkType3G5,
    BLYNetworkStoreNetworkType4G,
    BLYNetworkStoreNetworkTypeAIRPLANE,
    BLYNetworkStoreNetworkTypeUNKNOWN
} BLYNetworkStoreNetworkType;

extern NSString * const BLYNetworkStoreDidDetectThatNetworkIsNotReachable;
extern NSString * const BLYNetworkStoreDidDetectThatNetworkIsReachable;
extern NSString * const BLYNetworkStoreDidDetectThatNetworkTypeHasChanged;

@interface BLYNetworkStore : NSObject

+ (BLYNetworkStore *)sharedStore;

- (void)startNotifier;
- (BOOL)networkIsReachable;
- (BOOL)networkIsReachableViaCellularNetwork;
- (BOOL)networkIsReachableViaWifi;
- (BLYNetworkStoreNetworkType)networkType;
- (BOOL)networkIsDataNetwork;

@end
