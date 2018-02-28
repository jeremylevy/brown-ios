//
//  BLYAppSettingsViewController.m
//  Brown
//
//  Created by Jeremy Levy on 30/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYAppSettingsViewController.h"
#import "BLYAppSettingsSettingCell.h"
#import "BLYAppSettingsStore.h"

const int BLYAppSettingsViewControllerWithWifiSection = 0;
const int BLYAppSettingsViewControllerWithoutWifiSection = 1;
const int BLYAppSettingsViewControllerAllTheTimeSection = 2;

@interface BLYAppSettingsViewController ()

@end

@implementation BLYAppSettingsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        // Custom initialization
        self.navigationItem.title = NSLocalizedString(@"app_settings_navigation_item_title", nil);
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Load the NIB file
    UINib *nib = [UINib nibWithNibName:@"BLYAppSettingsSettingCell" bundle:nil];
    
    // Register this NIB which contains the cell
    [self.settings registerNib:nib forCellReuseIdentifier:@"BLYAppSettingsSettingCell"];
    
    [self.settings setRowHeight:61.0];

    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0.0f, self.navigationController.navigationBar.frame.size.height - 0.5, self.view.frame.size.width, 0.5f);
    
    // Set the background colour of the new layer to the colour you wish to
    // use for the border.
    bottomBorder.backgroundColor = [[UIColor colorWithWhite:0.92 alpha:1.0] CGColor];
    
    // Add the later to the tab bar's existing layer
    [self.navigationController.navigationBar.layer addSublayer:bottomBorder];
    self.navigationController.navigationBar.clipsToBounds = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == BLYAppSettingsViewControllerWithWifiSection) {
        return NSLocalizedString(@"app_settings_with_wifi_section_title", nil);
    } else if (section == BLYAppSettingsViewControllerWithoutWifiSection) {
         return NSLocalizedString(@"app_settings_without_wifi_section_title", nil);
    }
    
    return NSLocalizedString(@"app_settings_all_the_time_section_title", nil);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == BLYAppSettingsViewControllerAllTheTimeSection) {
        return NSLocalizedString(@"app_settings_footer_cv", nil);
    }
    
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYAppSettingsSettingCell *cell = [self.settings dequeueReusableCellWithIdentifier:@"BLYAppSettingsSettingCell"];
    
    [cell.settingSwitch addTarget:self
                           action:@selector(settingChange:)
                 forControlEvents:UIControlEventValueChanged];
    
    if (indexPath.section == BLYAppSettingsViewControllerWithWifiSection) {
        
        cell.settingDescriptionLabel.text = NSLocalizedString(@"app_settings_auto_download_songs_setting", nil);
        
        BOOL autoDownloadTracks = [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreAutoDownloadTracksSetting];
        
        [cell.settingSwitch setOn:autoDownloadTracks];
        [cell.settingSwitch setTag:BLYAppSettingsViewControllerWithWifiSection];
        
    } else if (indexPath.section == BLYAppSettingsViewControllerWithoutWifiSection) {
        
        cell.settingDescriptionLabel.text = NSLocalizedString(@"app_settings_forbid_uncached_songs_listening_setting", nil);
        
        BOOL forbidUncachedSongListening = [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting];
        
        [cell.settingSwitch setOn:forbidUncachedSongListening];
        [cell.settingSwitch setTag:BLYAppSettingsViewControllerWithoutWifiSection];
    } else if (indexPath.section == BLYAppSettingsViewControllerAllTheTimeSection) {
        cell.settingDescriptionLabel.text = NSLocalizedString(@"app_settings_shake_to_randomize_setting", nil);
        
        BOOL shakeToRandomizePlaylist = [[BLYAppSettingsStore sharedStore] boolForSetting:BLYAppSettingsStoreShakeToRandomizePlaylistSetting];
        
        [cell.settingSwitch setOn:shakeToRandomizePlaylist];
        [cell.settingSwitch setTag:BLYAppSettingsViewControllerAllTheTimeSection];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    BLYAppSettingsSettingCell *cell = [self.settings cellForRowAtIndexPath:indexPath];
    
    [cell.settingSwitch setOn:!cell.settingSwitch.isOn];
    [self settingChange:cell.settingSwitch];
    
    [self.settings deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)settingChange:(UISwitch *)_switch
{
    if (_switch.tag == BLYAppSettingsViewControllerWithWifiSection) {
        
        [[BLYAppSettingsStore sharedStore] setBool:_switch.isOn
                                        forSetting:BLYAppSettingsStoreAutoDownloadTracksSetting];
        
    } else if (_switch.tag == BLYAppSettingsViewControllerWithoutWifiSection) {
        
        [[BLYAppSettingsStore sharedStore] setBool:_switch.isOn
                                        forSetting:BLYAppSettingsStoreForbidUcachedSongsListeningSetting];
    } else if (_switch.tag == BLYAppSettingsViewControllerAllTheTimeSection) {
        [[BLYAppSettingsStore sharedStore] setBool:_switch.isOn
                                        forSetting:BLYAppSettingsStoreShakeToRandomizePlaylistSetting];
    }
}

@end
