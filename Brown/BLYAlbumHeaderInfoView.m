//
//  BLYAlbumHeaderInfoView.m
//  Brown
//
//  Created by Jeremy Levy on 06/10/2016.
//  Copyright © 2016 Jeremy Levy. All rights reserved.
//

#import "BLYAlbumHeaderInfoView.h"

@implementation BLYAlbumHeaderInfoView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        if (self.subviews.count == 0) {
            UINib *nib = [UINib nibWithNibName:NSStringFromClass([self class]) bundle:nil];
            UIView *subview = [[nib instantiateWithOwner:self options:nil] objectAtIndex:0];
            
            self.realView = (BLYAlbumHeaderInfoView *)subview;
            
            subview.frame = self.bounds;
            
            [self addSubview:subview];
        }
    }
    
    return self;
}

- (void)willMoveToWindow:(UIWindow *)newWindow
{
    // Given that this view was embedded two times
    // we don't want two bottom shadows that overlap
    if ([self.superview isKindOfClass:[BLYAlbumHeaderInfoView class]]) {
        [super willMoveToWindow:newWindow];
    }
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    [self.realView.downloadLabel setText:NSLocalizedString(@"album_download_label", nil)];
}

@end
