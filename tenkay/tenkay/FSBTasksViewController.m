//
//  FSBTaskViewController.m
//  tenkay
//
//  Created by Jabari Bell and Dawson Blackhouse on 12/28/12.
//  Copyright (c) 2012 Jabari Bell and Dawson Blackhouse. All rights reserved.
//

#import "FSBTasksViewController.h"
#import "FSBCalendarViewController.h"
#import "FSBTaskCell.h"
#import "Task.h"
#import "Session.h"
#import "FSBTextUtil.h"
#import "FSBAddTimeViewController.h"
#import "FSBEditView.h"
#import <QuartzCore/QuartzCore.h>
#import "FSBAddTaskCell.h"
#import "FSBSaveAlertBanner.h"

@interface FSBTasksViewController ()
- (void)hideOpenCell;
@end

@implementation FSBTasksViewController{
    NSFetchedResultsController *fetchedResultsController;
    Task *currentTask;
    Task *taskToDelete;
    Session *currentSession;
    //saving indexpath for stopCurrentSession upon gesture.
    NSIndexPath *currentIndexPath;
    NSTimer *sessionTimer;
    BOOL isRecording;
    NSInteger selectedRowNumber;
    FSBEditView *editView;
    CABasicAnimation *fadeUpAnimation;
    CABasicAnimation *fadeOutAnimation;
    UIButton *addButton;
    BOOL isAddCellSelected;
    BOOL isScrollTimerStarted;
    BOOL isScrollTimerNeeded;
    FSBSaveAlertBanner *saveAlertBanner;
}

#define kCellHeight 64.0 
#define kCellOpenedHeight 103.0

@synthesize managedObjectContext;

- (void)performFetch
{
    NSError *error;
    if (![self.fetchedResultsController performFetch:&error]) {
        FATAL_CORE_DATA_ERROR(error);
        return;
    }
}

- (void)onAddButtonPress:(id)sender
{
    [self hideOpenCell];
    FSBAddTaskCell *addTaskCell = (FSBAddTaskCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0] - 1 inSection:0]];
    if ([self.tableView indexPathForCell:addTaskCell]) {
        isAddCellSelected = NO;
        [addTaskCell.taskNameTextField becomeFirstResponder];
    } else {
        isScrollTimerNeeded = YES;
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0] - 1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)hideAddCellKeyboard
{
    FSBAddTaskCell *addTaskCell = (FSBAddTaskCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0] - 1 inSection:0]];
    [addTaskCell.taskNameTextField resignFirstResponder];
    isAddCellSelected = NO;
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    if(!isScrollTimerStarted && !isAddCellSelected) {
        FSBAddTaskCell *addTaskCell = (FSBAddTaskCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[self.tableView numberOfRowsInSection:0] - 1 inSection:0]];
        [addTaskCell.taskNameTextField becomeFirstResponder];
        isScrollTimerStarted = YES;
        //hack that waits for keyboard of add task keyboard to slide into place
        NSTimer *scrollListenerTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(setScrollListener:) userInfo:nil repeats:NO];
    }
}

- (void)setScrollListener:(id)sender
{
    isScrollTimerStarted = NO;
    isAddCellSelected = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if(isAddCellSelected == YES){
        [self hideAddCellKeyboard];
    }
}

- (void)openCalendar:(Task *)task
{
   selectedRowNumber = -1;
   [self performSegueWithIdentifier:@"openCalendarView" sender:task];
}

- (void)openEditScreen:(Task *)task
{
    editView = [[FSBEditView alloc] initWithFrame:CGRectMake(0.0, self.tableView.contentOffset.y, self.view.window.bounds.size.width, self.view.bounds.size.height)];
    editView.delegate = self;
    [editView setTask:task];
    [self.view addSubview:editView];
    self.tableView.userInteractionEnabled = FALSE;
    
    fadeUpAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeUpAnimation.duration = 0.4;
    fadeUpAnimation.fromValue = @0.0;
    fadeUpAnimation.toValue = @1.0;
    fadeUpAnimation.delegate = self;
    [fadeUpAnimation setValue:@"editScreenfadeUpAnimation" forKey:@"id"];
    [editView.layer addAnimation:fadeUpAnimation forKey:@"animateOpacity"];
    addButton.alpha = 0.0;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if ([[anim valueForKey:@"id"] isEqual:@"editScreenfadeUpAnimation"]) {
        [editView setKeyboardFirstResponder];
    } else if([[anim valueForKey:@"id"] isEqual:@"editScreenfadeOutAnimation"]) {
        fadeOutAnimation = nil;
        fadeUpAnimation = nil;
        [editView removeFromSuperview];
        editView = nil;
        self.tableView.userInteractionEnabled = TRUE;
        addButton.alpha = 1.0;
    }
}

