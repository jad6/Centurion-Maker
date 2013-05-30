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

#import "NSManagedObject+Appulse.h"
#import "Track.h"

@interface CMMainViewController ()

@property (strong, nonatomic) IBOutlet NSTextField *numTracksField, *progressField;
@property (strong, nonatomic) IBOutlet NSProgressIndicator *progressIndicator;
@property (strong, nonatomic) IBOutlet NSButton *clearSelectionButton, *createCenturionButton, *addTrackButton;

@property (strong, nonatomic) IBOutlet NSArrayController *trackArrayController;

@property (strong, nonatomic) NSURL *saveURL;
@property (strong, nonatomic) AVAsset *beepAsset;
@property (strong, nonatomic) AVMutableComposition *centurionMixComposition;
@property (strong, nonatomic) AVAssetExportSession *exportSession;
@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@property (nonatomic) NSUInteger totalNumTracks;

@end

@implementation CMMainViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.        
        self.beepAsset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"ComputerData" withExtension:@"caf"]];
        
        [self.progressField setHidden:YES];
        [self.progressIndicator setHidden:YES];
    }
    
    return self;
}

#pragma mark - Setters

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != managedObjectContext) {
        _managedObjectContext = managedObjectContext;
        self.managedObjectContext = managedObjectContext;
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
                track.localFileURL = [fileURL absoluteString];
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
            
            [self.progressField setHidden:NO];
            [self.progressIndicator setHidden:NO];
            [self.progressIndicator startAnimation:self];
            
            [self createCenturionMix];
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

- (void)createCenturionMix
{
    self.centurionMixComposition = [[AVMutableComposition alloc] init];
    AVMutableCompositionTrack *compositionAudioTrack = [self.centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTime nextClipStartTime = kCMTimeZero;
    
    for (Track *track in [self.trackArrayController arrangedObjects]) {
        AVAsset *asset = [AVAsset assetWithURL:[[NSURL alloc] initFileURLWithPath:track.localFileURL]];
        
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

- (void)exportWithCOmpletionHandler:(void (^)(AVAssetExportSessionStatus status))completion;
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

@end
