//
//  ZCCache.h
//  TableTest
//
//  Created by charles on 15/12/29.
//  Copyright © 2015年 charles. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZCCache : NSCache

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id<NSCopying>)aKey;
- (NSInteger)count;
- (NSArray *)allKeys;
- (void)cacheWillEvictObject:(void (^) (NSCache *cache, id obj))handler;

@end