- (void)openAddTimeScreen:(Task *)task
{
    currentTask = task;
    selectedRowNumber = -1;
    [self performSegueWithIdentifier:@"addTime" sender:self];  
}

- (void)dismissEditView:(NSString *)newTaskTitle
{
    fadeOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeOutAnimation.duration = 0.4;
    fadeOutAnimation.fromValue = @1.0;
    fadeOutAnimation.toValue = @0.0;
    fadeOutAnimation.delegate = self;
    editView.alpha = 0.0;
    [fadeOutAnimation setValue:@"editScreenfadeOutAnimation" forKey:@"id"];
    [editView.layer addAnimation:fadeOutAnimation forKey:@"animateOpacity"];
    
    //update model here
    if ([newTaskTitle length] > 0) {
        Task *task = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForItem:selectedRowNumber inSection:0]];
        [task setValue:newTaskTitle forKey:@"title"];
    }
    selectedRowNumber = -1;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self performFetch];
    
    addButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 41, 40)];
    [addButton setImage:[UIImage imageNamed:@"addTaskButton"] forState:UIControlStateNormal];
    [addButton addTarget:self action:@selector(onAddButtonPress:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:addButton];
    selectedRowNumber = -1;
    isAddCellSelected = NO;
    
    UIImage *logoImage = [UIImage imageNamed:@"header-logo"];
    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:logoImage];
    logoImageView.frame = CGRectMake(0, 0, 70, 27);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:logoImageView];
    
    saveAlertBanner = [[FSBSaveAlertBanner alloc] initWithFrame:CGRectMake(0, 0, 640, 61)];
    [self.parentViewController.view insertSubview:saveAlertBanner atIndex:1];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"openCalendarView"]) {
        FSBCalendarViewController *controller = (FSBCalendarViewController *)segue.destinationViewController;
        controller.managedObjectContext = managedObjectContext;
        Task *task = (Task *)sender;
        controller.taskForCalendar = task;
    } else if ([[segue identifier] isEqualToString:@"addTime"]) {
        FSBAddTimeViewController *controller = (FSBAddTimeViewController *)segue.destinationViewController;
        controller.delegate = self;
        controller.currentTask = currentTask;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // Repeating setup in viewDidLoad, needs to be refactored into a function later
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    //close the open cell
    [self hideOpenCell];
}

- (void)deleteTask:(Task *)task
{
    taskToDelete = task;
    NSString *destructiveTitle = @"Delete Task"; //Action Sheet Button Titles
    NSString *cancelTitle = @"Cancel";
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@""
                                  delegate:self
                                  cancelButtonTitle:cancelTitle
                                  destructiveButtonTitle:destructiveTitle
                                  otherButtonTitles:nil];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *buttonTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
    if  ([buttonTitle isEqualToString:@"Delete Task"]) {
        [managedObjectContext deleteObject:taskToDelete];
        selectedRowNumber = -1;
        NSError *error;
        if(![self.managedObjectContext save:&error]) {
            NSLog(@"Error Value: %@", [taskToDelete valueForKey:@"title"]);
        }
    }
}

- (void)addTimeToTask:(NSDate *)startDate endDate:(NSDate *)eDate numSeconds:(NSNumber *)seconds taskToAddTimeTo:(Task *)task
{
    Session *session = [NSEntityDescription insertNewObjectForEntityForName:@"Session" inManagedObjectContext:managedObjectContext];
    session.startDate = startDate;
    session.endDate = eDate;
    [task addTaskSessionObject:session];
    
    task.totalTime = [NSNumber numberWithDouble:([currentTask.totalTime doubleValue] + [seconds doubleValue])];
    
    [self performFetch];
}

- (BOOL)isRecording
{
    return isRecording;
}

