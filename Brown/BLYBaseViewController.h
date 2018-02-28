//
//  BLYBaseViewController.h
//  Brown
//
//  Created by Jeremy Levy on 04/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const BLYBaseViewControllerDidLoadNotification;

@class BLYHTTPConnection;

@interface BLYBaseViewController : UIViewController

@property (weak, nonatomic) BLYHTTPConnection *launchedConnection;
@property (nonatomic) CALayer *lightBottomBorder;

- (void)handleNetworkNotReachable:(NSNotification *)n;
- (void)handleNetworkReachable:(NSNotification *)n;
- (void)handleNetworkTypeChange:(NSNotification *)n;
- (void)dismissMe:(id)sender;
- (void)handlePlayerHasLoadedPlaylist:(NSNotification *)n;
- (BOOL)isVisible;
- (void)extendedNavigationBar;
- (void)normalNavigationBar;

@end
