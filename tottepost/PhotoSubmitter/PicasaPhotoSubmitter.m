//
//  PicasaPhotoSubmitter.m
//  tottepost
//
//  Created by Kentaro ISHITOYA on 12/02/10.
//  Copyright (c) 2012 cocotomo. All rights reserved.
//

#import "PhotoSubmitterAPIKey.h"
#import "PicasaPhotoSubmitter.h"
#import "PhotoSubmitterManager.h"
#import "UIImage+Digest.h"
#import "UIImage+EXIF.h"
#import "RegexKitLite.h"
#import "GTMOAuth2ViewControllerTouch.h"

#define PS_PICASA_ENABLED @"PSPicasaEnabled"
#define PS_PICASA_AUTH_URL @"photosubmitter://auth/evernote"
#define PS_PICASA_SCOPE @"https://picasaweb.google.com/data/"
#define PS_PICASA_KEYCHAIN_NAME @"PSPicasaKeychain"
#define PS_PICASA_SETTING_USERNAME @"PSPicasaUserName"
#define PS_PICASA_SETTING_ALBUMS @"PSPicasaAlbums"
#define PS_PICASA_SETTING_TARGET_ALBUM @"PSPicasaTargetAlbums"

//-----------------------------------------------------------------------------
//Private Implementations
//-----------------------------------------------------------------------------
@interface PicasaPhotoSubmitter(PrivateImplementation)
- (void) setupInitialState;
- (void) clearCredentials;
- (void) viewController:(GTMOAuth2ViewControllerTouch *)viewController
       finishedWithAuth:(GTMOAuth2Authentication *)auth
                  error:(NSError *)error;
- (void) doAnAuthenticatedAPIFetch;
@end

@implementation PicasaPhotoSubmitter(PrivateImplementation)
#pragma mark -
#pragma mark private implementations
/*!
 * initializer
 */
-(void)setupInitialState{
}

/*!
 * clear Picasa credential
 */
- (void)clearCredentials{
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:PS_PICASA_KEYCHAIN_NAME];
    [self removeSettingForKey:PS_PICASA_SETTING_USERNAME];
    [self removeSettingForKey:PS_PICASA_SETTING_ALBUMS];
    [self removeSettingForKey:PS_PICASA_SETTING_TARGET_ALBUM];
}

/*!
 * on authenticated
 */
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)auth
                 error:(NSError *)error {
    if (error != nil) {
        NSLog(@"Authentication error: %@", error);
        NSData *responseData = [[error userInfo] objectForKey:@"data"];        
        if ([responseData length] > 0) {
            NSString *str = 
            [[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding];
            NSLog(@"%@", str);
        }
        [self.authDelegate photoSubmitter:self didLogout:self.type];
        [self.authDelegate photoSubmitter:self didAuthorizationFinished:self.type];
        [self clearCredentials];
    } else {
        auth_ = auth;
        [self.authDelegate photoSubmitter:self didLogin:self.type];
        [self.authDelegate photoSubmitter:self didAuthorizationFinished:self.type]; 
    }
}

/*!
 * doAnAuthenticatedAPIFetch
 */
- (void)doAnAuthenticatedAPIFetch {
    NSString *urlStr = @"http://www.google.com/m8/feeds/contacts/default/thin";
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [auth_ authorizeRequest:request];

    NSError *error = nil;
    NSURLResponse *response = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request
                                         returningResponse:&response
                                                     error:&error];
    if (data) {
        // API fetch succeeded
        NSString *str = [[NSString alloc] initWithData:data
                                              encoding:NSUTF8StringEncoding];
        NSLog(@"API response: %@", str);
    } else {
        // fetch failed
        NSLog(@"API fetch error: %@", error);
        [self.authDelegate photoSubmitter:self didLogout:self.type];
        [self.authDelegate photoSubmitter:self didAuthorizationFinished:self.type];
        [self clearCredentials];
    }
}
@end

//-----------------------------------------------------------------------------
//Public Implementations
//-----------------------------------------------------------------------------
@implementation PicasaPhotoSubmitter
@synthesize authDelegate;
@synthesize dataDelegate;
#pragma mark -
#pragma mark public implementations
/*!
 * initialize
 */
- (id)init{
    self = [super init];
    if (self) {
        [self setupInitialState];
    }
    return self;
}

/*!
 * submit photo with data, comment and delegate
 */
- (void)submitPhoto:(PhotoSubmitterImageEntity *)photo andOperationDelegate:(id<PhotoSubmitterPhotoOperationDelegate>)delegate{    
/*    NSString *hash = photo.md5;
    [self addRequest:request];
    [self setPhotoHash:hash forRequest:request];
    [self setOperationDelegate:delegate forRequest:request];
    [self photoSubmitter:self willStartUpload:hash];*/
    
}    

/*!
 * cancel photo upload
 */
- (void)cancelPhotoSubmit:(PhotoSubmitterImageEntity *)photo{
}

/*!
 * login to Picasa
 */
