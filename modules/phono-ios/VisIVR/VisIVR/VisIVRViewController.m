//
//  VisIVRViewController.m
//  VisIVR
//
//  Created by Tim Panton on 15/12/2011.
//  Copyright (c) 2011 Westhhawk Ltd. All rights reserved.
//

#import "VisIVRViewController.h"
#import "PhonoNative.h"
#import "PhonoPhone.h"
#import <AudioToolbox/AudioToolbox.h>


@implementation VisIVRViewController

@synthesize  appNum , tjid, status, prompt, domain, outMess, codec, speakerSw, scrollView;

NSString *_empty = @"<html>\
<head>\
<script src='http://code.jquery.com/jquery-1.4.2.min.js'></script>\
</head>\
<body id='body'>Empty\
%@</body>\
</html>";
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

#pragma mark - View lifecycle

- (void) gotjId{
    [tjid setText:[phono sessionID]];
    if (speakerSw != nil) {
        [phono setUseSpeaker:[speakerSw isOn]];
    }
    NSDictionary *cprefs = [phono lowBWPrefs];
    if (cprefs != nil) {
        [phono setAudio:cprefs]; // or make up your own.
    }
    NSLog(@"sid: %@", [phono sessionID]);
    [self registerSessionID:[phono sessionID]];
}

- (void) update:(NSString *) state {
    [status setText:state];
    [codec setText:[call codecInd]];
}

-(void) popIncommingCallAlert:(PhonoCall *) incall{
    call = incall;
    NSString *erom = [PhonoNative unescapeString:[incall from]];
    // Extract caller name
    NSMutableDictionary *cheaders = [incall headers];
//    for (id key in [cheaders allKeys])
//    {
//        NSLog(@"key: %@", [key stringValue]);
//    }
    //NSString *callername = [cheaders objectForKey:@"x-pp-src-user-name"];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Incomming Call"
                          
                                                    message:erom
                          
                                                   delegate:self
                          
                                          cancelButtonTitle:@"Ignore"
                          
                                          otherButtonTitles:nil];
    [alert addButtonWithTitle:@"Accept"];

    [alert show];
    [alert release];
}

