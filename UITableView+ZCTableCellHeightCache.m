//
//  UITableView+ZCTableCellHeightCache.m
//  MeClassManager
//
//  Created by charles on 15/11/25.
//  Copyright © 2015年 com.meclass. All rights reserved.
//

#import "UITableView+ZCTableCellHeightCache.h"
#import <objc/runtime.h>


@implementation UITableView (ZCTableCellHeightCache)

#pragma mark - swizzling

+ (void)load {
    NSMutableArray *selectors = [@[] mutableCopy];
    [selectors addObject:@"reloadData"];
    [selectors addObject:@"insertSections:withRowAnimation:"];
    [selectors addObject:@"deleteSections:withRowAnimation:"];
    [selectors addObject:@"reloadSections:withRowAnimation:"];
    [selectors addObject:@"moveSection:toSection:"];
    [selectors addObject:@"insertRowsAtIndexPaths:withRowAnimation:"];
    [selectors addObject:@"deleteRowsAtIndexPaths:withRowAnimation:"];
    [selectors addObject:@"reloadRowsAtIndexPaths:withRowAnimation:"];
    [selectors addObject:@"moveRowAtIndexPath:toIndexPath:"];
    
    Class tableViewClazz = [self class];
    
    for (NSString *oriSelector in selectors) {
        NSString *swizzledSelector = [NSString stringWithFormat:@"zc_%@",oriSelector];
        Method oriMethod = class_getInstanceMethod(tableViewClazz, NSSelectorFromString(oriSelector));
        Method swizzledMethod = class_getInstanceMethod(tableViewClazz, NSSelectorFromString(swizzledSelector));
        method_exchangeImplementations(oriMethod, swizzledMethod);
    }
}

#pragma mark - properties settings

- (void)setZc_enableCache:(BOOL)zc_enableCache {
    if (zc_enableCache) {
        [self startCache];
    }
    objc_setAssociatedObject(self, @selector(zc_enableCache), @(zc_enableCache), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)zc_enableCache {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setRowHeightCache:(NSMutableDictionary *)cache {
    objc_setAssociatedObject(self, @selector(rowHeightCache), cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)rowHeightCache {
    return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - private methods

- (void)startCache {
    static dispatch_once_t zcCacheToken;
    dispatch_once(&zcCacheToken, ^{
        [self initRowHeightCache];
        [self setHookToDelegate];
    });
}

- (void)initRowHeightCache {
    NSInteger firstSectionRowCount = [self.dataSource tableView:self numberOfRowsInSection:0];
    //now the ds does not be prepared.
    if (firstSectionRowCount == 0) {
        return;
    }
    
    NSInteger sectionCount = [self numberOfSections];
    NSMutableDictionary *cache = [NSMutableDictionary dictionaryWithCapacity:sectionCount];
    for (NSInteger i = 0;i < sectionCount; i++) {
        NSInteger rowCount = [self.dataSource tableView:self numberOfRowsInSection:i];
        NSMutableArray *rowHeightCacheArray = [NSMutableArray arrayWithCapacity:rowCount];
        for (NSInteger i = 0;i < rowCount;i++) {
            [rowHeightCacheArray addObject:@(-1)];
        }
        cache[@(i)] = rowHeightCacheArray;
    }
    [self setRowHeightCache:cache];
}

- (void)setHookToDelegate {
    Method currentRowHeightMethod = class_getInstanceMethod([self class], @selector(zc_tableView:heightForRowAtIndexPath:));
    IMP currentRowHeightImp = method_getImplementation(currentRowHeightMethod);
    const char *type = method_getTypeEncoding(currentRowHeightMethod);
    BOOL isSuccess = class_addMethod([self.delegate class], @selector(zc_tableView:heightForRowAtIndexPath:), currentRowHeightImp, type);
    if (isSuccess) {
        Method oriRowHeightMethod = class_getInstanceMethod([self.delegate class], @selector(tableView:heightForRowAtIndexPath:));
        Method latestRowHeightMethod = class_getInstanceMethod([self.delegate class], @selector(zc_tableView:heightForRowAtIndexPath:));
        method_exchangeImplementations(oriRowHeightMethod, latestRowHeightMethod);
    }
}

- (void)addPreCacheObserver {
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFStringRef runloopMode = kCFRunLoopDefaultMode;
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
        //to be continued
    });
    
    CFRunLoopAddObserver(runloop, observer, runloopMode);
}

#pragma mark - cache operators

- (void)insertSection:(NSInteger)section withCache:(id)cache {
    NSMutableDictionary *rowHeightCache = [self rowHeightCache];
    NSInteger count = [rowHeightCache count];
    
    if (section < 0 || section > count) {
        return;
    }
    
    for (NSInteger i = count; i > section; i--) {
        rowHeightCache[@(i)] = rowHeightCache[@(i - 1)];
    }
    rowHeightCache[@(section)] = cache;
}

- (void)deleteSection:(NSInteger)section {
    NSMutableDictionary *rowHeightCache = [self rowHeightCache];
    NSInteger count = [rowHeightCache count];
    
    if (section < 0 || section >= count) {
        return;
    }
    
    for (NSInteger i = section;i < count - 1;i++) {
        rowHeightCache[@(i)] = rowHeightCache[@(i + 1)];
    }
    
    [rowHeightCache removeObjectForKey:@(count - 1)];
}

#pragma mark - swizzled methods

- (CGFloat)zc_tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL flag = [objc_getAssociatedObject(tableView, @selector(zc_enableCache)) boolValue];
    if (!flag) {
        return [self zc_tableView:tableView heightForRowAtIndexPath:indexPath];
    }
    
    NSMutableDictionary *cache = objc_getAssociatedObject(tableView, @selector(rowHeightCache));
    if (!cache) {
        SEL selector = @selector(initRowHeightCache);
        void (*methodPointer) (id, SEL) = (void (*) (id, SEL))[tableView methodForSelector:selector];
        methodPointer(tableView,selector);
    }
    
    NSMutableArray *cacheArrayInSection = cache[@(indexPath.section)];

    CGFloat cachedHeight = [cacheArrayInSection[indexPath.row] floatValue];
    if (cachedHeight == -1) {
        CGFloat height = [self zc_tableView:tableView heightForRowAtIndexPath:indexPath];
        cacheArrayInSection[indexPath.row] = @(height);
        return height;
    }
    else {
        return cachedHeight;
    }
}

- (void)zc_reloadData {
    if (self.zc_enableCache) {
        [self initRowHeightCache];
    }
    [self zc_reloadData];
}

- (void)zc_insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
            NSInteger row = [self numberOfRowsInSection:section];
            NSMutableArray *sectionArray = [NSMutableArray arrayWithCapacity:row];
            for (NSInteger i = 0;i < section; i++) {
                [sectionArray addObject:@(-1)];
            }
            [self insertSection:section withCache:sectionArray];
        }];
    }
    [self zc_insertSections:sections withRowAnimation:animation];
}

