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

#import "DurationFormat.h"
#import "NSPopover+Message.h"
#import "NSManagedObject+Appulse.h"
#import "Track.h"

#define MAX_NUM_TRACKS 150

@interface CMMainViewController () <CMTrackTableViewDelegate, NSTableViewDataSource, NSWindowRestoration, CMMediaManagerDelegate, CMTimeFormatterDelegate>

@property (weak, nonatomic) IBOutlet NSTextField *numTracksLeftField, *progressField, *previewStartField, *previewEndField;
@property (weak, nonatomic) IBOutlet NSSearchField *numTracksSearchField;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *progressIndicator, *previewIndicator;
@property (weak, nonatomic) IBOutlet NSButton *clearSelectionButton, *centurionButton, *addTrackButton, *previewButton;
@property (weak, nonatomic) IBOutlet CMTrackTableView *tracksTableView;

@property (strong, nonatomic) IBOutlet NSArrayController *trackArrayController;
@property (strong, nonatomic) Track *playingTrack;

@property (nonatomic) NSUInteger totalNumTracks;
@property (nonatomic) BOOL creatingCenturion, previewPlaying;

@end

static NSString *DraggedCellIdentifier = @"Track Dragged Cell";

static NSInteger kCenturionNumTracks = 100;
static NSInteger kHourOfPowerNumTracks = 60;

@implementation CMMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		// Initialization code here.
	}

	return self;
}

- (void)loadView {
	[super loadView];

	[self.tracksTableView registerForDraggedTypes:@[DraggedCellIdentifier]];
	[self.tracksTableView setDoubleAction:@selector(preview:)];
}

#pragma mark - First Run

- (void)handleFirstRunOnLaunch {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults valueForKey:FIRST_RUN_KEY]
	    || [[defaults valueForKey:FIRST_RUN_KEY] boolValue]) {
		[NSPopover showRelativeToRect:[self.addTrackButton frame]
		                       ofView:[self view]
		                preferredEdge:CGRectMaxYEdge
		                       string:@"Welcome! Get started by adding tracks into the mix. You can add mutliple batches to make up to 60 or 100 tracks."
		                     maxWidth:260.0];
	}
}

- (void)handleFirstRunTracksAdded {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults valueForKey:FIRST_RUN_KEY]
	    || [[defaults valueForKey:FIRST_RUN_KEY] boolValue]) {
		[NSPopover showRelativeToRect:[self.tracksTableView frame]
		                       ofView:self.tracksTableView
		                preferredEdge:CGRectMinYEdge
		                       string:@"You can re-order the tracks before creating the mix. Also you can set the starting time of a track to be included in the mix by editing the \"Mix Start\" column."
		                     maxWidth:300.0];

		[defaults setValue:@(NO) forKey:FIRST_RUN_KEY];
		[defaults synchronize];
	}
}

- (void)handleFirstTrackPlay {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults valueForKey:FIRST_PLAY_KEY]
	    || [[defaults valueForKey:FIRST_PLAY_KEY] boolValue]) {
		[NSPopover showRelativeToRect:[self.previewButton frame]
		                       ofView:[self view]
		                preferredEdge:CGRectMaxXEdge
		                       string:@"You are previewing the minute long track snippet which will be mixed. You can change the start time of the snippet by editing the \"Mix Start\" column."
		                     maxWidth:300.0];

		[defaults setValue:@(NO) forKey:FIRST_PLAY_KEY];
		[defaults synchronize];
	}
}

#pragma mark - Setters

- (void)setTrackArrayController:(NSArrayController *)trackArrayController {
	if (_trackArrayController != trackArrayController) {
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
		[trackArrayController setSortDescriptors:@[sortDescriptor]];

		_trackArrayController = trackArrayController;
	}
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
	if (_managedObjectContext != managedObjectContext) {
		_managedObjectContext = managedObjectContext;
	}

	[self refreshDisplay];
}

#pragma mark - Logic

- (void)showNotificationSuccess:(BOOL)success {
	NSUserNotification *notification = [[NSUserNotification alloc] init];
	notification.title = (success) ? @"Mix Complete" : @"Mix Error";
	notification.informativeText = (success) ? @"Check it out." : @"Well that sucks.";
	notification.deliveryDate = [NSDate date];
	notification.soundName = NSUserNotificationDefaultSoundName;

	NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
	[center scheduleNotification:notification];
}

