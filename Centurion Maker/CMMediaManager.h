//
//  CMMediaManager.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 31/05/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CMMediaManager;

@protocol CMMediaManagerDelegate <NSObject>

- (void)mediaManager:(CMMediaManager *)mediaManager changedProgressStatus:(double)progress;

@end

@interface CMMediaManager : NSObject

@property (weak, nonatomic) id<CMMediaManagerDelegate> delegate;

+ (CMMediaManager *)sharedManager;

- (NSDictionary *)metadataForKeys:(NSArray *)keys trackAtURL:(NSURL *)url;

- (void)createCenturionMixAtURL:(NSURL *)url
                     fromTracks:(NSArray *)tracks
                       delegate:(id<CMMediaManagerDelegate>)delegate
                     completion:(void (^)(BOOL success))completionBlock;

- (void)cancelCenturionMix;

@end
