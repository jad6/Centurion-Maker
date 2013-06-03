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

@property (strong, nonatomic) AVAssetExportSession *exportSession;

@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@property (strong, nonatomic) AVPlayer *player;

@end

@implementation CMMediaManager

+ (CMMediaManager *)sharedManager
{
    static __DISPATCH_ONCE__ CMMediaManager *singletonObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singletonObject = [[self alloc] init];
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
         startTime:(CMTime)startTime
          forTrack:(Track *)track
{
    NSError *error = nil;
    
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if ([tracks count] == 0) {
        NSLog(@"Error on track: %@", track);
    }
    
    AVAssetTrack *clipAudioTrack = [tracks lastObject];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(insertionTime, duration);
    [compositionTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:&error];
    
    return CMTimeAdd(startTime, timeRangeInAsset.duration);
}

- (void)exportComposition:(AVComposition *)composition
                    toURL:(NSURL *)url
         completion:(void (^)(AVAssetExportSessionStatus status))completionBlock
{
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:composition
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
        
        if (completionBlock) {
            completionBlock(self.exportSession.status);
        }
    }];
}

#pragma mark - Actions

- (void)updateProgressIndicator
{
    if ([self.delegate respondsToSelector:@selector(mediaManager:exportProgressStatus:)]) {
        [self.delegate mediaManager:self exportProgressStatus:(100 * self.exportSession.progress)];
    }
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
                       delegate:(id<CMMediaManagerDelegate>)delegate
                     completion:(void (^)(BOOL success))completionBlock
{
    self.delegate = delegate;
    
    [self startProgressTimer];
    
    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
    dispatch_async(exportQueue, ^{
        
        AVMutableComposition *centurionMixComposition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *compositionAudioTrack = [centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        CMTime nextClipStartTime = kCMTimeZero;
        
        for (Track *track in tracks) {
            AVAsset *asset = [AVAsset assetWithURL:[[NSURL alloc] initFileURLWithPath:track.filePath]];
            
            nextClipStartTime = [self addAsset:asset
                                       toTrack:compositionAudioTrack
                                 insertionTime:CMTimeMakeWithSeconds([track.mixStartTime integerValue], 1)
                                  withDuration:CMTimeMakeWithSeconds(59, 1)
                                     startTime:nextClipStartTime
                                      forTrack:track];
            
            AVAsset *beepAsset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"ComputerData" withExtension:@"caf"]];
            
            nextClipStartTime = [self addAsset:beepAsset
                                       toTrack:compositionAudioTrack
                                 insertionTime:kCMTimeZero
                                  withDuration:CMTimeMakeWithSeconds(1, 1)
                                     startTime:nextClipStartTime
                                      forTrack:nil];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(mediaManagerWillStartExporting:)]) {
                [self.delegate mediaManagerWillStartExporting:self];
            }
        });
        
        [self exportComposition:centurionMixComposition
                          toURL:url
                     completion:^(AVAssetExportSessionStatus status) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                             
                             [self endProgressTimer];
                             
                             BOOL success = (status == AVAssetExportSessionStatusCompleted);
                             
                             if ([self.delegate respondsToSelector:@selector(mediaManager:exportProgressStatus:)]) {
                                 [self.delegate mediaManager:self exportProgressStatus:(success) ? 100 : 0];
                             }
                             
                             if (completionBlock) {
                                 completionBlock(success);
                             }
                         });
                     }];
    });
}

- (void)cancelCenturionMix
{    
    [self.exportSession cancelExport];
}

- (void)startPreviewTrack:(Track *)track
     withCurrentTimeBlock:(void (^)(NSInteger seconds))currentTimeBlcok;
{
    if (self.player)
        [self stopPreview];
    
    self.player = [[AVPlayer alloc] initWithURL:[[NSURL alloc] initFileURLWithPath:track.filePath]];
    
    [self.player seekToTime:CMTimeMakeWithSeconds(([track.mixStartTime floatValue] + 1), 1)];
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1)
                                         queue:dispatch_queue_create("timeObserver", NULL)
                                    usingBlock:^(CMTime time) {
                                        if (currentTimeBlcok) {
                                            currentTimeBlcok(time.value / time.timescale);
                                        }
                                    }];
    
    [self.player play];
}

- (void)stopPreview
{
    [self.player pause];
    self.player = nil;
}

@end
