//
//  UIAlertController+Orientation.m
//  Brown
//
//  Created by Jeremy Levy on 12/01/2018.
//  Copyright © 2018 Jeremy Levy. All rights reserved.
//

#import "UIAlertController+Orientation.h"

@implementation UIAlertController (Orientation)

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
