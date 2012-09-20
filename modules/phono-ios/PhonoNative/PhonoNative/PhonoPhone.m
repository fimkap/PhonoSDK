/*
 * Copyright 2011 Voxeo Corp.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "PhonoPhone.h"
#import "PhonoCall.h"
#import "PhonoNative.h"
#import "PhonoXMPP.h"
#import "PhonoAPI.h"

@implementation PhonoPhone
@synthesize tones,onReady,onIncommingCall,headset,ringTone,ringbackTone,phono, xmppsessionID,currentCall,ringtoneSSID;

- (PhonoCall *)dial:(PhonoCall *)dest{
    if ([[phono pxmpp] isConnected]) {
        
    
    dest.phono = phono;
    [dest outbound];
    if (currentCall != nil){
        [self hangupCall:currentCall];
    }    
    currentCall = dest;
    [[phono pxmpp] dialCall:dest];
    } else {
        if (dest.onError != nil){
            dest.onError(nil);
        }
    }
    return dest;
}
- (void) didReceiveIncommingCall:(PhonoCall *)call{
    if (ringTone != nil){
        //[[phono papi] play:ringTone autoplay:YES];
        CFURLRef        myURLRef;
        myURLRef = CFURLCreateWithFileSystemPath (
                                                  kCFAllocatorDefault,
                                                  (CFStringRef)ringTone,
                                                  kCFURLPOSIXPathStyle,
                                                  FALSE
                                                  );
        OSStatus err = AudioServicesCreateSystemSoundID(myURLRef, &ringtoneSSID);
        if (err)
            NSLog(@"AudioServicesCreateSystemSoundID error");
        CFRelease (myURLRef);
        AudioServicesAddSystemSoundCompletion (
                                               ringtoneSSID,
                                               NULL,
                                               NULL,
                                               ringtoneCallback,
                                               NULL
                                               );
        AudioServicesPlaySystemSound(ringtoneSSID);
    }
    if (onIncommingCall != nil) {
        onIncommingCall(call);
    } else {
        [self hangupCall:call];
    }
}

//	 When a call arrives via an incomingCall event, it can be answered by calling this function.

- (void) acceptCall:(PhonoCall *)incall{
    if (currentCall != nil){
        [self hangupCall:currentCall];
    }
    currentCall = incall;
    [[phono pxmpp] acceptInboundCall:incall];
    if (ringTone != nil){
        //[[phono papi] stop:ringTone];
        AudioServicesDisposeSystemSoundID(ringtoneSSID);
    }
}

// hangup a call
-(void) hangupCall:(PhonoCall *)acall{
    [[phono pxmpp] hangupCall:acall];
    if (ringTone != nil){
        //[[phono papi] stop:ringTone];
        AudioServicesDisposeSystemSoundID(ringtoneSSID);
    }
    currentCall = nil;
}

static void ringtoneCallback (SystemSoundID  mySSID,void* inClientData)
{
    AudioServicesPlaySystemSound(mySSID);
}

@end
