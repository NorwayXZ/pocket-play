#import <AppKit/AppKit.h>
#import <objc/runtime.h>

static NSString *const PocketShowNotification = @"local.pocketplay.show-emulator";

@interface PocketDockAgent : NSObject
+ (instancetype)shared;
- (void)show:(NSNotification *)notification;
- (void)hidePhone:(id)sender;
- (void)installCloseAction;
@end

@implementation PocketDockAgent
+ (instancetype)shared {
    static PocketDockAgent *agent;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ agent = [PocketDockAgent new]; });
    return agent;
}
- (void)hidePhone:(id)sender {
    for (NSWindow *window in NSApp.windows) {
        if ([window.title hasPrefix:@"Android Emulator - PocketPlay_API35"]) {
            [window orderOut:sender];
            break;
        }
    }
}
- (void)installCloseAction {
    for (NSWindow *window in NSApp.windows) {
        if (![window.title hasPrefix:@"Android Emulator - PocketPlay_API35"]) continue;
        NSButton *button = [window standardWindowButton:NSWindowCloseButton];
        if (button && button.target != self) {
            button.target = self;
            button.action = @selector(hidePhone:);
        }
    }
}
- (void)show:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSWindow *window in NSApp.windows) {
            if ([window.title hasPrefix:@"Android Emulator - PocketPlay_API35"]) {
                [window makeKeyAndOrderFront:nil];
                [NSApp activateIgnoringOtherApps:YES];
                break;
            }
        }
    });
}
@end

__attribute__((constructor)) static void pocket_play_initialize(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
            [[PocketDockAgent shared] installCloseAction];
        }];
        [[NSDistributedNotificationCenter defaultCenter]
            addObserver:[PocketDockAgent shared]
               selector:@selector(show:)
                   name:PocketShowNotification
                 object:nil];
    });
}
