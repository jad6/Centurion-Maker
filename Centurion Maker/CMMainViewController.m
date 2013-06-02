//
//  CMMainViewController.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 12/03/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMMainViewController.h"

#import "CMAppDelegate.h"
#import "CMMediaManager.h"
#import "CMTrackTableView.h"
#import "CMTimeFormatter.h"

#import "NSManagedObject+Appulse.h"
#import "Track.h"

@interface CMMainViewController () <CMTrackTableViewDelegate, NSTableViewDataSource, NSWindowRestoration, CMMediaManagerDelegate>

@property (weak, nonatomic) IBOutlet NSTextField *numTracksField, *numTracksLeftField, *progressField;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak, nonatomic) IBOutlet NSButton *clearSelectionButton, *centurionButton, *addTrackButton;
@property (weak, nonatomic) IBOutlet CMTrackTableView *tracksTableView;

@property (strong, nonatomic) IBOutlet NSArrayController *trackArrayController;

@property (nonatomic) NSUInteger totalNumTracks;
@property (nonatomic) BOOL creatingCenturion;

@end

static NSString *DraggedCellIdentifier = @"Track Dragged Cell";

static NSInteger kCenturionNumTracks = 100;
static NSInteger kHourOfPowerNumTracks = 60;

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

- (NSArray *)invalidTracks
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableArray *nonExistingTracks = [[NSMutableArray alloc] init];
    [[self.trackArrayController arrangedObjects] enumerateObjectsUsingBlock:^(Track *track, NSUInteger idx, BOOL *stop) {
        if (![fileManager fileExistsAtPath:track.filePath]) {
            track.invalid = @(YES);
            [nonExistingTracks addObject:track];
        } else {
            track.invalid = @(NO);
        }
    }];
    
    if ([nonExistingTracks count] != 0) {
        [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
        [self.trackArrayController rearrangeObjects];
        
        return nonExistingTracks;
    }
    
    // Refresh the table
    [self.trackArrayController rearrangeObjects];
    
    return nil;
}

- (void)refreshData
{
    NSInteger trackCount = [Track countInContext:self.managedObjectContext];
    
    [self.centurionButton setEnabled:((trackCount == kCenturionNumTracks)
                                      || (trackCount == kHourOfPowerNumTracks))];
    
    [self.numTracksField setStringValue:[[NSString alloc] initWithFormat:@"%li tracks", trackCount]];
    
    NSMutableString *trackLeftString = [[NSMutableString alloc] init];
    NSInteger centurionTracksLeft = kCenturionNumTracks - trackCount;
    NSInteger hourOfPowerTracksLeft = kHourOfPowerNumTracks - trackCount;
    if (centurionTracksLeft > 0)
        [trackLeftString appendFormat:@"%li left for Centurion", centurionTracksLeft];
    if (centurionTracksLeft > 0 && hourOfPowerTracksLeft > 0)
        [trackLeftString appendString:@"\n"];
    if (hourOfPowerTracksLeft > 0)
        [trackLeftString appendFormat:@"%li left for Hour Of Power", hourOfPowerTracksLeft];
    [self.numTracksLeftField setStringValue:trackLeftString];
    
    NSString *createString = @"Create Mix";
    if (centurionTracksLeft == 0)
        createString = @"Create Centurion";
    if (hourOfPowerTracksLeft == 0)
        createString = @"Create Hour Of Power";
    [self.centurionButton setTitle:createString];
    
    self.totalNumTracks = trackCount;
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
        NSMutableArray *tooShortTrackNames = [[NSMutableArray alloc] init];
        
        [fileURLs enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger idx, BOOL *stop) {
            
            NSDictionary *metadataDict = [[CMMediaManager sharedManager] metadataForKeys:@[@"title", @"artist"] trackAtURL:fileURL];
            
            if ([metadataDict[@"length"] doubleValue] < 60) {
                [tooShortTrackNames addObject:metadataDict[@"title"]];
            } else {
                [Track newEntity:@"Track" inContext:self.managedObjectContext idAttribute:@"identifier" value:[[NSString alloc] initWithFormat:@"%@%@", [fileURL absoluteString], [NSDate date]] onInsert:^(Track *track) {
                    track.filePath = [fileURL path];
                    track.order = @(self.totalNumTracks + idx);
                    
                    [metadataDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        [track setValue:obj forKey:key];
                    }];
                }];
            }
        }];
        
        if ([tooShortTrackNames count] != 0) {
            NSString *message = nil;
            
            if ([tooShortTrackNames count] < 5) {
                NSMutableString *trackNames = [[NSMutableString alloc] init];
                
                [tooShortTrackNames enumerateObjectsUsingBlock:^(NSString *name, NSUInteger idx, BOOL *stop) {
                    if (idx == 0) {
                        [trackNames appendFormat:@"\n\"%@\"\n", name];
                    } else {
                        [trackNames appendFormat:@"\"%@\"\n", name];
                    }
                }];
                
                message = [[NSString alloc] initWithFormat:@"These tracks:%@are shorter than a minute. They have not been added to the list.", trackNames];
            } else {
                message = [[NSString alloc] initWithFormat:@"There are %li tracks which are shorter than a minute. They have not been added to the list.", [tooShortTrackNames count]];
            }
            
            NSAlert *tooShortAlert = [NSAlert alertWithMessageText:@"Track Duration Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", message];
            [tooShortAlert runModal];
        }
        
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