- (void)startPulsing
{
    [UIView animateWithDuration:0.05 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear) animations:^{
        self.view.backgroundColor = [UIColor colorWithRed:76.0f/255.0f green:168.0f/255.0f blue:207.0f/255.0f alpha:100.0];
    } completion:^(BOOL finished){
        self.view.backgroundColor = [UIColor colorWithRed:76.0f/255.0f green:168.0f/255.0f blue:207.0f/255.0f alpha:100.0];
        [UIView animateWithDuration:1.5 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear | UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse) animations:^{
            self.view.backgroundColor = [UIColor colorWithRed:114.0f/255.0f green:208.0f/255.0f blue:248.0f/255.0f alpha:100.0];
        } completion:^(BOOL finished){
            
        }];
    }];
}

- (void)stopPulsing
{
    [self.tableView reloadData]; 
    [UIView animateWithDuration:0.05 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear) animations:^{
        //animation here
        self.view.backgroundColor = [UIColor colorWithRed:231.0f/255.0f green:231.0f/255.0f blue:231.0f/255.0f alpha:100.0];
    } completion:^(BOOL finished){
       
    }];
}

- (void)onPlayButtonPress:(Task *)task indexPath:(NSIndexPath *)selectedIndex
{
    if (!isRecording) {
        currentIndexPath = selectedIndex;
        selectedRowNumber = -1;
        isRecording = YES;
        addButton.enabled = NO;
        [self.tableView reloadData];
        [self startPulsing];
        [self startTaskTimerAtIndexPath:currentIndexPath];
    }
}

- (void)onStopButtonPress:(Task *)task indexPath:(NSIndexPath *)selectedIndex
{
    if(isRecording) {
        addButton.enabled = YES;
        isRecording = NO;
        [self stopPulsing];
        [self stopCurrentSession];
    }
}

- (void)hideOpenCell
{
    FSBTaskCell *currentlySelectedCell = (FSBTaskCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRowNumber inSection:0]];
    [currentlySelectedCell hideNav];
    currentlySelectedCell.isOpen = NO;
    selectedRowNumber = -1;
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
}

- (void)onSaveNewTask:(NSString *)taskName
{
    NSLog(@"***** - onSave:");
    Task *task = nil;
    if(self.managedObjectContext) {
        if ([taskName length] > 0) {
            task = [NSEntityDescription insertNewObjectForEntityForName:@"Task" inManagedObjectContext:self.managedObjectContext];
            task.title = taskName;
            task.creationDate = [NSDate date];
            NSError *error;
            if(![self.managedObjectContext save:&error]) {
                NSLog(@"Error Value: %@", [task valueForKey:@"title"]);
            }
        }
    }
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    NSInteger *numRows = [sectionInfo numberOfObjects] + 1;
    return numRows;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    FSBTaskCell *taskCell = (FSBTaskCell *)cell;
    Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
    taskCell.task = task;
    taskCell.delegate = self;
    taskCell.taskLabel.text = task.title;
    taskCell.isOpen = NO;
    taskCell.isCellAnimating = NO;
    
    if(isRecording) {
        [taskCell hideNav];
        if (currentIndexPath.row == indexPath.row) {
            [taskCell showCurrentCellIsRecordingView];
        } else {
            [taskCell showIsRecordingView];
        }
        if (indexPath.row == (currentIndexPath.row - 1)) {
            [taskCell hideSeparator];
        }
        self.tableView.scrollEnabled = NO;
    } else {
        [taskCell showCurrentCellIsNotRecordingView];
        self.tableView.scrollEnabled = YES;
        if (selectedRowNumber == indexPath.row && taskCell.frame.size.height == kCellOpenedHeight) {
            NSLog(@"skipping index: %d", indexPath.row);
            [taskCell forceShowNav];
        } else {
            [taskCell hideNav];
        }
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
    NSTimeInterval timeInterval = [task.totalTime doubleValue];
    NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    taskCell.taskTime.text = [dateFormatter stringFromDate:timerDate];
    
    NSString *formattedTotalTime = [FSBTextUtil stringFromNumSeconds:task.totalTime isTruncated:YES];
    taskCell.taskTime.text = formattedTotalTime;
    
    double timeInt = timeInterval;
    double tenKHours = 36000000;
    
    double prog = timeInt / tenKHours;
    
    [taskCell.taskProgress setProgress:prog];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:0];
    if (indexPath.row >= [sectionInfo numberOfObjects]) {
        static NSString *CellIdentifier = @"AddTaskCell";
        FSBAddTaskCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        cell.delegate = self;
        if (isRecording) {
            [cell setHidden:YES];
        } else {
            [cell setHidden:NO];
        }
        return cell;
    } else {
        static NSString *CellIdentifier = @"TaskCell";
        FSBTaskCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        [self configureCell:cell atIndexPath:indexPath];
        return cell;
    }
}

