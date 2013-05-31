//
//  CMMainViewController.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 12/03/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "CMMainViewController.h"

#import "CMAppDelegate.h"
#import "CMTrackTableView.h"

#import "NSManagedObject+Appulse.h"
#import "Track.h"

@interface CMMainViewController () <CMTrackTableViewDelegate, NSTableViewDataSource>

@property (weak, nonatomic) IBOutlet NSTextField *numTracksField, *progressField;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak, nonatomic) IBOutlet NSButton *clearSelectionButton, *createCenturionButton, *addTrackButton;
@property (weak, nonatomic) IBOutlet CMTrackTableView *tracksTableView;

@property (strong, nonatomic) IBOutlet NSArrayController *trackArrayController;

@property (strong, nonatomic) NSURL *saveURL;
@property (strong, nonatomic) AVMutableComposition *centurionMixComposition;
@property (strong, nonatomic) AVAssetExportSession *exportSession;
@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@property (nonatomic) NSUInteger totalNumTracks;

@end

static NSString *DraggedCellIdentifier = @"Track Dragged Cell";

@implementation CMMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.        
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    
    [self.tracksTableView registerForDraggedTypes:@[DraggedCellIdentifier]];
}

#pragma mark - Setters

- (void)setTrackArrayController:(NSArrayController *)trackArrayController
{
    if (_trackArrayController != trackArrayController) {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
        [trackArrayController setSortDescriptors:@[sortDescriptor]];
        
        _trackArrayController = trackArrayController;
    }
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != managedObjectContext) {
        _managedObjectContext = managedObjectContext;
    }
    
    [self refreshData];
}

#pragma mark - Logic

- (void)refreshData
{
    NSInteger trackCount = [Track countInContext:self.managedObjectContext];
    
    [self.createCenturionButton setEnabled:(trackCount == 100)];
    
    [self.numTracksField setStringValue:[[NSString alloc] initWithFormat:@"%li tracks", trackCount]];
    
    self.totalNumTracks = trackCount;
}

- (void)setProgressTimer
{
    self.progressIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(updateProgressIndicator)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)updateProgressIndicator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressIndicator setDoubleValue:(100 * self.exportSession.progress)];
        
        if ([self.progressIndicator doubleValue] > 99.0) {
            [self.progressIndicator stopAnimation:self];
            [self.progressField setStringValue:@"Complete!"];
        }
    });
}

- (CMTime)addAsset:(AVAsset *)asset
           toTrack:(AVMutableCompositionTrack *)compositionTrack
     insertionTime:(CMTime)insertionTime
      withDuration:(CMTime)duration
         startTime:(CMTime)startTime idx:(NSInteger)idx
{
    NSError *error = nil;
    
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];

//    NSLog(@"Track: %@", tracks);

    if (idx > 0) {
        NSLog(@"%@, %li", tracks, idx);
    }
    
    AVAssetTrack *clipAudioTrack = [tracks lastObject];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(insertionTime, duration);
    [compositionTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:&error];
    
    return CMTimeAdd(startTime, timeRangeInAsset.duration);
}

#pragma mark - Actions

- (IBAction)selectTracks:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = YES;
        
    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    if ([documentController runModalOpenPanel:openPanel forTypes:@[@"mp3", @"m4a"]] == NSOKButton) {
        NSArray *fileURLs = [openPanel URLs];
        
        __block AVAsset *asset = nil;
        __block NSArray *metadata = nil;

        [fileURLs enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger idx, BOOL *stop) {
                        
            asset = [AVAsset assetWithURL:fileURL];
            metadata = [asset commonMetadata];
            if ([metadata count] == 0) {
                // Handle warning message here.
            }
                        
            [Track newEntity:@"Track" inContext:self.managedObjectContext idAttribute:@"identifier" value:[[NSString alloc] initWithFormat:@"%@%@", [fileURL absoluteString], [NSDate date]] onInsert:^(Track *track) {
                track.localFileURL = [fileURL path];
                track.order = @(self.totalNumTracks + (idx + 1));
                track.length = @(CMTimeGetSeconds(asset.duration));
                
                for (AVMetadataItem *item in metadata) {
                    if ([item.commonKey isEqualToString:@"title"]) {
                        track.name = item.stringValue;
                    } else if ([item.commonKey isEqualToString:@"artist"]) {
                        track.artist = item.stringValue;
                    }
                }
            }];
        }];
        
        [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
    }
    
    [self refreshData];
}

- (IBAction)clearSelectedtracks:(id)sender
{
    // Remove tracks here
    NSArray *allTracks = [Track findAllInContext:self.managedObjectContext];
    
    [allTracks enumerateObjectsUsingBlock:^(Track *track, NSUInteger idx, BOOL *stop) {
        [self.managedObjectContext deleteObject:track];
    }];
    
    self.totalNumTracks = 0;
    
    [self refreshData];
    
    [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
}

- (IBAction)createCenturion:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = @[@"m4a"];
    [savePanel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton) {
            self.saveURL = [savePanel URL];
            
            [self.progressIndicator startAnimation:self];
            
            [self createCenturionMix];
        }
    }];
}

#pragma mark - Table View Logic

- (NSArray *)itemsWithOrderBetween:(NSInteger)lowValue and:(NSInteger)highValue
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"order >= %i && order <= %i", lowValue, highValue];
    
    return [self tracksWithPredicate:fetchPredicate];
}

- (NSArray *)itemsWithOrderGreaterThanOrEqualTo:(NSInteger)value
{
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"order >= %i", value];
    
	return [self tracksWithPredicate:fetchPredicate];
}