-(void)login{
    if ([self isLogined]) {
        [self setSetting:@"enabled" forKey:PS_PICASA_ENABLED];
        [self.authDelegate photoSubmitter:self didLogin:self.type];
        return;
    }else{
        [self.authDelegate photoSubmitter:self willBeginAuthorization:self.type];
        /*auth_ = [GTMOAuth2ViewControllerTouch 
                 authForGoogleFromKeychainForName:PS_PICASA_KEYCHAIN_NAME
                 clientID:GOOGLE_SUBMITTER_API_KEY
                 clientSecret:GOOGLE_SUBMITTER_API_SECRET];*/
        SEL finishedSel = @selector(viewController:finishedWithAuth:error:);        
        GTMOAuth2ViewControllerTouch *viewController;
        viewController = 
        [GTMOAuth2ViewControllerTouch controllerWithScope:PS_PICASA_SCOPE
                                                 clientID:GOOGLE_SUBMITTER_API_KEY
                                             clientSecret:GOOGLE_SUBMITTER_API_SECRET
                                         keychainItemName:PS_PICASA_KEYCHAIN_NAME
                                                 delegate:self
                                         finishedSelector:finishedSel];
        
        //[[self navigationController] pushViewController:viewController animated:YES];
    }
}

/*!
 * logoff from Picasa
 */
- (void)logout{  
    if ([[auth_ serviceProvider] isEqual:kGTMOAuth2ServiceProviderGoogle]) {
        [GTMOAuth2ViewControllerTouch revokeTokenForGoogleAuthentication:auth_];
    }
    [self clearCredentials];
    [self removeSettingForKey:PS_PICASA_ENABLED];
    [self.authDelegate photoSubmitter:self didLogout:self.type];
}

/*!
 * disable
 */
- (void)disable{
    [self removeSettingForKey:PS_PICASA_ENABLED];
    [self.authDelegate photoSubmitter:self didLogout:self.type];
}

/*!
 * check is logined
 */
- (BOOL)isLogined{
    if(self.isEnabled == false){
        return NO;
    }
    if ([auth_ canAuthorize]) {
        return YES;
    }
    return NO;
}

/*!
 * check is enabled
 */
- (BOOL) isEnabled{
    return [PicasaPhotoSubmitter isEnabled];
}

/*!
 * return type
 */
- (PhotoSubmitterType) type{
    return PhotoSubmitterTypePicasa;
}

/*!
 * check url is processoble
 */
- (BOOL)isProcessableURL:(NSURL *)url{
    if([url.absoluteString isMatchedByRegex:PS_PICASA_AUTH_URL]){
        return YES;    
    }
    return NO;
}

/*!
 * on open url finished
 */
- (BOOL)didOpenURL:(NSURL *)url{
/*    [evernote_ handleOpenURL:url];
    BOOL result = NO;
    if([evernote_ isSessionValid]){
        [self setSetting:@"enabled" forKey:PS_PICASA_ENABLED];
        [self.authDelegate photoSubmitter:self didLogin:self.type];
        result = YES;
    }else{
        [self.authDelegate photoSubmitter:self didLogout:self.type];
    }
    [self.authDelegate photoSubmitter:self didAuthorizationFinished:self.type];
    return result;*/
    return NO;
}

/*!
 * name
 */
- (NSString *)name{
    return @"Picasa";
}

/*!
 * icon image
 */
- (UIImage *)icon{
    return [UIImage imageNamed:@"evernote_32.png"];
}

/*!
 * small icon image
 */
- (UIImage *)smallIcon{
    return [UIImage imageNamed:@"evernote_16.png"];
}

/*!
 * get username
 */
- (NSString *)username{
    return [self settingForKey:PS_PICASA_SETTING_USERNAME];
}

/*!
 * albumlist
 */
- (NSArray *)albumList{
    return [self complexSettingForKey:PS_PICASA_SETTING_ALBUMS];
}

/*!
 * update album list
 */
- (void)updateAlbumListWithDelegate:(id<PhotoSubmitterDataDelegate>)delegate{
    self.dataDelegate = delegate;
    //PicasaRequest *request = [evernote_ notebooksWithDelegate:self];
    //[self addRequest:request];
}

/*!
 * selected album
 */
- (PhotoSubmitterAlbumEntity *)targetAlbum{
    return [self complexSettingForKey:PS_PICASA_SETTING_TARGET_ALBUM];
}

/*!
 * save selected album
 */
- (void)setTargetAlbum:(PhotoSubmitterAlbumEntity *)targetAlbum{
    [self setComplexSetting:targetAlbum forKey:PS_PICASA_SETTING_TARGET_ALBUM];
}

/*!
 * update username
 */
- (void)updateUsernameWithDelegate:(id<PhotoSubmitterDataDelegate>)delegate{
    self.dataDelegate = delegate;
    //PicasaRequest *request = [evernote_ userWithDelegate:self];
    //[self addRequest:request];
}

/*!
 * invoke method as concurrent?
 */
- (BOOL)isConcurrent{
    return YES;
}

/*!
 * is sequencial? if so, use SequencialQueue
 */
- (BOOL)isSequencial{
    return NO;
}

/*!
 * requires network
 */
- (BOOL)requiresNetwork{
    return YES;
}

/*!
 * isEnabled
 */
+ (BOOL)isEnabled{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:PS_PICASA_ENABLED]) {
        return YES;
    }
    return NO;
}
@end
