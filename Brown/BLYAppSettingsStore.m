//
//  BLYAppSettingsStore.m
//  Brown
//
//  Created by Jeremy Levy on 01/11/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYAppSettingsStore.h"

NSString * const BLYAppSettingsStoreSettingHasChanged = @"BLYAppSettingsStoreSettingHasChanged";

@implementation BLYAppSettingsStore

+ (BLYAppSettingsStore *)sharedStore
{
    static BLYAppSettingsStore *appSettingsStore = nil;
    
    if (!appSettingsStore) {
        appSettingsStore = [[BLYAppSettingsStore alloc] init];
    }
    
    return appSettingsStore;
}

- (void)setObject:(id)object
       forSetting:(BLYAppSettingsStoreSetting)setting
{
    [[NSUserDefaults standardUserDefaults] setObject:object
                                              forKey:[[NSNumber numberWithInt:setting] stringValue]];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self postSettingHasChangedNotificationForSetting:setting];
}

- (id)objectForSetting:(BLYAppSettingsStoreSetting)setting
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:[[NSNumber numberWithInt:setting] stringValue]];
}

- (void)setBool:(BOOL)value
      forSetting:(BLYAppSettingsStoreSetting)setting
{
    [[NSUserDefaults standardUserDefaults] setBool:value
                                            forKey:[[NSNumber numberWithInt:setting] stringValue]];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self postSettingHasChangedNotificationForSetting:setting];
}

- (void)postSettingHasChangedNotificationForSetting:(BLYAppSettingsStoreSetting)setting
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BLYAppSettingsStoreSettingHasChanged
                                                        object:self
                                                      userInfo:@{@"setting": [NSNumber numberWithInt:setting]}];
}

- (BOOL)boolForSetting:(BLYAppSettingsStoreSetting)setting
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:[[NSNumber numberWithInt:setting] stringValue]];
}

- (BOOL)settingWasInitialized:(BLYAppSettingsStoreSetting)setting
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:[[NSNumber numberWithInt:setting] stringValue]] != nil;
}

@end