-(void) gotMessage:(PhonoMessage *)mess{
    // strictly test to and from here but for now.....
    // stringByEvaluatingJavaScriptFromString in future $("#"+newCallID);
    //NSString *html =[NSString stringWithFormat:@"<html><body>%@</body></html>",[mess body]];
    //[prompt loadHTMLString:html baseURL:nil];
    
    NSString *bo = [mess body];
    if ([bo characterAtIndex:0] == '$'){
        NSString *res = [prompt stringByEvaluatingJavaScriptFromString:bo];
        NSLog(@" js result %@",res);
    } else {
        NSString *html =[NSString stringWithFormat:_empty,[mess body]];
        [prompt loadHTMLString:html baseURL:nil];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    phone = [[PhonoPhone alloc] init];
    phone.onIncommingCall = ^(PhonoCall * incall){
        [self popIncommingCallAlert:incall];
    };
    phone.ringTone = [[NSBundle mainBundle] pathForResource:@"Diggztone_Marimba" ofType:@"mp3"] ;
    phone.ringbackTone= [[NSBundle mainBundle] pathForResource:@"ringback-uk" ofType:@"mp3"];

    phono = [[PhonoNative alloc] initWithPhone:phone ];
    phono.messaging.onMessage = ^(PhonoMessage *message){
        [self gotMessage:message];
    };
    phono.onReady = ^{ [self gotjId];};
    phono.onUnready = ^{ [self gotjId];};
    phono.onError = ^{ [self update:@"error"];};
    
    //phono.isForeground = ^{ return YES; }; //^{ [self isForeground];};
    phono.isForeground = ^{
        if (![self isMultitaskingOS])
        {
            return YES;
        }
        
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        if(state==UIApplicationStateActive) {
            return YES;
        }
        return NO;
    };
    phono.incomingConnectionOnBackground = ^{ [self incomingConnectionReceivedOnBackground];};


    NSURL *base = [NSURL URLWithString:@"http://s.phono.com/"];
    NSString *empty = [NSString stringWithFormat:_empty,@""];    
    [prompt loadHTMLString:empty baseURL:base];
    [self registerForKeyboardNotifications ];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (IBAction)connect{
    [phono setApiKey:@"C17D167F-09C6-4E4C-A3DD-2025D48BA243"];
    [phono connect];
    
    
    
//    NSURL* url = [[NSURL alloc] initWithString: @"http://purple-dev.appspot.com/api/120112/GroupSearch"];
//    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
//    
//    NSString *post = @"session_token=u9uBCefFmR7cFDb:iOS:0.1.0:1351774945.87:gYxK5boL42:e410ca8d351d425a782133c7ae74c658760d47ee&words=&from=&max_results=10";
//    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding];
//	
//    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
//    
//    [request setHTTPMethod:@"POST"];
//    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
//    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//    [request setHTTPBody:postData];
//    
//    NSURLResponse *response = [[NSURLResponse alloc]init];
//    NSError *err;
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
//    
//    NSError *jsonParsingError = nil;
//    NSDictionary *respJSON = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonParsingError];
//    
//    NSArray *groups = [respJSON objectForKey:@"groups"];
//    NSDictionary *group;
//    for(int i=0; i<[groups count];i++)
//    {
//        group = [groups objectAtIndex:i];
//        NSLog(@"Group name: %@", [group objectForKey:@"name"]);
//    }
    
    //[response release];
    
}
- (IBAction)disconnect{
    [phono disconnect];
}
- (IBAction)call{
    NSString *user = [appNum text];
    NSInteger m = [domain selectedSegmentIndex];
    NSString *dom =  (m == 1)? @"sip":@"app";
    if ([phono sessionID] != nil){
        call = [[[PhonoCall alloc] initOutbound:user domain:dom] retain]; 
        [self update:@"dialing"];
        [call.headers setObject:[phono sessionID] forKey:@"x-jid"];
        call.onAnswer = ^{ [self update:@"answered"];};
        call.onError = ^{ [self update:@"error"];};
        call.onHangup = ^{ [self update:@"hangup"];};
        call.onRing = ^{ [self update:@"ring"];};
        call.from = [NSString stringWithString:[phono sessionID]];
        [phono.phone dial:call];
    } else {
        [self update:@"Not connected"];
    }
    
}

- (IBAction)speaker:(id)sender{
    UISwitch *sp = (UISwitch *) sender;
    [phono setUseSpeaker:[sp isOn]];
}

- (IBAction)hangup{
    [call hangup];
}
- (IBAction)digit:(id) sender {
    UIButton *b = (UIButton *) sender;
    NSString *d = [[b titleLabel] text];
    NSLog(@"Digit %@",d);
    [call digit:d];
}

- (IBAction)mute:(id) sender {
    UISwitch *s = (UISwitch *) sender;
    BOOL d = [s isOn];
    [call setMute:d];
}

- (IBAction)sendMess{
    if (call == nil){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Can't send message"
                                                        message:@"You can only send messages during a call, sorry."
                                                       delegate:nil
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:nil];
        
        [alert show];
        [alert release];
    } else {
        NSString *b = [outMess text];
        PhonoMessage *m = [[PhonoMessage alloc] init];
        [m setPhono:phono];
        [m setBody:b];
        [m setFrom:[call from]];
        NSString *t = [NSString stringWithFormat:@"%@@tropo.im",[appNum text]];
        [m setTo:t];
        [m sendMe];
    }
}

// delegate actions
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    // don't actually care.
    
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0){
        // ignore
        [call hangup];
    } else if (buttonIndex == 1){
        // accept incomming call
        [call answer];
    }
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    if (scrollView == nil) return;
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your application might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, activeField.frame.origin.y-kbSize.height);
        [scrollView setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    if (scrollView == nil) return;

    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
}
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [activeField resignFirstResponder];
    if (textField == appNum) {
        [self call];
    } else if (textField == outMess) {
        [self sendMess];
    }
    return YES;
}
- (void)registerSessionID:(NSString*)sid
{
    NSURL* url = [[NSURL alloc] initWithString: @"http://purple-dev.appspot.com/api/120112/tropo_register_sid"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    
    NSString *post = [NSString stringWithFormat:@"session_token=u9uBCefFmR7cFDb:iOS:0.1.0:1351774945.87:gYxK5boL42:e410ca8d351d425a782133c7ae74c658760d47ee&device_id=iphone2&sid=%@",sid];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding];
	
    NSString *postLength = [NSString stringWithFormat:@"%d", [postData length]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSURLResponse *response = [[NSURLResponse alloc]init];
    NSError *err;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&err];
    
    NSError *jsonParsingError = nil;
    NSDictionary *respJSON = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonParsingError];

    
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
