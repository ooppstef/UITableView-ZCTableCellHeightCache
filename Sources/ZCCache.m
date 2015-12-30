//
//  ZCCache.m
//  TableTest
//
//  Created by charles on 15/12/29.
//  Copyright © 2015年 charles. All rights reserved.
//

#import "ZCCache.h"

typedef void (^cacheWillEvictObjectHandler) (NSCache *cache,id obj);

@interface ZCCache () <NSCacheDelegate>

@property (nonatomic, assign) NSInteger                   count;
@property (nonatomic, strong) NSMutableArray              *keys;
@property (nonatomic, strong) NSMutableArray              *values;
@property (nonatomic, copy  ) cacheWillEvictObjectHandler handler;

@end

@implementation ZCCache

#pragma mark - life cycle

- (id)init {
    if (self = [super init]) {
        _keys = [@[] mutableCopy];
        _values = [@[] mutableCopy];
        self.delegate = self;
    }
    return self;
}

#pragma mark - subscript

- (id)objectForKeyedSubscript:(id)key {
    return [self objectForKey:key];
}

- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)aKey {
    [self setObject:object forKey:aKey];
}

#pragma mark - public methods

- (NSInteger)count {
    return _count;
}

- (NSArray *)allKeys {
    return _keys;
}

- (void)cacheWillEvictObject:(void (^) (NSCache *cache, id obj))handler {
    _handler = handler;
}

#pragma mark - override methods

- (void)setObject:(id)obj forKey:(id)key {
    if (![_keys containsObject:key]) {
        _count++;
        [_keys addObject:key];
        [_values addObject:@((uintptr_t)key)];
    }
    [super setObject:obj forKey:key];
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g {
    if (![_keys containsObject:key]) {
        _count++;
        [_keys addObject:key];
        [_values addObject:@((uintptr_t)key)];
    }
    [super setObject:obj forKey:key cost:g];
}

- (void)removeObjectForKey:(id)key {
    if ([_keys containsObject:key]) {
        _count--;
        NSUInteger index = [_keys indexOfObject:key];
        [_keys removeObjectAtIndex:index];
        [_values removeObjectAtIndex:index];
        [super removeObjectForKey:key];
    }
}

- (void)removeAllObjects {
    [_keys removeAllObjects];
    [_values removeAllObjects];
    _count = 0;
    [super removeAllObjects];
}

- (void)setDelegate:(id<NSCacheDelegate>)delegate {
    [super setDelegate:self];
}

- (NSString *)description {
    NSString *desc;
    for (NSString *key in _keys) {
        desc = [desc stringByAppendingFormat:@"%@\r",[self[key] description]];
    }
    return desc;
}

#pragma mark - delegate methods

- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    NSNumber *value = @((uintptr_t)obj);
    if ([_values containsObject:value]) {
        NSUInteger index = [_values indexOfObject:value];
        [_keys removeObjectAtIndex:index];
        [_values removeObjectAtIndex:index];
        _count--;
    }
    !_handler ? : _handler(cache,obj);
}

@end