- (void)updateTimerAtIndexPath:(NSIndexPath *)indexPath
{
    FSBTaskCell *taskCell = (FSBTaskCell *)[self.tableView cellForRowAtIndexPath:indexPath];

    NSDate *currentDate = [NSDate date];
    NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:currentSession.startDate];
    NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
    
    NSString *timeString = [dateFormatter stringFromDate:timerDate];
    taskCell.taskTime.text = timeString;
}

- (void)startTaskTimerAtIndexPath:(NSIndexPath *)indexPath
{
    currentTask = [self.fetchedResultsController objectAtIndexPath:indexPath];
    currentIndexPath = indexPath;

    currentSession = [NSEntityDescription insertNewObjectForEntityForName:@"Session" inManagedObjectContext:managedObjectContext];
    currentSession.startDate = [NSDate date];
    
    //need to send indexpath with selector
    //will use nsinvocation
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(updateTimerAtIndexPath:)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(updateTimerAtIndexPath:)];
    [invocation setArgument:&indexPath atIndex:2];

    sessionTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                  invocation: invocation
                                                  repeats:YES];
    isRecording = true;
}

- (void)stopCurrentSession
{
    currentSession.endDate = [NSDate date];
    [currentTask addTaskSessionObject:currentSession];
    
    //dnfl: there's a way to override the addTaskSessionObject
    //      to add the current session to totalTime
    NSTimeInterval sessionInterval = [currentSession.endDate timeIntervalSinceDate:currentSession.startDate];
    NSNumber *sessionIntervalNum = [NSNumber numberWithDouble:sessionInterval];
    currentTask.totalTime = [NSNumber numberWithDouble:([currentTask.totalTime doubleValue] + [sessionIntervalNum doubleValue])];

//    NSLog(@"just added %f", [sessionIntervalNum integerValue]);
    NSString *saveBannerText = [NSString stringWithFormat:@"%@ recorded!", [FSBTextUtil stringFromNumSeconds:[NSNumber numberWithInt:[sessionIntervalNum integerValue]] isTruncated:NO]];
    [saveAlertBanner setSaveText:saveBannerText];
    
    //animate banner to y coordinate 63
    [UIView animateWithDuration:0.5 delay:0.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear) animations:^{
        [saveAlertBanner setFrame:CGRectMake(0, 63, saveAlertBanner.frame.size.width, saveAlertBanner.frame.size.height)];
    } completion:^(BOOL finished){
        [UIView animateWithDuration:0.5 delay:1.0 options:(UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveLinear) animations:^{
            [saveAlertBanner setFrame:CGRectMake(0, 0, saveAlertBanner.frame.size.width, saveAlertBanner.frame.size.height)];
        } completion:^(BOOL finished){
            
        }];
    }];
   
    
    [sessionTimer invalidate];
    sessionTimer = nil;
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
    
    NSTimeInterval timeInterval = [currentTask.totalTime doubleValue];
    NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    NSString *timeString = [dateFormatter stringFromDate:timerDate];
    
    FSBTaskCell *taskCell = (FSBTaskCell *)[self.tableView cellForRowAtIndexPath:currentIndexPath];
    taskCell.taskTime.text = timeString;
    
    /*
    double timeInt = timeInterval;
    double tenKHours = 36000000;
    
    
    Progress bar moved to Phase 2
    double prog = timeInt / tenKHours;
    NSLog(@"progress: %f", prog);
    [taskCell.taskProgress setProgress:prog];
    */
    
    isRecording = false;
    
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        FATAL_CORE_DATA_ERROR(error);
        return;
    }
}

