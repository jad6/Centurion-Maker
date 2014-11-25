//
//  CMCMTrack.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 25/11/2014.
//  Copyright (c) 2014 Jad. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface CMTrack : NSManagedObject

@property (nonatomic, retain) NSString * artist;
@property (nonatomic, retain) NSString * filePath;
@property (nonatomic, retain) NSString * identifier;
@property (nonatomic, retain) NSNumber * invalid;
@property (nonatomic, retain) NSNumber * length;
@property (nonatomic, retain) NSNumber * mixStartTime;
@property (nonatomic, retain) NSNumber * order;
@property (nonatomic, retain) NSNumber * playing;
@property (nonatomic, retain) NSString * title;

@end