- (void)saveAndRefreshData:(BOOL)refresh {
	[(CMAppDelegate *)[NSApp delegate] saveAction : nil];

	if (refresh) {
		[self.trackArrayController rearrangeObjects];
	}
}

- (void)refreshPreviewSliderForTrack:(Track *)track currentTime:(NSInteger)seconds {
	if (!track) {
		[self.previewIndicator setDoubleValue:0];

		[self.previewStartField setStringValue:@"0:00"];
		[self.previewEndField setStringValue:@"1:00"];

		[self.previewButton setTitle:@"Play Preview"];
	} else {
		NSInteger secondsPlayed = seconds - [track.mixStartTime integerValue];

		[self.previewIndicator setDoubleValue:((secondsPlayed / 60.0) * 100)];

		[self.previewStartField setStringValue:[@(secondsPlayed)stringTrackDurationForInput : NO]];
		[self.previewEndField setStringValue:[@(60 - secondsPlayed)stringTrackDurationForInput : NO]];

		[self.previewButton setTitle:@"Stop Preview"];
	}
}

- (void)playSelectedTrack {
	NSInteger clickedRow = [self.tracksTableView clickedRow];
	if (clickedRow == -1) {
		NSIndexSet *selectedSet = [self.tracksTableView selectedRowIndexes];
		if ([selectedSet count] > 0) {
			clickedRow = [selectedSet firstIndex];
		} else {
			return;
		}
	}

	Track *track = [self.trackArrayController arrangedObjects][clickedRow];

	if (![self isValidTrack:track fileManager:[NSFileManager defaultManager]]) {
		[self saveAndRefreshData:NO];

		return;
	}

	CMMediaManager *mediaManager = [CMMediaManager sharedManager];
	mediaManager.delegate = self;

	[self.previewIndicator startAnimation:nil];
	[mediaManager startPreviewTrack:track withCurrentTimeBlock: ^(NSInteger seconds) {
	    [self refreshPreviewSliderForTrack:track currentTime:seconds];

	    if (seconds == ([track.mixStartTime integerValue] + 60)) {
	        [self refreshPreviewSliderForTrack:nil currentTime:-1];
	        [self.previewIndicator stopAnimation:nil];

	        [self stopSelectedTrack];
	        [self.trackArrayController rearrangeObjects];
		}
	}];

	if (self.playingTrack)
		self.playingTrack.playing = @(NO);

	track.playing = @(YES);
	self.playingTrack = track;

	[self saveAndRefreshData:NO];
}

- (void)stopSelectedTrack {
	[[CMMediaManager sharedManager] stopPreview];
	if (self.playingTrack) {
		self.playingTrack.playing = @(NO);
		[self saveAndRefreshData:NO];
	}

	self.playingTrack = nil;

	[self refreshPreviewSliderForTrack:nil currentTime:-1];
}

- (void)resetState {
	[self.progressIndicator setDoubleValue:0];
	[self.progressIndicator stopAnimation:self];

	[self.progressField setStringValue:@"Progress:"];

	[self.clearSelectionButton setEnabled:YES];
	[self.addTrackButton setEnabled:YES];

	self.creatingCenturion = NO;

	[self refreshDisplay];
}

- (BOOL)isValidTrack:(Track *)track fileManager:(NSFileManager *)fileManager {
	track.invalid = @(![fileManager fileExistsAtPath:track.filePath]);

	return ![track.invalid boolValue];
}

- (NSArray *)invalidTracks {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSMutableArray *nonExistingTracks = [[NSMutableArray alloc] init];
	[[self.trackArrayController arrangedObjects] enumerateObjectsUsingBlock: ^(Track *track, NSUInteger idx, BOOL *stop) {
	    if (![self isValidTrack:track fileManager:fileManager]) {
	        [nonExistingTracks addObject:track];
		}
	}];

	if ([nonExistingTracks count] != 0) {
		[self saveAndRefreshData:YES];

		return nonExistingTracks;
	}

	// Refresh the table
	[self.trackArrayController rearrangeObjects];

	return nil;
}

- (void)deleteSelectedtracks {
	[self.trackArrayController removeObjectsAtArrangedObjectIndexes:[self.tracksTableView selectedRowIndexes]];

	[self reorderTracks:[self.trackArrayController arrangedObjects] startingAt:0];

	[self.tracksTableView deselectAll:nil];

	[self saveAndRefreshData:NO];
	[self refreshDisplay];
}

