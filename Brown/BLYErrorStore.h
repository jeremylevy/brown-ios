//
//  BLYErrorStore.h
//  Brown
//
//  Created by Jeremy Levy on 21/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BLYErrorStore : NSObject

+ (BLYErrorStore *)sharedStore;

- (void)manageError:(NSError *)error forViewController:(UIViewController *)controller;
- (void)manageError:(NSError *)error forViewController:(UIViewController *)controller withCompletionAfterAlertViewWasDismissed:(void(^)(void))completion;

@end
