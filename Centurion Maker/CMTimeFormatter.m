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

@property (nonatomic) NSUInteger numInvalidTries;

@end

@implementation CMTimeFormatter

- (id)initWithDelegate:(id <CMTimeFormatterDelegate> )delegate {
	self = [super init];
	if (self) {
		self.legalCharacterSet = [NSMutableCharacterSet decimalDigitCharacterSet];
		[self.legalCharacterSet addCharactersInString:@":"];
		self.delegate = delegate;
	}
	return self;
}

- (void)recordInvalidAttempt {
	self.numInvalidTries++;

	if ([self.delegate respondsToSelector:@selector(timeFormatter:enteredInvalidData:)])
		[self.delegate timeFormatter:self enteredInvalidData:self.numInvalidTries];
}

- (BOOL)getObjectValue:(id *)object
             forString:(NSString *)string
      errorDescription:(NSString **)error {
	*object = string;
	return YES;
}

- (NSString *)stringForObjectValue:(id)object {
	return (NSString *)object;
}

- (BOOL)isPartialStringValid:(NSString **)partialStringPtr
       proposedSelectedRange:(NSRangePointer)proposedSelRangePtr
              originalString:(NSString *)origString
       originalSelectedRange:(NSRange)origSelRange
            errorDescription:(NSString **)error {
	if ([*partialStringPtr rangeOfCharacterFromSet :[self.legalCharacterSet invertedSet]].location == NSNotFound) {
		if ([[*partialStringPtr componentsSeparatedByString : @":"] count] > 2
		    || [*partialStringPtr isEqualToString : @":"]) {
			[self recordInvalidAttempt];
			return NO;
		}

		if ([*partialStringPtr rangeOfString : @":"].location != NSNotFound) {
			if ([*partialStringPtr secondsComponent] >= 60) {
				[self recordInvalidAttempt];
				return NO;
			}

			if ([[*partialStringPtr componentsSeparatedByString : @":"][1] length] > 2) {
				[self recordInvalidAttempt];
				return NO;
			}
		}

		if ([[*partialStringPtr numberTrackDuration] doubleValue] <= self.maxSecondsValue) {
			return YES;
		} else {
			[self recordInvalidAttempt];
			return NO;
		}
	}

	[self recordInvalidAttempt];
	return NO;
}

@end
