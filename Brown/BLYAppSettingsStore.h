//
//  BLYAppSettingsStore.h
//  Brown
//
//  Created by Jeremy Levy on 01/11/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYStore.h"

typedef NS_ENUM(NSInteger, BLYAppSettingsStoreSetting) {
    BLYAppSettingsStoreAutoDownloadTracksSetting,
    BLYAppSettingsStoreForbidUcachedSongsListeningSetting,
    BLYAppSettingsStoreShakeToRandomizePlaylistSetting
};

extern NSString * const BLYAppSettingsStoreSettingHasChanged;

@interface BLYAppSettingsStore : NSObject

+ (BLYAppSettingsStore *)sharedStore;

- (void)setObject:(id)object
       forSetting:(BLYAppSettingsStoreSetting)setting;

- (id)objectForSetting:(BLYAppSettingsStoreSetting)setting;

- (void)setBool:(BOOL)value
     forSetting:(BLYAppSettingsStoreSetting)setting;

- (BOOL)boolForSetting:(BLYAppSettingsStoreSetting)setting;

- (BOOL)settingWasInitialized:(BLYAppSettingsStoreSetting)setting;

@end
