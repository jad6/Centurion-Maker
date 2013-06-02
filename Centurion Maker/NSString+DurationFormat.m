//
//  NSString+DurationFormat.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 2/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "NSString+DurationFormat.h"

@implementation NSString (DurationFormat)

- (NSNumberFormatter *)formatter
{
    static __DISPATCH_ONCE__ NSNumberFormatter *formatter = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
    });
    
    return formatter;
}

- (NSNumber *)numberTrackDuration
{
    if ([self length] == 0)
        return @(0);
    
    NSInteger minutes = 0;
    NSInteger seconds = 0;
    
    NSArray *split = [self componentsSeparatedByString:@":"];
    if ([split count] == 2) {
        seconds = [[[self formatter] numberFromString:split[1]] integerValue];
        
        if (seconds < 10 && [split[1] length] == 1)
            seconds *= 10;
    }
    
    minutes = [[[self formatter] numberFromString:split[0]] integerValue];
    
    return @((minutes * 60) + seconds);
}

- (NSInteger)minutesComponent
{
    NSArray *split = [self componentsSeparatedByString:@":"];
    return [[[self formatter] numberFromString:split[0]] integerValue];
}

- (NSInteger)secondsComponent
{
    NSArray *split = [self componentsSeparatedByString:@":"];
    if ([split count] == 2) {
        NSInteger seconds = [[[self formatter] numberFromString:split[1]] integerValue];
        
        if (seconds < 10 && [split[1] length] == 1)
            seconds *= 10;
        
        return seconds;
    } else {
        return 0;
    }
}

@end
