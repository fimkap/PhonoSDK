 //
//  PhonoXMPP.m
//  PhonoNative
//
//  Created by Tim Panton on 15/12/2011.
//  Copyright (c) 2011 Westhhawk Ltd. All rights reserved.
//

#import "PhonoXMPP.h"
#import "PhonoAPI.h"
#import "PhonoNative.h"
#import "PhonoPhone.h"
#import "PhonoCall.h"

@implementation PhonoXMPP

@synthesize  xmppStream, xmppJingle,xmppReconnect,rtt;

- (id) initWithPhono:(PhonoNative *)p{
    
    
    self = [super init];
    if (self) {
        phono = p;     
    }
    return self;
}
- (BOOL) isConnected{
    return isXmppConnected;
}
- (void)setupStream
{
	// NSAssert(xmppStream == nil, @"Method setupStream invoked multiple times");
	if (xmppStream != nil){
        return;
    }
    
	// Setup xmpp stream
	// 
	// The XMPPStream is the base class for all activity.
	// Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
	xmppStream = [[XMPPStream alloc] init];
	
#if !TARGET_IPHONE_SIMULATOR
	{
		// Want xmpp to run in the background?
		// 
		// P.S. - The simulator doesn't support backgrounding yet.
		//        When you try to set the associated property on the simulator, it simply fails.
		//        And when you background an app on the simulator,
		//        it just queues network traffic til the app is foregrounded again.
		//        We are patiently waiting for a fix from Apple.
		//        If you do enableBackgroundingOnSocket on the simulator,
		//        you will simply see an error message from the xmpp stack when it fails to set the property.
		
		xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
	
	// Setup reconnect
	// 
	// The XMPPReconnect module monitors for "accidental disconnections" and
	// automatically reconnects the stream for you.
	// There's a bunch more information in the XMPPReconnect header file.
	
	xmppReconnect = [[XMPPReconnect alloc] init];
    [xmppReconnect         activate:xmppStream];
    
    xmppAPing = [[XMPPAutoPing alloc ] init];
    [xmppAPing setPingInterval:30.0];
    [xmppAPing activate:xmppStream];
    
    
    xmppJingle = [[XMPPJingle alloc] initWithPhono:NO];
    [xmppJingle setPayloadAttrFilter:@"[@name=\"ULAW\" and @clockrate=\"8000\"]"]; // default value.
    
    [xmppJingle activate:xmppStream];
    [xmppJingle addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    [xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    //[xmppStream setHostName:@"ec2-50-19-77-101.compute-1.amazonaws.com"];
    //[xmppStream setHostName:@"app-phono-com-1412939140.us-east-1.elb.amazonaws.com"]; http://haproxy1-ext.voxeolabs.net/http-bind
    [xmppStream setHostName:@"phono-srtp-ext.qa.voxeolabs.net"];
    // efim - test
    //[xmppStream setHostName:@"app.phono.com"];

    [xmppStream setHostPort:5222];	
    
	
    
	// You may need to alter these settings depending on the server you're connecting to
	allowSelfSignedCertificates = NO;
	allowSSLHostNameMismatch = NO;
    allAudioCodecs = [xmppJingle emptyAudioPayload];
    NSArray * codecs = [[phono papi] codecArray];
    for (int i=0; i< [codecs count]; i++){
        NSDictionary *codec = [codecs objectAtIndex:i];
        [xmppJingle addCodecToPayload:allAudioCodecs name:[codec objectForKey:@"name"] rate:[codec objectForKey:@"rate"] ptype:[codec objectForKey:@"ptype"]];
    }
    
}

- (void)teardownStream
{
	[xmppStream removeDelegate:self];
	
	[xmppReconnect         deactivate];
    
	
	[xmppStream disconnect];
	
	[xmppStream release];
	[xmppReconnect release];
    [xmppJingle release];
	xmppJingle = nil;
	xmppStream = nil;
	xmppReconnect = nil;
}


- (BOOL)connect:(NSString *)anapiKey
{
    apiKey = [[NSString stringWithString:anapiKey] retain];
	if (![xmppStream isDisconnected]) {
		return YES;
	}
    
	//
	// If you don't want to use the Settings view to set the JID, 
	// uncomment the section below to hard code a JID and password.
	//
	// Replace me with the proper JID and password:
	NSString *myJID = @"anon@gw-v3.d.phono.com/voxeo";
	NSString *myPassword = @"";
    
	if (myJID == nil || myPassword == nil) {
		NSLog(@"JID and password must be set before connecting!");
        
		return NO;
	}
    
	[xmppStream setMyJID:[XMPPJID jidWithString:myJID]];
	NSError *error = nil;
	if (![xmppStream connect:&error]){        
		NSLog(@"Error connecting: %@", error);
        
		return NO;
	}
    
	return YES;
}

- (void)disconnect {    
    [xmppStream disconnect];
}

// used for both directions - call should have all the info.
-(void) startMediaOnCall:(PhonoCall*) ccall now:(BOOL)now{
    NSString *fhost = [xmppJingle ipWithCandidate:(NSXMLElement *)[ccall candidate] ];
    NSString *fport = [xmppJingle portWithCandidate:(NSXMLElement *)[ccall candidate] ];
    NSString *lshare = [ccall share];
    NSString *fullshare = [NSString stringWithFormat:@"%@:%@:%@", lshare, fhost , fport];
    
    NSString *mycodec = [xmppJingle ptypeWithPayload:(NSXMLElement *)[ccall payload] ];
    NSLog(@" selected codec is %@",mycodec );
    NSLog(@" fullshare is %@",fullshare );
    [ccall setCodecInd:mycodec];
    // srtpType:(NSString *)srtpType srtpKeyL:(NSString *)srtpKeyL srtpKeyR:(NSString *)srtpKeyR;
    [[phono papi] share:fullshare autoplay:now codec:mycodec srtpType:[ccall srtpType] srtpKeyL:[ccall srtpKeyL]  srtpKeyR:[ccall srtpKeyR] ]; 
    
}

- (void)acceptInboundCall:(PhonoCall *)incall{
    
    NSString *lshare = incall.share =  [phono.papi allocateEndpoint];
    NSArray *bits = [lshare componentsSeparatedByString:@":"];
    // 0= 'rtp' 1 = //192.67.4.1 2 =3020
    if (( [bits count ] == 3) 
        && ( [(NSString *)[bits objectAtIndex:0] compare:@"rtp"] == NSOrderedSame ) ){
        NSString *host = [(NSString *)[bits objectAtIndex:1] substringFromIndex:2];
        NSString *port = [bits objectAtIndex:2];
        NSMutableArray * cryptoLines = [NSMutableArray arrayWithCapacity:1];

        if (([incall srtpKeyR] != nil) && ([incall srtpType] != nil)){
            [incall setSrtpKeyL:[[NSString alloc ] initWithString:[PhonoAPI mkKey]]];
            NSMutableDictionary *ctags = [[NSMutableDictionary alloc] initWithCapacity:2];
            [ctags setValue:[incall srtpType] forKey:@"crypto-suite" ];
            [ctags setValue:[NSString stringWithFormat:@"inline:%@",[incall srtpKeyL]] forKey:@"key-params"];
            [cryptoLines addObject:ctags];
        }
        [xmppJingle sendSessionAccept:[incall callId] to:[incall from] host:host port:port payload:[incall payload] cryptos:cryptoLines];
        [self startMediaOnCall:incall now:NO];
    }
    
}

- (void)hangupCall:(PhonoCall *)acall{
    NSString *lshare = acall.share ;
    [[phono papi] stop:lshare];
    if(acall.ringing){
        [[phono papi] stop:phono.phone.ringbackTone ];
    }
    NSLog(@"stopping %@",[acall share] );
    [acall setState:ENDED];
    [[phono papi] freeEndpoint:lshare];
    [phono.phone setCurrentCall:nil];

    
    [xmppJingle sendHangup:acall.callId to:[acall from] reason:@"success"];
}

- (void)dialCall:(PhonoCall *)acall{
    NSString *lshare = acall.share =  [phono.papi allocateEndpoint];
    NSArray *bits = [lshare componentsSeparatedByString:@":"];
    // 0= 'rtp' 1 = //192.67.4.1 2 =3020
    if (( [bits count ] == 3) 
        && ( [(NSString *)[bits objectAtIndex:0] compare:@"rtp"] == NSOrderedSame ) ){
        NSString *host = [(NSString *)[bits objectAtIndex:1] substringFromIndex:2];
        NSString *port = [bits objectAtIndex:2];
        NSMutableArray *heads = nil;
        if (acall.headers != nil){
            // add the custom phono stuff here.
            heads = [[NSMutableArray alloc] initWithCapacity:[acall.headers count]];
            NSEnumerator *e = [acall.headers keyEnumerator];
            NSString *k = nil;
            while (nil != (k = [e nextObject])){
                NSString *v = [acall.headers objectForKey:k];
                NSXMLElement * xe = [DDXMLElement elementWithName:@"custom-header"];
                [xe addAttributeWithName:@"name" stringValue:k];
                [xe addAttributeWithName:@"data" stringValue:v];
                [heads addObject:xe];
            }
        }
        NSInteger reqCrypt = 0;
        if ([acall secure]){
            reqCrypt = 1;
        }
        NSMutableArray * cryptoLines = [NSMutableArray arrayWithCapacity:1];

        if (([acall srtpKeyL] != nil) && ([acall srtpType] != nil)){
            NSMutableDictionary *ctags = [[NSMutableDictionary alloc] initWithCapacity:2];
            [ctags setValue:[acall srtpType] forKey:@"crypto-suite" ];
            [ctags setValue:[NSString stringWithFormat:@"inline:%@",[acall srtpKeyL]] forKey:@"key-params"];
            [cryptoLines addObject:ctags];
        }
        
        NSString * sessionId = [xmppJingle initSessionTo:[acall to] lhost:host lport:port payloads:allAudioCodecs custom:heads cryptoRequired:reqCrypt cryptoLines:cryptoLines];
        [acall setCallId:sessionId];
        [acall setState:NEW];
    }
}

- (NSString *)findKeyForType:(NSString *)srtpType cels:(NSArray *)clines{
    NSString *ret = nil;
    for (NSDictionary * cl in clines){
        NSString * ctype = [cl objectForKey:@"crypto-suite"];
        if ([ctype compare:srtpType] == NSOrderedSame){
            ret = [cl objectForKey:@"key-params"];
        }
    }
    if (ret != nil) {
        NSRange r = [ret rangeOfString:@"inline:"];
        if ((r.location == 0) && (r.length == 7)){
            ret = [ret substringFromIndex:7];
        } else {
            NSLog(@"looking for inline in %@",ret);
            ret = nil;
        }
    } else {
        NSLog(@"no matching cypher suite");
    }
    return ret;
}

- (void) sendApiKey {
    // <iq type="set" xmlns="jabber:client"><apikey xmlns="http://phono.com/apikey">C17D167F-09C6-4E4C-A3DD-2025D48BA243</apikey></iq>
    XMPPIQ *iq = [XMPPIQ iqWithType:@"set" ];
    readyID = [[NSString alloc ] initWithString:[xmppJingle mkIdElement]];
    [iq addAttributeWithName:@"id" stringValue:readyID];
    NSXMLElement *xapikey = [NSXMLElement elementWithName:@"apikey" xmlns:@"http://phono.com/apikey"];
    [xapikey addChild:[NSXMLNode textWithStringValue:apiKey]];
    [iq addChild:xapikey];
    [xmppStream sendElement:iq];
}

- (void) sendMessage:(PhonoMessage *)mess {
/* <message xmlns="jabber:client" from="phono-weather@tropo.im/Tropo" type="chat" to="43daae43-0edc-41aa-8f45-567b22a62276@gw-v3.d.phono.com/voxeo"><body>Conditions for Silver Spring, MD at 3:58 pm EST: 45 degrees Fahrenheit. Fair</body></message>*/
    XMPPMessage *jmessage = [[ XMPPMessage alloc] init];
    [jmessage setXmlns:@"jabber:client"];
    [jmessage addAttributeWithName:@"type" stringValue:@"chat"];
    [jmessage addAttributeWithName:@"to" stringValue:[mess to]];
    //[jmessage addAttributeWithName:@"from" stringValue:[mess from]];
    NSXMLElement *xbody = [NSXMLElement elementWithName:@"body" stringValue:[mess body]];
    [xbody setXmlns:@"jabber:client"];
    [jmessage addChild:xbody];
    NSLog(@"sending %@",[jmessage XMLString]);
    [xmppStream sendElement:jmessage];
}




////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPJingle Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppJingle:(XMPPJingle *)sender didReceiveIncommingAudioCall:(NSString *)sid from:(XMPPJID *)from to:(XMPPJID *)to transport:(NSXMLElement *)candidate sdp:(NSXMLElement *)payload cryptoRequired:(NSString *) creqI cryptoElements:(NSArray *)cels {
    PhonoCall * incall = [[PhonoCall alloc] initInbound];
    [incall setPhono:phono];
    [incall setSrtpType:@"AES_CM_128_HMAC_SHA1_80"];
    [incall setCallId:sid];
    [incall setPayload:payload];
    [incall setCandidate:candidate];
    [incall setFrom:[from full]];
    [incall setTo:[to full]];
    [incall setSecure:[creqI integerValue]];
    [incall setSrtpKeyR:[self findKeyForType:[incall srtpType] cels:cels]];
    [incall setState:PENDING];
    [phono.phone didReceiveIncommingCall:incall];
}



- (void)xmppJingle:(XMPPJingle *)sender didReceiveAcceptForCall:(NSString *)sid from:(XMPPJID *)from to:(XMPPJID *)to transport:(NSXMLElement *)candidate sdp:(NSXMLElement *)payload
    cryptoRequired:(NSString *) creqI cryptoElements:(NSArray *)cels
{
    PhonoCall *ccall = [phono.phone currentCall];
    if ([[ccall callId] compare:sid] == NSOrderedSame ){
        if (ccall.state == PENDING){
            [ccall setCandidate:candidate];
            [ccall setPayload:payload];
            [ccall setSecure:[creqI integerValue]];
            [ccall setSrtpKeyR:[self findKeyForType:[ccall srtpType] cels:cels]];
            if(ccall.ringing){
                [phono.papi stop:phono.phone.ringbackTone ];
            }
            [self startMediaOnCall:ccall now:YES];
            [ccall setState:ACTIVE];
            if (ccall.onAnswer != nil){
                ccall.onAnswer();
            }
        } else {
                NSLog(@"Call state mixup - call should be PENDING when accept arrives");
            }
    } else {
        NSLog(@"got accept for call %@ that isn't current one %@",[ccall callId], sid);
    }
}

- (void)xmppJingle:(XMPPJingle *)sender didReceiveInfoForCall:(NSString *)sid from:(XMPPJID *)from to:(XMPPJID *)to info:(NSXMLNode *)info {
    PhonoCall *ccall = [phono.phone currentCall];
    if ([[ccall callId] compare:sid] == NSOrderedSame ){
        if(ccall.state == PENDING) {
            if (!ccall.ringing){
                if (ccall.onRing != nil)  {
                    ccall.onRing();
                }
                ccall.ringing = YES;
                if (phono.phone.ringbackTone != nil){
                    [phono.papi play:phono.phone.ringbackTone autoplay:YES];
                }
            }
        }
    }
}

- (void)xmppJingle:(XMPPJingle *)sender
  didReceiveResult:(NSString *)sid {
    // should have a list of calls - but for now a choice of 1
    PhonoCall *ccall = [phono.phone currentCall];
    if ([[ccall callId] compare:sid] == NSOrderedSame ){
        NSInteger state = [ccall state];
        switch (state){
            case PENDING : {
                [ccall setState:ACTIVE];
                [[phono papi] start:[ccall share]];
                NSLog(@"starting %@",[ccall share]);
                break;
            }
            case NEW: {
                [ccall setState:PENDING];
                NSLog(@"waiting for an accept");
                break;
            }
        }
    }
    
    
}
- (void)xmppJingle:(XMPPJingle *)sender
   didReceiveError:(NSString *)sid error:(NSXMLElement*)error{
    NSLog(@"got error");
    if (phono.onError != nil){
        phono.onError();
    }

}
- (void)xmppJingle:(XMPPJingle *)sender
didReceiveTerminate:(NSString *)sid reason:(NSString*)reason{
    // should have a list of calls - but for now a choice of 1
    PhonoCall *ccall = [phono.phone currentCall];
    if ([[ccall callId] compare:sid] == NSOrderedSame ){
        [[phono papi] stop:[ccall share]];
        [[phono papi] freeEndpoint:[ccall share]];
        [phono.phone setCurrentCall:nil];

        NSLog(@"stopping %@",[ccall share] );
        if (ccall.onHangup != nil){
            ccall.onHangup();
        }
        [ccall setState:ENDED];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket 
{
    
	NSLog(@"Socket Connected");
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	NSLog(@"Secure with settings");
}

- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	NSLog(@"Secured with settings");
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	NSLog(@"Connected");
	
	isXmppConnected = YES;
	
	NSError *error = nil;
    
    [sender authenticateAnonymously:&error];
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	NSLog(@"Authenticated as %@", [sender myJID]) ;
    phono.sessionID = [[sender myJID] bare];
    phono.myJID = [[sender myJID] full];
    [xmppJingle setMe:[sender myJID]];
    [self sendApiKey];
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    [[self xmppStream] sendElement:presence];
    
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	NSLog(@"Not Authenticated because %@", [error XMLString]);
}

- (void) calculateRTT:(NSString *)thenS{
    NSTimeInterval then = [thenS doubleValue]; 
    NSDate *now = [NSDate date];
    NSTimeInterval fpnow = [now timeIntervalSince1970];
    rtt = fpnow - then;
    NSLog(@"RTT is %g",rtt);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	NSLog(@"Got iq %@", [iq XMLString]);
    if ([iq isResultIQ]) {
        NSLog(@"isResultIQ true");
    }
    else {
        NSLog(@"isResultIQ false");
    }
    NSLog(@"readyID %@", readyID);
    if ([iq isResultIQ] && (readyID != nil) && ([readyID compare:[iq elementID] ] == NSOrderedSame)){
        [self calculateRTT:[iq elementID]];
        if (phono.onReady != nil){
            dispatch_queue_t q_main = dispatch_get_main_queue();
            dispatch_async(q_main, phono.onReady);
            [readyID release];
            readyID = nil;
        }
    }
    else {
        NSLog(@"in background mode");
        [self incomingConnectionReceivedOnBackground];
    }
	return NO;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	NSLog(@"Got message from %@ : %@", [message from] , [[message elementForName:@"body"] stringValue]);
    PhonoMessaging *pm = [phono messaging];
    if (pm.onMessage != nil){
        PhonoMessage *mess = [[[PhonoMessage alloc] init] autorelease];
        [mess setBody:[[message elementForName:@"body"] stringValue]];
        [mess setFrom:[PhonoNative unescapeString:[message fromStr]]];
        [mess setTo: [PhonoNative unescapeString:[message toStr]]];
        [mess setPhono:phono];
        pm.onMessage(mess);
    }
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	NSLog(@"Presnce");
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	NSLog(@"Error");
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{	
    NSLog(@"disconnected ");
	if (!isXmppConnected)
	{
		NSLog(@"Unable to disconnect from server. Check xmppStream.hostName");
	}
    if (phono.onUnready != nil){
        dispatch_queue_t q_main = dispatch_get_main_queue();
        dispatch_async(q_main, phono.onUnready);
    }
    PhonoCall *ccall = [phono.phone currentCall];
    if (ccall != nil) {
        [[phono papi] stop:[ccall share]];
        [[phono papi] freeEndpoint:[ccall share]];
        [phono.phone setCurrentCall:nil];
    }
    isXmppConnected = NO;
}

-(BOOL)isMultitaskingOS
{
	//Check to see if device's OS supports multitasking
	BOOL backgroundSupported = NO;
	UIDevice *currentDevice = [UIDevice currentDevice];
	if ([currentDevice respondsToSelector:@selector(isMultitaskingSupported)])
	{
		backgroundSupported = currentDevice.multitaskingSupported;
	}
	
	return backgroundSupported;
}

-(BOOL)isForeground
{
	//Check to see if app is currently in foreground
	if (![self isMultitaskingOS])
	{
		return YES;
	}
	
	UIApplicationState state = [UIApplication sharedApplication].applicationState;
	if(state==UIApplicationStateActive) {
        return YES;
    }
    return NO;
}

-(void) incomingConnectionReceivedOnBackground
{
    if ([self isForeground]) {
        NSLog(@"In foreground");
        return;
    }
    //App is not in the foreground, so send LocalNotification
    UIApplication* app = [UIApplication sharedApplication];
    UILocalNotification* notification = [[UILocalNotification alloc] init];
    NSArray* oldNots = [app scheduledLocalNotifications];
    
    if ([oldNots count]>0)
    {
        [app cancelAllLocalNotifications];
    }
    
    notification.alertBody = @"Incoming Call";
    
    [app presentLocalNotificationNow:notification];
    [notification release];
}
@end