- (NSArray *)tracksWithPredicate:(NSPredicate *)predicate
{
    return [Track fetchRequest:^(NSFetchRequest *fs) {
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
        [fs setSortDescriptors:@[sortDescriptor]];
        [fs setPredicate:predicate];
    } inContext:self.managedObjectContext];
}

- (NSInteger)reorderTracks:(NSArray *)tracks startingAt:(NSInteger)value
{
    __block NSInteger currentTrack = value;
        
    if (tracks && ([tracks count] > 0) ) {
        [tracks enumerateObjectsUsingBlock:^(Track *track, NSUInteger idx, BOOL *stop) {
            track.order = @(currentTrack);
            currentTrack++;
        }];
    }
    
    return currentTrack;
}

#pragma mark - NSTableView

- (void)tableView:(NSTableView *)tableView didPressDeleteKeyForRowIndexes:(NSIndexSet *)indexSet
{
    [self.trackArrayController removeObjectsAtArrangedObjectIndexes:indexSet];
    
    [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
    
    [self refreshData];
}

- (BOOL)tableView:(NSTableView *)tableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	[pboard declareTypes:[NSArray arrayWithObject:DraggedCellIdentifier] owner:self];
	[pboard setData:data forType:DraggedCellIdentifier];
    
    return ([tableView.selectedRowIndexes count] <= 1);
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if ([[info draggingSource] isEqual:self.tracksTableView]) {
        if (dropOperation == NSTableViewDropOn)
            [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        
        return NSDragOperationMove;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation
{
    NSPasteboard *pasteboard = [info draggingPasteboard];
    NSData *rowData = [pasteboard dataForType:DraggedCellIdentifier];
    NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    
    NSArray *allItemsArray = [self.trackArrayController arrangedObjects];
    NSMutableArray *draggedItemsArray = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
    
    NSUInteger currentItemIndex;
    NSRange range = NSMakeRange(0, [rowIndexes lastIndex] + 1);
    while ([rowIndexes getIndexes:&currentItemIndex maxCount:1 inIndexRange:&range] > 0) {
        NSManagedObject *thisItem = [allItemsArray objectAtIndex:currentItemIndex];
        [draggedItemsArray addObject:thisItem];
    }
    
    for (NSInteger i = 0; i < [draggedItemsArray count]; i++) {
        Track *track = draggedItemsArray[i];
        track.order = @(-1);
    }
    
    NSInteger tempRow = (row == 0) ? -1 : row - 1;
    
    NSArray *startItemsArray = [self itemsWithOrderBetween:0 and:tempRow];
    NSArray *endItemsArray = [self itemsWithOrderGreaterThanOrEqualTo:row];
    
    NSInteger currentOrder = 0;
    
    currentOrder = [self reorderTracks:startItemsArray startingAt:0];
    currentOrder = [self reorderTracks:draggedItemsArray startingAt:currentOrder];
    currentOrder = [self reorderTracks:endItemsArray startingAt:currentOrder];
    
    [self.trackArrayController rearrangeObjects];
    
    [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
    
    return YES;
}

#pragma mark - AVFoundation

- (void)createCenturionMix
{
    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
	dispatch_async(exportQueue, ^{
        
        self.centurionMixComposition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *compositionAudioTrack = [self.centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        CMTime nextClipStartTime = kCMTimeZero;
        
        NSInteger idx = 0;
        for (Track *track in [self.trackArrayController arrangedObjects]) {
            AVAsset *asset = [AVAsset assetWithURL:[[NSURL alloc] initFileURLWithPath:track.localFileURL]];
            
            nextClipStartTime = [self addAsset:asset
                                      toTrack:compositionAudioTrack
                                insertionTime:CMTimeMakeWithSeconds(60, 1)
                                 withDuration:CMTimeMakeWithSeconds(59, 1)
                                    startTime:nextClipStartTime idx:idx];
            
            AVAsset *beepAsset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"ComputerData" withExtension:@"caf"]];
            
            nextClipStartTime = [self addAsset:beepAsset
                                       toTrack:compositionAudioTrack
                                 insertionTime:kCMTimeZero
                                  withDuration:CMTimeMakeWithSeconds(1, 1)
                                     startTime:nextClipStartTime idx:-1];
            
            idx++;
        }
                
        [self exportWithCompletionHandler:^(AVAssetExportSessionStatus status) {
            [self.progressIndicator stopAnimation:self];
        } async:YES];
    });
}

- (void)exportWithCompletionHandler:(void (^)(AVAssetExportSessionStatus status))completionBlock
                              async:(BOOL)async
{
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:self.centurionMixComposition
                                                           presetName:AVAssetExportPresetAppleM4A];
    
    if (async) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setProgressTimer];
        });
    } else {
        [self setProgressTimer];
    }
    
    // Configure export session, output with all our parameters
    self.exportSession.outputURL = self.saveURL;
    self.exportSession.outputFileType = AVFileTypeAppleM4A;
    
    // Perform the export
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^(void){
        switch (self.exportSession.status) {
            case AVAssetExportSessionStatusCompleted:
                NSLog(@"Success!");
                break;
            case AVAssetExportSessionStatusFailed:
                NSLog(@"Failed:%@", self.exportSession.error);
                break;
                
            case AVAssetExportSessionStatusCancelled:
                NSLog(@"Canceled:%@", self.exportSession.error);
                break;
                
            default:
                break;
        }
        
        if (completionBlock) {
            if (async) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock(self.exportSession.status);
                });
            } else {
                completionBlock(self.exportSession.status);
            }
        }
    }];
}

@end
