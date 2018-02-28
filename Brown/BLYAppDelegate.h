//
//  BLYAppDelegate.h
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const BLYAppDelegateDidReceiveRemoteControlNotification;

extern const int BLYBaseTabBarControllerPlayerIndex;
extern const int BLYBaseTabBarControllerExternalTopIndex;
extern const int BLYBaseTabBarControllerSearchIndex;
extern const int BLYBaseTabBarControllerPlayedSongsIndex;

@class BLYBaseTabBarController, BLYPlayerViewController;

@interface BLYAppDelegate : UIResponder <UIApplicationDelegate> 

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) BLYBaseTabBarController *tabBarVC;

- (UIBackgroundTaskIdentifier)requestExtraBackgroundTime;
- (void)resignExtraBackgroundTime;
- (NSString *)countryCodeForCurrentLocale;
- (NSString *)countryNameForCountryCode:(NSString *)countryCode;

@end
