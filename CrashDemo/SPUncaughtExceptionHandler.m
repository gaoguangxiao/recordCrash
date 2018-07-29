//
//  SPUncaughtExceptionHandler.m
//  CrashDemo
//
//  Created by gaoguangxiao on 2018/7/27.
//  Copyright © 2018年 gaoguangxiao. All rights reserved.
//

#import "SPUncaughtExceptionHandler.h"
#import <UIKit/UIKit.h>

#import <libkern/OSAtomic.h>
#import <execinfo.h>
static SPUncaughtExceptionHandler *_instance;
NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;
const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;
@interface SPUncaughtExceptionHandler ()
{
    BOOL dismissed;
    NSString *_message_my;
    NSString *_message_alert;
    NSString *_message_exception;
    NSString *_title_alert;
    void (^action)(NSString *msg);
    void (^handleBlock)(NSString *path);
}
@property (nonatomic, assign) BOOL showInfor;
@property (nonatomic, assign) BOOL show_alert;
@property (nonatomic, retain) NSString *logFilePath;
@end

@implementation SPUncaughtExceptionHandler
+(instancetype)shareInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc]init];
        _instance.showInfor = YES;
        _instance.show_alert = YES;
    });
    return _instance;
}
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
-(id)copyZone{
    return _instance;
}
void SignalHandler(int signal) {
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
//    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
//    NSArray *callStack = [SPUncaughtExceptionHandler backtrace];
//    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
//    [[SPUncaughtExceptionHandler shareInstance] performSelectorOnMainThread:@selector(handleException:) withObject: [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason: [NSString stringWithFormat: NSLocalizedString(@"Signal %d was raised.", nil), signal] userInfo: [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey]] waitUntilDone:YES];
}
SPUncaughtExceptionHandler *installCrash(void){
    
    NSSetUncaughtExceptionHandler(&HandleException);//捕获异常
    
    signal(SIGABRT, SignalHandler);
 
    return [SPUncaughtExceptionHandler shareInstance];
}

//执行异常铺货
void HandleException(NSException *exception){
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    NSArray *callStack = [SPUncaughtExceptionHandler backtrace];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [[SPUncaughtExceptionHandler shareInstance] performSelectorOnMainThread:@selector(handleException:) withObject: [NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo] waitUntilDone:YES];
}

- (void)handleException:(NSException *)exception {
    
    //1、记录崩溃日志
    [self validateAndSaveCriticalApplicationData:exception];
    
    if (_showInfor) {
        _message_alert = [NSString stringWithFormat:NSLocalizedString(@"如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开\n\n" @"异常原因如下:\n%@\n%@", nil), [exception reason], [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];
    }else {
        _message_alert = [NSString stringWithFormat:NSLocalizedString(@"\n如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开\n", nil)];
        if (_message_my) {
            _message_alert = _message_my;
        }
    }
    NSString *titleStr = nil;
    if (_title_alert) {
        titleStr = _title_alert;
    }else {
        titleStr = NSLocalizedString(@"抱歉，程序出现了异常", nil);
    }
    _message_exception = [NSString stringWithFormat:NSLocalizedString(@"异常原因如下:\n%@\n%@", nil), [exception reason], [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];

    UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {

        //关闭程序
//        exit(0);
        
    }];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"我知道了" message:_message_alert preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:alertAction];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!dismissed){
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    CFRelease(allModes);
#pragma clang diagnostic pop
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    }else{
        [exception raise];
    }
}
#pragma mark - 对崩溃日志进行统计
- (void)validateAndSaveCriticalApplicationData:(NSException *)exception {
    NSString *exceptionMessage = [NSString stringWithFormat:NSLocalizedString(@"\n********** %@ 异常原因如下: **********\n%@\n%@\n========== End ==========\n", nil), [self currentTimeString], [exception reason], [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];
    // 4.创建文件对接对象,文件对象此时针对文件，可读可写
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:_logFilePath];
    [handle seekToEndOfFile];
    [handle writeData:[exceptionMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
    //NSLog(@"%@", filePath);
    if (handleBlock) {
        handleBlock(_logFilePath);
    }
}
- (NSString *)currentTimeString {
    //时间格式化
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //设定时间格式,这里可以设置成自己需要的格式
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    //用[NSDate date]可以获取系统当前时间
    NSString *currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    return currentDateStr;
}

+ (NSArray *)backtrace {
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount; i < UncaughtExceptionHandlerSkipAddressCount + UncaughtExceptionHandlerReportAddressCount; i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}
@end
