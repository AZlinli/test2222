//
//  MineResidentRedactRootTableViewCell.h
//  wisdomNeighbor
//
//  Created by Lin Li on 2019/11/17.
//  Copyright © 2019 Lin Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MineResidentRedactModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface MineResidentRedactRootTableViewCell : UITableViewCell
/**<##>*/
@property(nonatomic, strong) MineResidentRedactModelData *model;

- (void)isShowNextImage:(BOOL)isShow;
@end

NS_ASSUME_NONNULL_END
