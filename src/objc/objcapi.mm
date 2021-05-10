#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "src/objc/objcapi.h"

void ObjCApi::set_idle_timer_disabled() {
//    [[UIApplication sharedApplication] setIdleTimerDisabled: YES];
    [[[UIApplication class] performSelector:@selector(sharedApplication)] setIdleTimerDisabled: YES];
}
