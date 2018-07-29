//
//  SPUncaughtExceptionHandler.h
//  CrashDemo
//
//  Created by gaoguangxiao on 2018/7/27.
//  Copyright © 2018年 gaoguangxiao. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPUncaughtExceptionHandler : NSObject

+(instancetype)shareInstance;

SPUncaughtExceptionHandler *installCrash(void);

@end