- (void)zc_deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
            [self deleteSection:section];
        }];
    }
    [self zc_deleteSections:sections withRowAnimation:animation];
}

- (void)zc_reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        NSDictionary *cache = [self rowHeightCache];
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
            NSMutableArray *sectionCache = cache[@(section)];
            [sectionCache removeAllObjects];
        }];
    }
    [self zc_reloadSections:sections withRowAnimation:animation];
}

- (void)zc_moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (self.zc_enableCache) {
        NSMutableDictionary *caches = [self rowHeightCache];
        NSMutableArray *cache1 = [caches[@(section)] mutableCopy];
        NSMutableArray *cache2 = [caches[@(newSection)] mutableCopy];
        caches[@(section)] = cache2;
        caches[@(newSection)] = cache1;
    }
    [self zc_moveSection:section toSection:newSection];
}

- (void)zc_insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        NSMutableDictionary *caches = [self rowHeightCache];
        for (NSIndexPath *indexPath in indexPaths) {
            NSMutableArray *cache = caches[@(indexPath.section)];
            [cache insertObject:@(-1) atIndex:indexPath.row];
        }
    }
    [self zc_insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)zc_deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        NSMutableDictionary *caches = [self rowHeightCache];
        for (NSIndexPath *indexPath in indexPaths) {
            NSMutableArray *cache = caches[@(indexPath.section)];
            [cache removeObjectAtIndex:indexPath.row];
        }
    }
    [self zc_deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)zc_reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.zc_enableCache) {
        NSMutableDictionary *caches = [self rowHeightCache];
        for (NSIndexPath *indexPath in indexPaths) {
            NSMutableArray *cache = caches[@(indexPath.section)];
            [cache replaceObjectAtIndex:indexPath.row withObject:@(-1)];
        }
    }
    [self zc_reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
}

- (void)zc_moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath {
    if (self.zc_enableCache) {
        NSMutableDictionary *caches = [self rowHeightCache];
        NSMutableArray *cache1 = caches[@(indexPath.section)];
        NSMutableArray *cache2 = caches[@(newIndexPath.section)];
        
        CGFloat height1 = [cache1[indexPath.row] floatValue];
        CGFloat height2 = [cache2[newIndexPath.row] floatValue];
        
        [cache1 replaceObjectAtIndex:indexPath.row withObject:@(height2)];
        [cache2 replaceObjectAtIndex:newIndexPath.row withObject:@(height1)];
    }
    [self zc_moveRowAtIndexPath:indexPath toIndexPath:newIndexPath];
}

@end
