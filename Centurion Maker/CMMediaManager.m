//
//  CMMediaManager.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import AVFoundation;

#import "CMMediaManager.h"
#import "CMTrack.h"

@interface CMMediaManager ()

@property (strong, nonatomic) AVAssetExportSession *exportSession;

@property (strong, nonatomic) NSTimer *progressIndicatorTimer;

@property (strong, nonatomic) AVPlayer *player;

@end

@implementation CMMediaManager

+ (instancetype)sharedManager {
    static __DISPATCH_ONCE__ id singletonObject = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        singletonObject = [[self alloc] init];
    });
    
    return singletonObject;
}

#pragma mark - Logic

#warning message
- (NSNumber *)sampleRateOfTrack:(CMTrack *)track {
    NSError *error = nil;
    AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[[NSURL alloc] initFileURLWithPath:track.filePath] error:&error];
    
    return audioPlayer.settings[AVSampleRateKey];
}

- (BOOL)handleMutlipleSampleRates:(NSMutableDictionary *)tracksSampleRates
                 errorDescription:(NSString **)descrtiprion {
    NSArray *allKeys = [tracksSampleRates allKeys];
    if ([allKeys count] == 1) {
        return YES;
    }
    
    __block NSInteger maxNumTracks = 0;
    __block NSNumber *majoritySampleRate = nil;
    [tracksSampleRates enumerateKeysAndObjectsUsingBlock: ^(NSNumber *key, NSArray *tracks, BOOL *stop) {
        NSInteger numTracks = [tracks count];
        if (maxNumTracks < numTracks) {
            maxNumTracks = numTracks;
            majoritySampleRate = key;
        }
    }];
    [tracksSampleRates removeObjectForKey:majoritySampleRate];
    
    NSMutableString *invalidTracks = [[NSMutableString alloc] init];
    __block NSInteger numInvalidTracks = 0;
    [tracksSampleRates enumerateKeysAndObjectsUsingBlock: ^(NSNumber *sampleRate, NSArray *tracks, BOOL *stop) {
        for (CMTrack * track in tracks) {
            [invalidTracks appendFormat:@"#%@ - \"%@\" at %@Hz\n", track.order, track.title, sampleRate];
            track.invalid = @(YES);
            numInvalidTracks++;
        }
    }];
    
    NSString *filePlural = (numInvalidTracks > 1) ? @"these files" : @"this file";
    NSMutableString *mutableDescription = [[NSMutableString alloc] initWithString:@"Multiple sample rates were found. "];
    [mutableDescription appendFormat:@"The majority of the tracks are at %@Hz. However a different sample rate is observed for %@:\n\n", majoritySampleRate, filePlural];
    [mutableDescription appendString:invalidTracks];
    [mutableDescription appendFormat:@"\nPlease fix %@ by converting it with your preferred tool and try again.", filePlural];
    
    *descrtiprion = mutableDescription;
    
    return NO;
}

- (void)startProgressTimer {
    self.progressIndicatorTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                   target:self
                                                                 selector:@selector(updateProgressIndicator)
                                                                 userInfo:nil
                                                                  repeats:YES];
}

- (void)endProgressTimer {
    [self.progressIndicatorTimer invalidate];
    self.progressIndicatorTimer = nil;
}

- (CMTime)addAsset:(AVAsset *)asset
           toTrack:(AVMutableCompositionTrack *)compositionTrack
     insertionTime:(CMTime)insertionTime
      withDuration:(CMTime)duration
         startTime:(CMTime)startTime {
    NSError *error = nil;
    
    NSArray *tracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    AVAssetTrack *clipAudioTrack = [tracks lastObject];
    CMTimeRange timeRangeInAsset = CMTimeRangeMake(insertionTime, duration);
    [compositionTrack insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:startTime error:&error];
    
    return CMTimeAdd(startTime, timeRangeInAsset.duration);
}

- (void)exportComposition:(AVComposition *)composition
                    toURL:(NSURL *)url
               completion:(void (^)(AVAssetExportSessionStatus status))completionBlock {
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:composition
                                                           presetName:AVAssetExportPresetAppleM4A];
    
    // Configure export session, output with all our parameters
    self.exportSession.outputURL = url;
    self.exportSession.outputFileType = AVFileTypeAppleM4A;
    
    // Perform the export
    [self.exportSession exportAsynchronouslyWithCompletionHandler: ^(void) {
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

- (void)updateProgressIndicator {
    if ([self.delegate respondsToSelector:@selector(mediaManager:exportProgressStatus:)]) {
        [self.delegate mediaManager:self exportProgressStatus:(100 * self.exportSession.progress)];
    }
}

#pragma mark - Public

- (NSDictionary *)metadataForKeys:(NSArray *)keys trackAtURL:(NSURL *)url {
    NSMutableDictionary *metadataDict = [[NSMutableDictionary alloc] init];
    
    AVAsset *asset = [AVAsset assetWithURL:url];
    NSArray *metadata = [asset commonMetadata];
    if ([metadata count] == 0) {
        // Handle warning message here.
    }
    
    [metadataDict setObject:@(CMTimeGetSeconds(asset.duration)) forKey:@"length"];
    
    for (NSString *key in keys) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"commonKey LIKE %@", key];
        AVMetadataItem *item = [[metadata filteredArrayUsingPredicate:predicate] lastObject];
        if (item) {
            [metadataDict setObject:item.stringValue forKey:key];
        }
    }
    
    return metadataDict;
}

