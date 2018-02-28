//
//  BLYAppDelegate.m
//  Brown
//
//  Created by Jeremy Levy on 19/09/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYAppDelegate.h"
#import "BLYBaseNavigationController.h"
#import "BLYBaseTabBarController.h"
#import "BLYExternalTopSongViewController.h"
#import "BLYPlayedSongViewController.h"
#import "BLYSearchSongViewController.h"
#import "BLYPlayerViewController.h"
#import "BLYDiscoveryViewController.h"
#import "BLYNetworkStore.h"
#import "BLYSongStore.h"
#import "BLYVideoStore.h"
#import "BLYPlayerContainerViewController.h"
#import "BLYSearchSongAutocompleteResultsStore.h"
#import "BLYSearchSongsStore.h"
#import "BLYAppSettingsStore.h"
#import "BLYFullScreenPlayerViewController.h"

NSString * const BLYAppDelegateDidReceiveRemoteControlNotification = @"BLYAppDelegateDidReceiveRemoteControlNotification";

const int BLYBaseTabBarControllerPlayerIndex = 0;
const int BLYBaseTabBarControllerExternalTopIndex = 1;
const int BLYBaseTabBarControllerSearchIndex = 2;
const int BLYBaseTabBarControllerPlayedSongsIndex = 3;

@interface BLYAppDelegate ()

@property (weak, nonatomic) BLYPlayerViewController *playerVC;
@property (nonatomic) UIBackgroundTaskIdentifier bgTaskID;
@property (nonatomic) int currentExtraBackgroundTimeRequest;

@end

@implementation BLYAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    
    self.window = [[UIWindow alloc] initWithFrame:screenBounds];
    
    self.bgTaskID = UIBackgroundTaskInvalid;
    
    UIColor *navBarTintColor = [UIColor whiteColor];
    
    UIColor *tabBarTintColor = [UIColor whiteColor];
    
    [[UINavigationBar appearance] setBarTintColor:navBarTintColor];
    [[UITabBar appearance] setBarTintColor:tabBarTintColor];
    
    [[BLYNetworkStore sharedStore] startNotifier];
    
    if (![[BLYAppSettingsStore sharedStore] settingWasInitialized:BLYAppSettingsStoreShakeToRandomizePlaylistSetting]) {
        [[BLYAppSettingsStore sharedStore] setBool:YES
                                        forSetting:BLYAppSettingsStoreShakeToRandomizePlaylistSetting];
    }
    
    // Override point for customization after application launch.
    BLYBaseTabBarController *tabBarController = [[BLYBaseTabBarController alloc] init];
    
    BLYBaseNavigationController *externalTopSongsNavController = [[BLYBaseNavigationController alloc] init];
    BLYBaseNavigationController *searchSongsNavController = [[BLYBaseNavigationController alloc] init];
    
    BLYBaseNavigationController *playerNavController = [[BLYBaseNavigationController alloc] init];
    BLYBaseNavigationController *playedSongsHistoryNavController = [[BLYBaseNavigationController alloc] init];
    
    BLYPlayerViewController *playerVC = [[BLYPlayerViewController alloc] init];
    BLYExternalTopSongViewController *externalTopSongsVC = [[BLYExternalTopSongViewController alloc] init];
    
    BLYPlayedSongViewController *playedSongsHistoryVC = [[BLYPlayedSongViewController alloc] init];
    BLYSearchSongViewController *searchSongsVC = [[BLYSearchSongViewController alloc] init];
    
    BLYPlayerContainerViewController *playerContainerVC = [[BLYPlayerContainerViewController alloc] init];
    
    [externalTopSongsVC setPlayerVC:playerVC];
    [playedSongsHistoryVC setPlayerVC:playerVC];
    
    [searchSongsVC setPlayerVC:playerVC];
    [playerContainerVC setPlayerVC:playerVC];
    
    [playerVC setContainerVC:playerContainerVC];
    
    self.playerVC = playerVC;
    
    [externalTopSongsNavController addChildViewController:externalTopSongsVC];
    [searchSongsNavController addChildViewController:searchSongsVC];
    
    [playerNavController addChildViewController:playerContainerVC];
    [playedSongsHistoryNavController addChildViewController:playedSongsHistoryVC];

    [tabBarController addChildViewController:playerNavController];
    [tabBarController addChildViewController:externalTopSongsNavController];
    
    [tabBarController addChildViewController:searchSongsNavController];
    [tabBarController addChildViewController:playedSongsHistoryNavController];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    _tabBarVC = tabBarController;
    [self.window setRootViewController:tabBarController];
    
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.tintColor = [UIColor blackColor];
    
    [self.window makeKeyAndVisible];
    
    [[BLYSearchSongAutocompleteResultsStore sharedStore] removeOrphanedSearchSongAutocompleteResults];
    
    [[BLYSearchSongsStore sharedStore] clearHiddenSongSearchs];
    
    [[BLYSongStore sharedStore] removeOrphanedSongs];
    
    [[BLYVideoStore sharedStore] removeOrphanedVideoSongs];
    [[BLYVideoStore sharedStore] removeOrphanedVideos];
    
    return YES;
}

- (UIBackgroundTaskIdentifier)requestExtraBackgroundTime
{
    __weak BLYAppDelegate *weakSelf = self;
    
    if (self.bgTaskID != UIBackgroundTaskInvalid) {
        self.currentExtraBackgroundTimeRequest++;
        
        return self.bgTaskID;
    }
    
    self.currentExtraBackgroundTimeRequest = 1;
    
    self.bgTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [weakSelf resignExtraBackgroundTimeByForcing:YES];
    }];
    
    return self.bgTaskID;
}

- (void)resignExtraBackgroundTime
{
    [self resignExtraBackgroundTimeByForcing:NO];
}

- (void)resignExtraBackgroundTimeByForcing:(BOOL)forcing
{
    if (self.bgTaskID == UIBackgroundTaskInvalid) {
        return;
    }
    
    self.currentExtraBackgroundTimeRequest--;
    
    if (self.currentExtraBackgroundTimeRequest > 0 && !forcing) {
        return;
    }
    
    self.currentExtraBackgroundTimeRequest = 0;
    
    [[UIApplication sharedApplication] endBackgroundTask:self.bgTaskID];
    
    self.bgTaskID = UIBackgroundTaskInvalid;
}

- (NSString *)countryCodeForCurrentLocale
{
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSString *countryCode = [currentLocale objectForKey:NSLocaleCountryCode];
    
    return [countryCode lowercaseString];
}

- (NSString *)countryNameForCountryCode:(NSString *)countryCode
{
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSString *country = [currentLocale displayNameForKey:NSLocaleCountryCode
                                                   value:countryCode];
    
    return country;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    if (![self.playerVC isPlaying]) {
        // [self endTrackingInBackground:YES];
    }
    
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    if (![self.playerVC isPlaying]) {
        // [self startTracking];
    }
    
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // [self endTrackingInBackground:NO];
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

// In case of PlayerViewController isn't the first responder
- (void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:receivedEvent
                                                         forKey:@"receivedEvent"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYAppDelegateDidReceiveRemoteControlNotification
                                                        object:self
                                                      userInfo:userInfo];
}

// Fix full screen player not rotating
// when `MPAVRoutingSheetSecureWindow` displayed and rotated
// TODO: Learn wh
- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window {
    
//    if ([window.rootViewController isKindOfClass:[BLYFullScreenPlayerViewController class]]) {
//        return UIInterfaceOrientationMaskLandscape;
//    }
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
