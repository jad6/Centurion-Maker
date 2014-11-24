//
//  NSString+DurationFormat.h
//  Centurion Maker
//
//  Created by Jad Osseiran on 2/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

@import Foundation;

@interface NSString (DurationFormat)

- (NSNumber *)numberTrackDuration;

- (NSInteger)minutesComponent;
- (NSInteger)secondsComponent;

@end