- (void)createCenturionMixAtURL:(NSURL *)url
                     fromTracks:(NSArray *)tracks
                       delegate:(id <CMMediaManagerDelegate> )delegate
                     completion:(void (^)(BOOL success))completionBlock {
    self.delegate = delegate;
    
    [self startProgressTimer];
    
    dispatch_queue_t exportQueue = dispatch_queue_create("export", NULL);
    dispatch_async(exportQueue, ^{
        if ([self.delegate respondsToSelector:@selector(mediaManagerDidStartProcessingMedia:)]) {
            [self.delegate mediaManagerDidStartProcessingMedia:self];
        }
        
        AVMutableComposition *centurionMixComposition = [[AVMutableComposition alloc] init];
        AVMutableCompositionTrack *compositionAudioTrack = [centurionMixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        
        AVAsset *beepAsset = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"ComputerData" withExtension:@"caf"]];
        CMTime nextClipStartTime = kCMTimeZero;
        CMTime trackTime = CMTimeAbsoluteValue(CMTimeAdd(CMTimeMake(-60, 1), beepAsset.duration));
        
#warning This is here because of a bug with mixing different sample rates. Might be fixed later, WWDC 2013 engineers know about it. Thanks David.
        NSMutableDictionary *tracksSampleRates = [[NSMutableDictionary alloc] init];
        
        for (CMTrack *track in tracks) {
            AVAsset *asset = [AVAsset assetWithURL:[[NSURL alloc] initFileURLWithPath:track.filePath]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSNumber *sampleRate = [self sampleRateOfTrack:track];
                id sampleRateTracks = tracksSampleRates[sampleRate];
                
                if (!sampleRateTracks) {
                    tracksSampleRates[sampleRate] = [[NSMutableArray alloc] initWithObjects:track, nil];
                } else {
                    [sampleRateTracks addObject:track];
                }
            });
            
            nextClipStartTime = [self addAsset:asset
                                       toTrack:compositionAudioTrack
                                 insertionTime:CMTimeMakeWithSeconds([track.mixStartTime integerValue], 1)
                                  withDuration:trackTime
                                     startTime:nextClipStartTime];
            
            nextClipStartTime = [self addAsset:beepAsset
                                       toTrack:compositionAudioTrack
                                 insertionTime:kCMTimeZero
                                  withDuration:beepAsset.duration
                                     startTime:nextClipStartTime];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *description = nil;
            if (![self handleMutlipleSampleRates:tracksSampleRates
                                errorDescription:&description]) {
                [self.exportSession cancelExport];
                [self endProgressTimer];
                
                [self.delegate mediaManager:self didFailWithErrorDescription:description];
            }
            
            if ([self.delegate respondsToSelector:@selector(mediaManagerWillStartExporting:)]) {
                [self.delegate mediaManagerWillStartExporting:self];
            }
        });
        
        [self exportComposition:centurionMixComposition
                          toURL:url
                     completion: ^(AVAssetExportSessionStatus status) {
                         dispatch_async(dispatch_get_main_queue(), ^{
                             [self endProgressTimer];
                             
                             BOOL success = (status == AVAssetExportSessionStatusCompleted);
                             
                             if ([self.delegate respondsToSelector:@selector(mediaManager:exportProgressStatus:)]) {
                                 [self.delegate mediaManager:self exportProgressStatus:(success) ? 100:0];
                             }
                             
                             if (completionBlock) {
                                 completionBlock(success);
                             }
                         });
                     }];
    });
}

- (void)cancelCenturionMix {
    [self.exportSession cancelExport];
}

- (void)startPreviewTrack:(CMTrack *)track
     withCurrentTimeBlock:(void (^)(NSInteger seconds))currentTimeBlcok;
{
    if (self.player)
        [self stopPreview];
    
    self.player = [[AVPlayer alloc] initWithURL:[[NSURL alloc] initFileURLWithPath:track.filePath]];
    
    [self.player seekToTime:CMTimeMakeWithSeconds(([track.mixStartTime floatValue] + 1), 1)];
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1, 1)
                                              queue:dispatch_queue_create("timeObserver", NULL)
                                         usingBlock: ^(CMTime time) {
                                             if (currentTimeBlcok) {
                                                 currentTimeBlcok(time.value / time.timescale);
                                             }
                                         }];
    
    [self.player play];
}

- (void)stopPreview {
    [self.player pause];
    self.player = nil;
}

@end
