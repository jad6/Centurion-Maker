//
//  CMMediaManager.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "CMMediaManager.h"

#import "Track.h"

@interface CMMediaManager ()

@property (strong, nonatomic) AVMutableComposition *centurionMixComposition;
@property (strong, nonatomic) AVAssetExportSession *exportSession;

@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@end

@implementation CMMediaManager

+ (CMMediaManager *)sharedManagerWithDelegate:(id<CMMediaManagerDelegate>)delegate
{
    static __DISPATCH_ONCE__ CMMediaManager *singletonObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singletonObject = [[self alloc] init];
        singletonObject.delegate = delegate;
    });
    
    return singletonObject;
}

#pragma mark - Logic

- (void)startProgressTimer
{
    self.progressIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(updateProgressIndicator)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)endProgressTimer
{
    [self.progressIndicatorTimer invalidate];
    self.progressIndicatorTimer = nil;
}

- (CMTime)addAsset:(AVAsset *)asset
           toTrack:(AVMutableCompositionTrack *)compositionTrack
     insertionTime:(CMTime)insertionTime
      withDuration:(CMTime)duration
         startTime:(CMTime)startTime idx:(NSInteger)idx
{
    NSError *error = nil;
    
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    AVAssetTrack *clipAudioTrack = [tracks lastObject];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(insertionTime, duration);
    [compositionTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:&error];
    
    return CMTimeAdd(startTime, timeRangeInAsset.duration);
}

- (void)exportToURL:(NSURL *)url
         completion:(void (^)(AVAssetExportSessionStatus status))completionBlock
{
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:self.centurionMixComposition
                                                           presetName:AVAssetExportPresetAppleM4A];
    
    // Configure export session, output with all our parameters
    self.exportSession.outputURL = url;
    self.exportSession.outputFileType = AVFileTypeAppleM4A;
    
    // Perform the export
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^(void) {
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
        
        
        dispatch_async(dispatch_get_main_queue(), ^{            
            if (completionBlock) {
                completionBlock(self.exportSession.status);
            }
        });
    }];
}

#pragma mark - Actions

- (void)updateProgressIndicator
{
    [self.delegate mediaManager:self changedProgressStatus:(100 * self.exportSession.progress)];
}

#pragma mark - Public

- (NSDictionary *)metadataForKeys:(NSArray *)keys trackAtURL:(NSURL *)url
{
    NSMutableDictionary *metadataDict = [[NSMutableDictionary alloc] init];
    
    AVAsset *asset = [AVAsset assetWithURL:url];
    NSArray *metadata = [asset commonMetadata];
    if ([metadata count] == 0) {
        // Handle warning message here.
    }

    [metadataDict setObject:@(CMTimeGetSeconds(asset.duration)) forKey:@"length"];
    
    [keys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"commonKey LIKE %@", key];
        AVMetadataItem *item = [[metadata filteredArrayUsingPredicate:predicate] lastObject];
        if (item) {
            [metadataDict setObject:item.stringValue forKey:key];
        }
    }];
    
    return metadataDict;
}

- (void)createCenturionMixAtURL:(NSURL *)url
                     fromTracks:(NSArray *)tracks
                     completion:(void (^)(BOOL success))completionBlock
{
    [self startProgressTimer];

    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
    dispatch_async(exportQueue, ^{
        
        self.centurionMixComposition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *compositionAudioTrack = [self.centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        CMTime nextClipStartTime = kCMTimeZero;
        
        NSInteger idx = 0;
        for (Track *track in tracks) {
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
        
        [self exportToURL:url completion:^(AVAssetExportSessionStatus status) {
            [self endProgressTimer];

            BOOL success = (status == AVAssetExportSessionStatusCompleted);
            
            [self.delegate mediaManager:self changedProgressStatus:(success) ? 100 : 0];
            
            if (completionBlock) {
                completionBlock(success);
            }
        }];
    });
}

- (void)cancelCenturionMix
{    
    [self.exportSession cancelExport];
}

@end