- (IBAction)centurion:(id)sender
{
    if (self.creatingCenturion) {
        
        [[CMMediaManager sharedManager] cancelCenturionMix];
        
        [self.clearSelectionButton setEnabled:YES];
        [self.addTrackButton setEnabled:YES];
        [self.centurionButton setTitle:@"Create Centurion"];

        [self.progressIndicator stopAnimation:self];        
    } else {
        NSArray *invalidTracks = [self invalidTracks];
        
        if (!invalidTracks) {
            NSSavePanel *savePanel = [NSSavePanel savePanel];
            savePanel.allowedFileTypes = @[@"m4a"];
            [savePanel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
                if (result == NSFileHandlingPanelOKButton) {
                    
                    self.creatingCenturion = YES;
                    
                    [self.clearSelectionButton setEnabled:NO];
                    [self.addTrackButton setEnabled:NO];
                    [self.centurionButton setTitle:@"Cancel Centurion"];
                    
                    [self.progressIndicator startAnimation:self];
                    
                    [[CMMediaManager sharedManager] createCenturionMixAtURL:[savePanel URL] fromTracks:[self.trackArrayController arrangedObjects] delegate:self completion:^(BOOL success) {
                        [self.progressIndicator setDoubleValue:0];
                        [self.progressIndicator stopAnimation:self];
                        
                        [self.progressField setStringValue:@"Progress:"];
                        
                        [self.clearSelectionButton setEnabled:YES];
                        [self.addTrackButton setEnabled:YES];
                        
                        self.creatingCenturion = NO;
                        
                        [self refreshData];
                    }];
                }
            }];
        } else {
            NSAlert *invalidTracksAlert = [NSAlert alertWithMessageText:@"Invalid Tracks" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"There are %li tracks whos original files could not be located. These tracks are highlighted in red. Replace them before creating a mix.", [invalidTracks count]];
            
            [invalidTracksAlert runModal];
        }
    }
}

- (IBAction)openInFinder:(id)sender
{
    Track *track = [self.trackArrayController arrangedObjects][[self.tracksTableView selectedRow]];
    
    if ([track.invalid boolValue]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"File Not Found" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The original file for \"%@\" could not be found.", track.title];
        [alert runModal];
    } else {
        NSArray *fileURLs = @[[[NSURL alloc] initFileURLWithPath:track.filePath]];
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    }
}

#pragma mark - Media delegate

- (void)mediaManager:(CMMediaManager *)mediaManager changedProgressStatus:(double)progress
{
    [self.progressIndicator setDoubleValue:progress];
    
    if ([self.progressIndicator doubleValue] > 99.0) {
        [self.progressIndicator stopAnimation:self];
        [self.progressField setStringValue:@"Complete!"];
    }
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

#pragma mark - Tracks Table view

- (void)tableView:(NSTableView *)tableView didPressDeleteKeyForRowIndexes:(NSIndexSet *)indexSet
{
    [self.trackArrayController removeObjectsAtArrangedObjectIndexes:indexSet];
    
    [self reorderTracks:[self.trackArrayController arrangedObjects] startingAt:0];
    
    [tableView deselectAll:nil];
    
    [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
    
    [self refreshData];
}

- (BOOL)tableView:(NSTableView *)tableView shouldRespondToDeleteKeyForRowIndexes:(NSIndexSet *)indexSet
{
    return !self.creatingCenturion;
}

#pragma mark - Table view

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row
{
    Track *track = [self.trackArrayController arrangedObjects][row];
    if ([track.invalid boolValue]) {
        if ([tableColumn.identifier isEqualToString:@"Path"]) {
            [cell setTitle:@"Error"];
        } else {
            [cell setTextColor:[NSColor redColor]];
        }
    } else {
        if ([tableColumn.identifier isEqualToString:@"Path"]) {
            [cell setTitle:@"Show"];
        } else {
            [cell setTextColor:[NSColor blackColor]];
        }
    }
    
    if ([tableColumn.identifier isEqualToString:@"Mix Start"]) {
        CMTimeFormatter *formatter = [[CMTimeFormatter alloc] init];
        formatter.maxSecondsValue = ([track.length integerValue] - 60);
        [cell setFormatter:formatter];
    }
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:DraggedCellIdentifier] owner:self];
    [pboard setData:data forType:DraggedCellIdentifier];
    
    return ([tableView.selectedRowIndexes count] <= 1) && !self.creatingCenturion;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation
{
    if ([[info draggingSource] isEqual:self.tracksTableView]) {
        if (dropOperation == NSTableViewDropOn) [tableView setDropRow:row dropOperation:NSTableViewDropAbove];
        
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
        
    [(CMAppDelegate *)[NSApp delegate] saveAction:nil];
    
    [self.trackArrayController rearrangeObjects];
    
    return YES;
}

#pragma mark - NSAlert

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == 0) {
        [[CMMediaManager sharedManager] cancelCenturionMix];
        [[[self view] window] close];
    }
}

#pragma mark - Window

- (BOOL)windowShouldClose:(id)sender
{
    if (self.creatingCenturion) {
        NSAlert *closeAlert = [NSAlert alertWithMessageText:@"Export In Progress" defaultButton:@"No" alternateButton:@"Yes" otherButton:nil informativeTextWithFormat:@"Centurion Maker is in the process of exporting a mix. Are you sure you wish to close the application and cancel the export?"];
        [closeAlert beginSheetModalForWindow:[[self view] window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
        return NO;
    }
    
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (self.creatingCenturion) {
        [[CMMediaManager sharedManager] cancelCenturionMix];
    }
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    // Get the window from the window controller,
    // which is stored as an outlet by the delegate.
    // Both the app delegate and window controller are
    // created when the main nib file is loaded.
    CMAppDelegate *appDelegate = (CMAppDelegate *)[[NSApplication sharedApplication] delegate];
    NSWindow *mainWindow = appDelegate.window;
    
    // Pass the window to the provided completion handler.
    completionHandler(mainWindow, nil);
}

@end