- (void)refreshDisplay {
	NSInteger trackCount = [Track countInContext:self.managedObjectContext];

	[self.centurionButton setEnabled:((trackCount == kCenturionNumTracks)
	                                  || (trackCount == kHourOfPowerNumTracks))];

	[[self.numTracksSearchField cell] setPlaceholderString:[[NSString alloc] initWithFormat:@"Search %li Tracks", trackCount]];

	NSMutableString *trackLeftString = [[NSMutableString alloc] init];
	NSInteger centurionTracksLeft = kCenturionNumTracks - trackCount;
	NSInteger hourOfPowerTracksLeft = kHourOfPowerNumTracks - trackCount;
	if (centurionTracksLeft > 0) {
		[trackLeftString appendFormat:@"Add %li for Centurion", centurionTracksLeft];
	} else if (centurionTracksLeft > 0) {
		[trackLeftString appendFormat:@"Remove %li for Centurion", ABS(centurionTracksLeft)];
	}

	[trackLeftString appendString:@"\n"];

	if (hourOfPowerTracksLeft > 0) {
		[trackLeftString appendFormat:@"Add %li for Hour Of Power", hourOfPowerTracksLeft];
	} else if (hourOfPowerTracksLeft < 0) {
		[trackLeftString appendFormat:@"Remove %li for Hour Of Power", ABS(hourOfPowerTracksLeft)];
	}

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

- (IBAction)selectTracks:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	openPanel.canChooseDirectories = NO;
	openPanel.allowsMultipleSelection = YES;

	NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
	if ([documentController runModalOpenPanel:openPanel forTypes:@[@"mp3", @"m4a"]] == NSModalResponseOK) {
		NSArray *fileURLs = [openPanel URLs];
		NSMutableArray *tooShortTrackNames = [[NSMutableArray alloc] init];

		if (self.totalNumTracks + [fileURLs count] > MAX_NUM_TRACKS) {
            NSAlert *tooManyTracksAlert = [[NSAlert alloc] init];
            tooManyTracksAlert.messageText = @"Added Too Many Tracks";
            tooManyTracksAlert.informativeText = [[NSString alloc] initWithFormat:@"You can only add a maximum of %i tracks.", MAX_NUM_TRACKS];
            [tooManyTracksAlert addButtonWithTitle:@"OK"];
			[tooManyTracksAlert runModal];

			return;
		}

		[fileURLs enumerateObjectsUsingBlock: ^(NSURL *fileURL, NSUInteger idx, BOOL *stop) {
		    NSDictionary *metadataDict = [[CMMediaManager sharedManager] metadataForKeys:@[@"title", @"artist"] trackAtURL:fileURL];

		    if ([metadataDict[@"length"] doubleValue] < 60) {
		        [tooShortTrackNames addObject:metadataDict[@"title"]];
			} else {
		        [Track newEntity:@"Track" inContext:self.managedObjectContext idAttribute:@"identifier" value:[[NSString alloc] initWithFormat:@"%@%@", [fileURL absoluteString], [NSDate date]] onInsert: ^(Track *track) {
		            track.filePath = [fileURL path];
		            track.order = @(self.totalNumTracks + idx);

		            [metadataDict enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
		                [track setValue:obj forKey:key];
					}];
				}];
			}
		}];

		if ([tooShortTrackNames count] != 0) {
			NSString *message = nil;

			if ([tooShortTrackNames count] < 5) {
				NSMutableString *trackNames = [[NSMutableString alloc] init];

				[tooShortTrackNames enumerateObjectsUsingBlock: ^(NSString *name, NSUInteger idx, BOOL *stop) {
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

            NSAlert *tooShortAlert = [[NSAlert alloc] init];
            tooShortAlert.messageText = @"Track Duration Error";
            tooShortAlert.informativeText = message;
            [tooShortAlert addButtonWithTitle:@"OK"];

			[tooShortAlert runModal];
		} else {
			[self handleFirstRunTracksAdded];
		}

		[self saveAndRefreshData:NO];
	}

	[self refreshDisplay];
}

- (IBAction)clearSelectedtracks:(id)sender {
	[self stopSelectedTrack];

	// Remove tracks here
	NSArray *allTracks = [Track findAllInContext:self.managedObjectContext];

	[allTracks enumerateObjectsUsingBlock: ^(Track *track, NSUInteger idx, BOOL *stop) {
	    [self.managedObjectContext deleteObject:track];
	}];

	self.totalNumTracks = 0;

	[self refreshDisplay];

	[self saveAndRefreshData:NO];
}

- (IBAction)centurion:(id)sender {
	if (self.creatingCenturion) {
		[[CMMediaManager sharedManager] cancelCenturionMix];

		[self.clearSelectionButton setEnabled:YES];
		[self.addTrackButton setEnabled:YES];
		[self.centurionButton setTitle:@"Create Centurion"];

		[self.progressIndicator stopAnimation:self];
	} else {
		[self stopSelectedTrack];

		NSArray *invalidTracks = [self invalidTracks];

		if (!invalidTracks) {
			NSSavePanel *savePanel = [NSSavePanel savePanel];
			savePanel.allowedFileTypes = @[@"m4a"];
			[savePanel beginSheetModalForWindow:[[self view] window] completionHandler: ^(NSInteger result) {
			    if (result == NSFileHandlingPanelOKButton) {
			        self.creatingCenturion = YES;

			        [self.clearSelectionButton setEnabled:NO];
			        [self.addTrackButton setEnabled:NO];
			        [self.centurionButton setTitle:@"Cancel Mix"];

			        [[CMMediaManager sharedManager] createCenturionMixAtURL:[savePanel URL] fromTracks:[self.trackArrayController arrangedObjects] delegate:self completion: ^(BOOL success) {
			            [self showNotificationSuccess:success];

			            [self resetState];
					}];
				}
			}];
		} else {
            NSAlert *invalidTracksAlert = [[NSAlert alloc] init];
            invalidTracksAlert.messageText = @"Invalid Tracks";
            invalidTracksAlert.informativeText = [[NSString alloc] initWithFormat:@"There are %li tracks whos original files could not be located. These tracks are highlighted in red. Replace them before creating a mix.", [invalidTracks count]];
            [invalidTracksAlert addButtonWithTitle:@"OK"];
            
			[invalidTracksAlert runModal];
		}
	}
}

- (IBAction)openInFinder:(id)sender {
	Track *track = [self.trackArrayController arrangedObjects][[self.tracksTableView selectedRow]];

	if ([track.invalid boolValue]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"File Error";
        alert.informativeText = [[NSString alloc] initWithFormat:@"Make sure the original file for \"%@\" exists or that it matches the sample rate of the other tracks.", track.title];
        [alert addButtonWithTitle:@"OK"];

		[alert runModal];
	} else {
		NSArray *fileURLs = @[[[NSURL alloc] initFileURLWithPath:track.filePath]];
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
	}
}

- (IBAction)preview:(id)sender {
	[self handleFirstTrackPlay];

	if ([sender isKindOfClass:[NSButton class]]) {
		if (self.previewPlaying) {
			[self stopSelectedTrack];
		} else {
			[self playSelectedTrack];
		}

		self.previewPlaying = !self.previewPlaying;
	} else {
		[self playSelectedTrack];

		self.previewPlaying = YES;
	}

	[self.trackArrayController rearrangeObjects];
}

#pragma mark - Formatter delegate

- (void) timeFormatter:(CMTimeFormatter *)timeFormatter
    enteredInvalidData:(NSUInteger)numInvalidTries {
	if ((numInvalidTries % 3) == 0) {
		CGRect frame = [self.tracksTableView frameOfCellAtColumn:4
		                                                     row:[self.tracksTableView selectedRow]];
		[NSPopover showRelativeToRect:frame
		                       ofView:self.tracksTableView
		                preferredEdge:NSMaxXEdge
		                       string:@"The mix start time must be at least a minute before the track's end time."
		                     maxWidth:250.0];
	}
}

#pragma mark - Media delegate

- (void)mediaManager:(CMMediaManager *)mediaManaher didFailWithErrorDescription:(NSString *)description {
    NSAlert *errorAlert = [[NSAlert alloc] init];
    errorAlert.messageText = @"Error Making Mix";
    errorAlert.informativeText = description;
    [errorAlert addButtonWithTitle:@"OK"];

	[errorAlert runModal];

	[self saveAndRefreshData:YES];
	[self resetState];
}

- (void)mediaManager:(CMMediaManager *)mediaManager exportProgressStatus:(double)progress {
	[self.progressIndicator setDoubleValue:progress];

	if ([self.progressIndicator doubleValue] > 99.0) {
		[self.progressIndicator stopAnimation:self];
		[self.progressField setStringValue:@"Complete!"];
	}
}

- (void)mediaManagerWillStartExporting:(CMMediaManager *)mediaManager {
	[self.progressField setStringValue:@"Exporting Mix..."];
	[self.progressIndicator setIndeterminate:NO];
}

- (void)mediaManagerDidStartProcessingMedia:(CMMediaManager *)mediaManager {
	[self.progressIndicator startAnimation:self];

	[self.progressField setStringValue:@"Processing Tracks..."];
	[self.progressIndicator setIndeterminate:YES];
}

#pragma mark - Table View Logic

- (NSArray *)itemsWithOrderBetween:(NSInteger)lowValue and:(NSInteger)highValue {
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"order >= %i && order <= %i", lowValue, highValue];

	return [self tracksWithPredicate:fetchPredicate];
}

- (NSArray *)itemsWithOrderGreaterThanOrEqualTo:(NSInteger)value {
	NSPredicate *fetchPredicate = [NSPredicate predicateWithFormat:@"order >= %i", value];

	return [self tracksWithPredicate:fetchPredicate];
}

- (NSArray *)tracksWithPredicate:(NSPredicate *)predicate {
	return [Track fetchRequest: ^(NSFetchRequest *fs) {
	    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES];
	    [fs setSortDescriptors:@[sortDescriptor]];
	    [fs setPredicate:predicate];
	} inContext:self.managedObjectContext];
}

