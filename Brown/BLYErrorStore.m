//
//  BLYErrorStore.m
//  Brown
//
//  Created by Jeremy Levy on 21/10/13.
//  Copyright (c) 2013 Jeremy Levy. All rights reserved.
//

#import "BLYErrorStore.h"
#import "BLYFullScreenPlayerViewController.h"

@interface BLYErrorStore ()

@property (strong, nonatomic) NSMutableArray *pendingErrors;
@property (strong, nonatomic) void(^completionForDismiss)(void);

@end

@implementation BLYErrorStore

+ (BLYErrorStore *)sharedStore
{
    static BLYErrorStore *store = nil;
    
    if (!store) {
        store = [[BLYErrorStore alloc] init];
    }
    
    return store;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAppBecomeActive:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        
        _pendingErrors = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)handleAppBecomeActive:(NSNotification *)n
{
    if ([self.pendingErrors count] == 0) {
        return;
    }
    
    for (NSDictionary *errorComponents in self.pendingErrors) {
        NSError *error = [errorComponents objectForKey:@"error"];
        UIViewController *controller = [errorComponents objectForKey:@"controller"];
        void(^completion)(void) = [errorComponents objectForKey:@"completion"];
        
        [self manageError:error forViewController:controller withCompletionAfterAlertViewWasDismissed:completion];
    }
    
    [self.pendingErrors removeAllObjects];
}

- (void)manageError:(NSError *)error forViewController:(UIViewController *)controller
{
    [self manageError:error forViewController:controller withCompletionAfterAlertViewWasDismissed:nil];
}

- (void)manageError:(NSError *)error forViewController:(UIViewController *)controller withCompletionAfterAlertViewWasDismissed:(void(^)(void))completion
{
    if (!completion) {
        completion = ^{};
    }
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        [self.pendingErrors addObject:@{@"error": error, @"controller": controller, @"completion": completion}];
        
        return;
    }
    
    self.completionForDismiss = completion;
    
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:@"Erreur"
                                 message:error.localizedDescription
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelButton = [UIAlertAction
                                actionWithTitle:@"OK"
                                style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction *action) {
                                    if (self.completionForDismiss) {
                                        self.completionForDismiss();
                                    }
                                    
                                    self.completionForDismiss = nil;
                                }];
    
    [alert addAction:cancelButton];
    
    UIViewController *rootViewControler = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    
    if (rootViewControler.presentedViewController) {
        rootViewControler = rootViewControler.presentedViewController;
    } else if ([controller isKindOfClass:[BLYFullScreenPlayerViewController class]]) {
        rootViewControler = controller;
    }
    
    [rootViewControler presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
