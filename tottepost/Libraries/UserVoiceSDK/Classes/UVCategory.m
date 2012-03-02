//
//  UVCategory.m
//  UserVoice
//
//  Created by UserVoice on 12/15/09.
//  Copyright 2009 UserVoice Inc. All rights reserved.
//

#import "UVCategory.h"
#import "NSString+UVHTMLEntities.h"


@implementation UVCategory

@synthesize categoryId;
@synthesize name;

- (id)initWithDictionary:(NSDictionary *)dict {
	if (self = [super init]) {
		self.categoryId = [(NSNumber *)[dict objectForKey:@"id"] integerValue];
		self.name = [[self objectOrNilForDict:dict key:@"name"] stringByDecodingHTMLEntities];
	}
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"categoryId: %d\nname: %@", self.categoryId, self.name];
}

- (void)dealloc {
    self.name = nil;
    [super dealloc];
}

@end
