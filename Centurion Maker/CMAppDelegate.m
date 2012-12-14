//
//  CMAppDelegate.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 14/12/12.
//  Copyright (c) 2012 Jad. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "CMAppDelegate.h"

#define DEBUG 1

typedef void (^exportBlock)(AVAssetExportSessionStatus status);

@interface CMAppDelegate ()

@property (strong, nonatomic) IBOutlet NSTextField *numTracksField, *progressField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong, nonatomic) IBOutlet NSButton *clearSelectionButton, *createCenturionButton, *addTrackButton;

@property (strong, nonatomic) NSURL *saveURL;
@property (strong, nonatomic) AVAsset *beepAsset;
@property (strong, nonatomic) AVMutableComposition *centurionMixComposition;
@property (strong, nonatomic) AVAssetExportSession *exportSession;
@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@end

@implementation CMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application.
    self.fileURLs = [[NSMutableArray alloc] init];
    
    self.beepAsset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"ComputerData" withExtension:@"caf"]];
    
    [self.progressField setHidden:YES];
    [self.progressIndicator setHidden:YES];
    
    [self.clearSelectionButton setEnabled:NO];
        
    [self updateFileURLs];
}

#pragma mark - Actions

- (IBAction)selectTracks:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = YES;
    
    NSDocumentController *documentController = [NSDocumentController sharedDocumentController];
    if ([documentController runModalOpenPanel:openPanel forTypes:[NSArray arrayWithObjects:@"mp3", @"m4a", nil]] == NSOKButton) {
        [self.fileURLs addObjectsFromArray:[openPanel URLs]];
        [self updateFileURLs];
    }
}

- (IBAction)clearSelectedtracks:(id)sender
{
    [self.fileURLs removeAllObjects];
    [self updateFileURLs];
}

- (IBAction)createCenturion:(id)sender
{
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.allowedFileTypes = [NSArray arrayWithObject:@"m4a"];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        
        if (result == NSFileHandlingPanelOKButton) {
            self.saveURL = [savePanel URL];
            
            [self.progressField setHidden:NO];
            [self.progressIndicator setHidden:NO];
            [self.progressIndicator startAnimation:self];
            
            [self createCenturionMixFromURLs:self.fileURLs];
        }
    }];
}

#pragma mark - Logic

- (void)updateProgressIndicator
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressIndicator.doubleValue = 100 * self.exportSession.progress;
        
        if (self.progressIndicator.doubleValue > 99.0) {
            [self.progressIndicator stopAnimation:self];
            self.progressField.stringValue = @"Complete!";
        }
    });
}

- (void)updateFileURLs
{
    switch (self.fileURLs.count) {
        case 0:
            self.numTracksField.stringValue = @"Select 100 files to use in the centurion.";
            [self.clearSelectionButton setEnabled:NO];
            [self.createCenturionButton setEnabled:NO];
            [self.addTrackButton setEnabled:YES];
            break;
            
        case 100:
            [self.clearSelectionButton setEnabled:YES];
            [self.createCenturionButton setEnabled:YES];
            [self.addTrackButton setEnabled:NO];
            break;
            
        default:
            self.numTracksField.stringValue = [NSString stringWithFormat:@"%lu tracks selected", self.fileURLs.count];
            [self.clearSelectionButton setEnabled:YES];
            [self.createCenturionButton setEnabled:NO];
            [self.addTrackButton setEnabled:YES];
            break;
    }
}

- (CMTime)addAsset:(AVAsset *)asset
         toTrack:(AVMutableCompositionTrack *)compositionTrack
   insertionTime:(CMTime)insertionTime
    withDuration:(CMTime)duration
       startTime:(CMTime)startTime 
{
    NSError *error = nil;

    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack *clipAudioTrack = [tracks lastObject];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(insertionTime, duration);
    [compositionTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:&error];
    
    return CMTimeAdd(startTime, timeRangeInAsset.duration);
}

#pragma mark - AV foundation

- (void)createCenturionMixFromURLs:(NSArray *)fileURLs
{    
    self.centurionMixComposition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *compositionAudioTrack = [self.centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime nextClipStartTime = kCMTimeZero;
    
    for (NSURL *fileURL in fileURLs) {
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        
        nextClipStartTime =[self addAsset:asset
                                  toTrack:compositionAudioTrack
                            insertionTime:CMTimeMakeWithSeconds(60, 1)
                             withDuration:CMTimeMakeWithSeconds(59, 1)
                                startTime:nextClipStartTime];
        
        nextClipStartTime = [self addAsset:self.beepAsset
                                   toTrack:compositionAudioTrack
                             insertionTime:kCMTimeZero
                              withDuration:CMTimeMakeWithSeconds(1, 1)
                                 startTime:nextClipStartTime];
    }
    
    [self exportWithCOmpletionHandler:^(AVAssetExportSessionStatus status) {
        [self.progressIndicator stopAnimation:self];
    }];
}

- (void)exportWithCOmpletionHandler:(exportBlock)completion
{
    self.progressIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(updateProgressIndicator)
                                                                 userInfo:nil
                                                                  repeats:YES];
    
    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
	dispatch_async(exportQueue, ^{
        self.exportSession = [AVAssetExportSession exportSessionWithAsset:self.centurionMixComposition
                                                                                presetName:AVAssetExportPresetAppleM4A];
        
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

            if (completion) {
                completion(self.exportSession.status);
            }
        }];
    });
}

#pragma mark - CoreData

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "com.jad.Centurion_Maker" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"com.jad.Centurion_Maker"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Centurion_Maker" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Centurion_Maker.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _persistentStoreCoordinator = coordinator;
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];

    return _managedObjectContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
