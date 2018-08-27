//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "AVPlayerTracker.h"

// TODO: what if we have multiple players instantiated, what happens with the NSNotifications?

@import AVKit;

@interface NewRelicVideoAgent ()

@property (nonatomic) id<TrackerProtocol> tracker;

@end

@implementation NewRelicVideoAgent

+ (instancetype)sharedInstance {
    static NewRelicVideoAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NewRelicVideoAgent alloc] init];
    });
    return instance;
}

+ (void)startWithPlayer:(id)player {
    if ([player isKindOfClass:[AVPlayer class]]) {
        [[self sharedInstance] setTracker:[[AVPlayerTracker alloc] initWithAVPlayer:(AVPlayer *)player]];
    }
    else {
        [[self sharedInstance] setTracker:nil];
        NSLog(@"⚠️ Not recognized player class. ⚠️");
    }
    
    if ([[self sharedInstance] tracker]) {
        [[[self sharedInstance] tracker] reset];
        [[[self sharedInstance] tracker] setup];
    }
}

@end