- (NSInteger)reorderTracks:(NSArray *)tracks startingAt:(NSInteger)value {
	__block NSInteger currentTrack = value;

	if (tracks && ([tracks count] > 0)) {
		[tracks enumerateObjectsUsingBlock: ^(Track *track, NSUInteger idx, BOOL *stop) {
		    track.order = @(currentTrack);
		    currentTrack++;
		}];
	}

	return currentTrack;
}

#pragma mark - Tracks Table view

- (void)tableView:(NSTableView *)tableView didPressDeleteKeyForRowIndexes:(NSIndexSet *)indexSet {
	[self deleteSelectedtracks];

	[self reorderTracks:[Track findAllInContext:self.managedObjectContext] startingAt:0];
	[self.trackArrayController rearrangeObjects];
}

- (BOOL)tableView:(NSTableView *)tableView shouldRespondToDeleteKeyForRowIndexes:(NSIndexSet *)indexSet {
	return !self.creatingCenturion;
}

#pragma mark - Table view

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	Track *track = [self.trackArrayController arrangedObjects][row];

	return !([track.invalid boolValue] || [track.playing boolValue]);
}

- (void)  tableView:(NSTableView *)tableView
    willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn *)tableColumn
                row:(NSInteger)row {
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
			if ([track.playing boolValue]) {
				[cell setTextColor:[NSColor blueColor]];
			} else {
				[cell setTextColor:[NSColor blackColor]];
			}
		}
	}

	if ([tableColumn.identifier isEqualToString:@"Mix Start"]) {
		CMTimeFormatter *formatter = [[CMTimeFormatter alloc] initWithDelegate:self];
		formatter.maxSecondsValue = ([track.length integerValue] - 60);
		[cell setFormatter:formatter];
	}
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
	[pboard declareTypes:[NSArray arrayWithObject:DraggedCellIdentifier] owner:self];
	[pboard setData:data forType:DraggedCellIdentifier];

	return ([tableView.selectedRowIndexes count] <= 1) && !self.creatingCenturion;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo> )info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)dropOperation {
	if ([[info draggingSource] isEqual:self.tracksTableView]) {
		if (dropOperation == NSTableViewDropOn) [tableView setDropRow:row dropOperation:NSTableViewDropAbove];

		return NSDragOperationMove;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo> )info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
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
	[self reorderTracks:endItemsArray startingAt:currentOrder];

	[self saveAndRefreshData:YES];

	return YES;
}

#pragma mark - Window

- (void)windowDidBecomeMain:(NSNotification *)notification {
	[self handleFirstRunOnLaunch];
}

- (BOOL)windowShouldClose:(id)sender {
	if (self.creatingCenturion) {
        NSAlert *closeAlert = [[NSAlert alloc] init];
        closeAlert.messageText = @"Export In Progress";
        closeAlert.informativeText = @"Centurion Maker is in the process of exporting a mix. Are you sure you wish to close the application and cancel the export?";
        [closeAlert addButtonWithTitle:@"Yes"];
        [closeAlert addButtonWithTitle:@"No"];
        
        [closeAlert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
            [NSApp terminate:self];
        }];

        return NO;
	}

	return YES;
}

- (void)windowWillClose:(NSNotification *)notification {
	if (self.creatingCenturion) {
		[[CMMediaManager sharedManager] cancelCenturionMix];
	}

	[self stopSelectedTrack];
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
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
