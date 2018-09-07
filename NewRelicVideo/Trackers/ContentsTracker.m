//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "TrackerAutomat.h"
#import "EventDefs.h"

#define ACTION_FILTER @"CONTENT_"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@interface ContentsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@property (nonatomic) NSTimeInterval requestTimestamp;
@property (nonatomic) NSTimeInterval trackerReadyTimestamp;
@property (nonatomic) NSTimeInterval heartbeatTimestamp;
@property (nonatomic) NSTimeInterval totalPlaytime;
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval timeSinceStartedTimestamp;
@property (nonatomic) NSTimeInterval timeSincePausedTimestamp;
@property (nonatomic) NSTimeInterval timeSinceBufferBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceSeekBeginTimestamp;

@end

@implementation ContentsTracker

- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
    if (!_contentsAttributeGetters) {
        _contentsAttributeGetters = @{
                                      @"contentId": [NSValue valueWithPointer:@selector(getVideoId)],
                                      @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                                      @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                                      @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                                      @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
                                      @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                                      @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
                                      @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
                                      @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
                                      @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
                                      @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMutted)],
                                      @"contentIsAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
                                      @"contentIsFullscreen": [NSValue valueWithPointer:@selector(getIsFullscreen)],
                                      }.mutableCopy;
    }
    return _contentsAttributeGetters;
}

- (void)updateContentsAttributes {
    for (NSString *key in self.contentsAttributeGetters) {
        [self updateContentsAttribute:key];
    }
}

- (void)setContentsOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self setOptionKey:key value:value forAction:ACTION_FILTER];
}

- (void)updateContentsAttribute:(NSString *)attr {
    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.contentsAttributeGetters];
    if (val) [self setOptionKey:attr value:val forAction:ACTION_FILTER];
}

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        self.trackerReadyTimestamp = TIMESTAMP;
    }
    return self;
}

- (void)reset {
    [super reset];
    
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
    self.playtimeSinceLastEventTimestamp = 0;
    self.timeSinceStartedTimestamp = 0;
    
    [self updateContentsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateContentsAttributes];
    
    [self setContentsOptionKey:@"timeSinceTrackerReady" value:@(1000.0f * TIMESINCE(self.trackerReadyTimestamp))];
    [self setContentsOptionKey:@"timeSinceRequested" value:@(1000.0f * TIMESINCE(self.requestTimestamp))];
    
    if (self.heartbeatTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.heartbeatTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.requestTimestamp))];
    }
    
    if (self.automat.state == TrackerStatePlaying) {
        self.totalPlaytime += TIMESINCE(self.totalPlaytimeTimestamp);
        self.totalPlaytimeTimestamp = TIMESTAMP;
    }
    [self setContentsOptionKey:@"totalPlaytime" value:@(1000.0f * self.totalPlaytime)];
    
    if (self.playtimeSinceLastEventTimestamp == 0) {
        self.playtimeSinceLastEventTimestamp = TIMESTAMP;
    }
    [self setContentsOptionKey:@"playtimeSinceLastEvent" value:@(1000.0f * TIMESINCE(self.playtimeSinceLastEventTimestamp))];
    self.playtimeSinceLastEventTimestamp = TIMESTAMP;
    
    if (self.timeSinceStartedTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceStarted" value:@(1000.0f * TIMESINCE(self.timeSinceStartedTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceStarted" value:@0];
    }
    
    if (self.timeSincePausedTimestamp > 0) {
        [self setOptionKey:@"timeSincePaused" value:@(1000.0f * TIMESINCE(self.timeSincePausedTimestamp)) forAction:CONTENT_RESUME];
    }
    else {
        [self setOptionKey:@"timeSincePaused" value:@0 forAction:CONTENT_RESUME];
    }
    
    if (self.timeSinceBufferBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceBufferBegin" value:@(1000.0f * TIMESINCE(self.timeSinceBufferBeginTimestamp)) forAction:CONTENT_BUFFER_END];
    }
    else {
        [self setOptionKey:@"timeSinceBufferBegin" value:@0 forAction:CONTENT_BUFFER_END];
    }
    
    if (self.timeSinceSeekBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceSeekBegin" value:@(1000.0f * TIMESINCE(self.timeSinceSeekBeginTimestamp)) forAction:CONTENT_SEEK_END];
    }
    else {
        [self setOptionKey:@"timeSinceSeekBegin" value:@0 forAction:CONTENT_SEEK_END];
    }
}

- (void)sendRequest {
    self.requestTimestamp = TIMESTAMP;
    [super sendRequest];
}

- (void)sendStart {
    if (self.automat.state == TrackerStateStarting) {
        self.timeSinceStartedTimestamp = TIMESTAMP;
    }
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendStart];
}

- (void)sendEnd {
    [super sendEnd];
    self.totalPlaytime = 0;
}

- (void)sendPause {
    self.timeSincePausedTimestamp = TIMESTAMP;
    [super sendPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendResume];
}

- (void)sendSeekStart {
    self.timeSinceSeekBeginTimestamp = TIMESTAMP;
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    self.timeSinceBufferBeginTimestamp = TIMESTAMP;
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    self.heartbeatTimestamp = TIMESTAMP;
    [super sendHeartbeat];
}

- (void)sendRenditionChange {
    [super sendRenditionChange];
}

- (void)sendError {
    [super sendError];
}

#pragma mark - Getters

- (NSNumber *)getIsAd {
    return @NO;
}

- (NSString *)getPlayerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getPlayerVersion {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerVersion {
    OVERWRITE_STUB
    return nil;
}

#pragma mark - Timer

- (void)trackerTimeEvent {
    // TODO: bitrate stuff
}

@end
