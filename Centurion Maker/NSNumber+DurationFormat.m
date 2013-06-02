//
//  NSNumber+DurationFormat.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 2/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "NSNumber+DurationFormat.h"

@implementation NSNumber (DurationFormat)

- (NSString *)stringTrackDuration
{
    NSInteger seconds = [self integerValue];
    
    NSInteger formattedSeconds = (seconds % 60);
    NSInteger formattedMinutes = (seconds / 60);
    
    // Make sure that the seconds are in order of 2 decimals
    NSString *extraZeroString = @"";
    if (formattedSeconds < 10) {
        formattedSeconds *= 10;
        
        if (formattedSeconds == 0) {
            extraZeroString = @"0";
        }
    }
    
    return [[NSString alloc] initWithFormat:@"%li:%li%@", formattedMinutes, formattedSeconds, extraZeroString];
}

@end
