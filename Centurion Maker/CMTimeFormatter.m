//
//  CMTimeFormatter.m
//  Centurion Maker
//
//  Created by Jad Osseiran on 2/06/13.
//  Copyright (c) 2013 Jad. All rights reserved.
//

#import "CMTimeFormatter.h"

#import "DurationFormat.h"

@interface CMTimeFormatter ()

@property (strong, nonatomic) NSMutableCharacterSet *legalCharacterSet;

@end

@implementation CMTimeFormatter

- (id)init
{
    self = [super init];
    if (self) {
        self.legalCharacterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
        [self.legalCharacterSet addCharactersInString:@":"];
    }
    return self;
}

- (BOOL)getObjectValue:(id *)object
             forString:(NSString *)string
      errorDescription:(NSString **)error
{
    *object = string;
    return YES;
}

- (NSString *)stringForObjectValue:(id)object
{
    return (NSString *)object;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error
{
    if ([*partialStringPtr rangeOfCharacterFromSet:[self.legalCharacterSet invertedSet]].location == NSNotFound) {
        
        if ([[*partialStringPtr componentsSeparatedByString:@":"] count] > 2
            || [*partialStringPtr isEqualToString:@":"]) {
            return NO;
        }
        
        if ([*partialStringPtr rangeOfString:@":"].location != NSNotFound) {
            if ([*partialStringPtr secondsComponent] >= 60)
                return NO;
            if ([[*partialStringPtr componentsSeparatedByString:@":"][1] length] > 2)
                return NO;
        }
                
        double startTime = [[*partialStringPtr numberTrackDuration] doubleValue];
        return startTime <= self.maxSecondsValue;
    }

    return NO;
}

@end