- (void)calendarViewControllerDidGoBack:(FSBCalendarViewController *)controller
{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/
/*
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self.managedObjectContext deleteObject:task];
        
        NSError *error;
        if (![self.managedObjectContext save:&error]) {
            FATAL_CORE_DATA_ERROR(error);
            return;
        }
    }
}
*/
/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //no sessions timed
//    if (!isTiming) {
//        [self startTaskTimerAtIndexPath:indexPath];
//    }
//    //current session timed but not the same as the new session
//    else if (currentTask != [self.fetchedResultsController objectAtIndexPath:indexPath]) {
//        [self stopCurrentSession];
//        [self startTaskTimerAtIndexPath:indexPath];
//    }
//    //current session same as new session
//    else {
//        [self stopCurrentSession];
//    }
    CGRect rectInTableView = [self.tableView rectForRowAtIndexPath:indexPath];
    CGFloat offsetPosition = -self.tableView.contentOffset.y + rectInTableView.origin.y;
    BOOL isShifting = NO;
    //if offsetpos is > 393.5 then we need to shift and only if it's opening the cell
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:0];
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.row < [sectionInfo numberOfObjects]) {
        FSBTaskCell *selectedCell = (FSBTaskCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        NSLog(@"is cell animating: %d", selectedCell.isCellAnimating);
        if (!isRecording && !selectedCell.isCellAnimating) {
            // if it's already selected
            if(selectedRowNumber == indexPath.row) {
                selectedRowNumber = -1;
                [selectedCell hideNav];
                NSLog(@"LMOA");
            } else if(selectedRowNumber > -1 && selectedRowNumber != indexPath.row){
                //need to close currently open one!
                FSBTaskCell *currentlySelectedCell = (FSBTaskCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:selectedRowNumber inSection:0]];
                [currentlySelectedCell hideNav];
                currentlySelectedCell.isOpen = NO;
                selectedRowNumber = indexPath.row;
                if (offsetPosition > 393.5f) {
                    isShifting = YES;
                }
                [selectedCell toggleNav];
            } else {
                selectedRowNumber = indexPath.row;
                if (offsetPosition > 393.5f) {
                    isShifting = YES;
                }
                [selectedCell toggleNav];
            }
            selectedCell.isCellAnimating = YES;
        }
        [self hideAddCellKeyboard];
        [self.tableView beginUpdates];
        [self.tableView endUpdates];
        if (isShifting == YES) {
            //if last item is opened this shifts the list so that the open cell is left opened
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    } else {
        [self hideOpenCell];
    }
    
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == selectedRowNumber) {
        return kCellOpenedHeight;
    }
    return kCellHeight;
}

//- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    [self stopCurrentSession];
//    
//}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController == nil) {
        id delegate = [[UIApplication sharedApplication] delegate];
        managedObjectContext = [delegate managedObjectContext];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Task" inManagedObjectContext:managedObjectContext];
        [fetchRequest setEntity:entity];
        
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES];
        [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        
        [fetchRequest setFetchBatchSize:5];
        
        fetchedResultsController = [[NSFetchedResultsController alloc]
                                    initWithFetchRequest:fetchRequest
                                    managedObjectContext:managedObjectContext
                                    sectionNameKeyPath:nil
                                    cacheName:@"Tasks"];
        
        fetchedResultsController.delegate = self;
    }
    
    return fetchedResultsController;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"*** controllerWillChangeContent");
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            NSLog(@"*** controllerDidChangeObject - NSFetchedResultsChangeInsert");
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            NSLog(@"*** controllerDidChangeObject - NSFetchedResultsChangeDelete");
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeUpdate:
            NSLog(@"*** controllerDidChangeObject - NSFetchedResultsChangeUpdate");
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
        case NSFetchedResultsChangeMove:
            NSLog(@"*** controllerDidChangeObject - NSFetchedResultsChangeMove");
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            NSLog(@"*** controllerDidChangeSection - NSFetchedResultsChangeInsert");
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
        case NSFetchedResultsChangeDelete:
            NSLog(@"*** controllerDidChangeSection - NSFetchedResultsChangeDelete");
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
        default:
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    NSLog(@"*** controllerDidChangeContent");
    [self.tableView endUpdates];
}


@end
