//
//  FSBTaskCell.h
//  tenkay
//
//  Created by Dawson Blackhouse on 12/30/12.
//  Copyright (c) 2012 Jabari Bell and Dawson Blackhouse. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "Task.h"
#import "FSBTasksViewController.h"

@interface FSBTaskCell : UITableViewCell 

@property (nonatomic) BOOL isOpen;
@property (nonatomic) BOOL isCellAnimating;
@property (nonatomic, strong) id <FSBTasksViewDelegate> delegate;
@property (nonatomic, strong) Task *task;
@property (nonatomic, strong) IBOutlet UILabel *taskLabel;
@property (nonatomic, strong) IBOutlet UILabel *taskTime;
@property (strong, nonatomic) IBOutlet UIProgressView *taskProgress;


- (void)toggleNav;
- (void)hideNav;
- (void)forceShowNav;
- (void)showIsRecordingView;
- (void)showCurrentCellIsRecordingView;
- (void)showCurrentCellIsNotRecordingView;
- (void)hideSeparator;

@end
