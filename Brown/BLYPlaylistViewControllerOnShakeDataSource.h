//
//  BLYPlaylistViewControllerOnShakeDataSource.h
//  Brown
//
//  Created by Jeremy Levy on 15/12/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BLYPlaylist;

@protocol BLYPlaylistViewControllerOnShakeDataSource <NSObject>

- (BLYPlaylist *)playlistToRunOnShake;

@end
