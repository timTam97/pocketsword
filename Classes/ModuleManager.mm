/*
	PocketSword - A frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2009 Ian Wagner

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "ModuleManager.h"

@implementation ModuleManager

@synthesize installedModules;
@synthesize downloadableBibles;
@synthesize downloadableZCommentaries;
@synthesize downloadableRawCommentaries;
@synthesize betaBibles;
@synthesize library;
@synthesize primaryText;

NSString *libDir;
float installationProgress;

- (ModuleManager *)init {
	self = [super init];
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	libDir = [[paths objectAtIndex: 0] stringByAppendingString: @"/"];
	//libDir = [[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/data/library/"];
	
	// Create a library manager
	self.library = new SWMgr([libDir UTF8String], true, new MarkupFilterMgr(FMT_HTMLHREF, ENC_HTML));
	self.library->setGlobalOption("Cross-references","Off");
	self.library->setGlobalOption("Strong's Numbers","Off");
	self.library->setGlobalOption("Headings","On");
	self.library->setGlobalOption("Footnotes","Off");
	self.library->setGlobalOption("Words of Christ in Red","On");
	
	self.downloadableBibles = [[NSMutableArray arrayWithObjects: nil] retain];
	self.downloadableZCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
	self.downloadableRawCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
	self.betaBibles = [[NSMutableArray arrayWithObjects: nil] retain];
	[self performSelectorInBackground: @selector(reloadRepositoryModuleList) withObject: nil];
	
	self.installedModules = [[NSMutableDictionary dictionaryWithCapacity: 10] retain];
	for (ModMap::iterator it = library->Modules.begin(); it != library->Modules.end(); it++) {
		NSString *modName = [NSString stringWithUTF8String: (*it).second->Name()];
		NSString *modType = [NSString stringWithUTF8String: (*it).second->Type()];
		NSLog(@"Found module [%@] with type %@", modName, modType);
		
		NSMutableArray *array = [installedModules objectForKey: modType];
		if (array == nil) {
			array = [NSMutableArray arrayWithObjects: nil];
		}
		[array insertObject: modName atIndex: [array count]];
		
		[installedModules setObject: array forKey: modType];
	}
	
	return self;
}

- (SWModule *)getPrimaryText {
	return primaryText;
}

- (void)loadPrimaryText:(NSString *)newText {
	primaryText = library->getModule([newText UTF8String]);
}

- (NSArray *)installedBibles {	
	// TODO: Return only installed bibles, not all modules
	NSMutableArray *bibles = [NSMutableArray arrayWithObjects: nil];
	for (ModMap::iterator it = library->Modules.begin(); it != library->Modules.end(); it++) {
		NSString *mod = [NSString stringWithUTF8String: (*it).second->Name()];
		NSString *modType = [NSString stringWithUTF8String: (*it).second->Type()];
		NSLog(@"Found module [%@] with type %@", mod, modType);
		if ([modType isEqualToString: @"Biblical Texts"]) {
			[bibles insertObject: mod atIndex: [bibles count]];
		}
	}
	return bibles;
}

// Returns a dictionary with the format being
// { 'type1': ['mod1', 'mod2'], 'type2': ['mod3', 'mod4'] } etc
- (NSDictionary *)getInstalledModules {
	return installedModules;
}

- (void)reload {
	bool restoreText = false;
	SWKey loc;
	NSString *moduleName;
	
	if (primaryText) {
		restoreText = true;
		loc = primaryText->getKeyText();
		moduleName = [NSString stringWithUTF8String: primaryText->Name()];
	}
	
	library->Load();
	installationProgress = 0;
	
	installedModules = [[NSMutableDictionary dictionaryWithCapacity: 10] retain];
	for (ModMap::iterator it = library->Modules.begin(); it != library->Modules.end(); it++) {
		NSString *modName = [NSString stringWithUTF8String: (*it).second->Name()];
		NSString *modType = [NSString stringWithUTF8String: (*it).second->Type()];
		NSLog(@"Found module [%@] with type %@", modName, modType);
		
		NSMutableArray *array = [installedModules objectForKey: modType];
		if (array == nil) {
			array = [NSMutableArray arrayWithObjects: nil];
		}
		[array insertObject: modName atIndex: [array count]];
		
		[installedModules setObject: array forKey: modType];
	}
	
	if (restoreText) {
		primaryText = library->getModule([moduleName UTF8String]);
		if (primaryText) {
			primaryText->setKey(loc);
		}
	}
}

- (void)reloadRepositoryModuleList {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	// Get the bible directory listing page
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/texts/ztext/"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 30.0];
	NSData *responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		downloadableBibles = [[NSMutableArray arrayWithObjects: nil] retain];
		[pool release];
		return;
	}
	
	NSString *dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	
	// Parse out a listing :)
	NSRange dataRange;
	downloadableBibles = [[NSMutableArray arrayWithObjects: nil] retain];
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *item = [dataString substringToIndex: dataRange.location - 1];
			if (isalnum([item characterAtIndex: 0])) {
				[downloadableBibles addObject: item];
			}
		}
	}
	
	// Get the z-compressed commentary directory listing page
	request = [NSURLRequest requestWithURL: [NSURL URLWithString: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/comments/zcom/"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 30.0];
	responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		downloadableZCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
		[pool release];
		return;
	}
	
	dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	
	// Parse out a listing :)
	downloadableZCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *item = [dataString substringToIndex: dataRange.location - 1];
			if (isalnum([item characterAtIndex: 0])) {
				[downloadableZCommentaries addObject: item];
			}
		}
	}
	
	// Get the raw commentary directory listing page
	request = [NSURLRequest requestWithURL: [NSURL URLWithString: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/comments/rawcom/"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 30.0];
	responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		downloadableRawCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
		[pool release];
		return;
	}
	
	dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	
	// Parse out a listing :)
	downloadableRawCommentaries = [[NSMutableArray arrayWithObjects: nil] retain];
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *item = [dataString substringToIndex: dataRange.location - 1];
			if (isalnum([item characterAtIndex: 0])) {
				[downloadableRawCommentaries addObject: item];
			}
		}
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"beta_preference"]) {
		// Get the beta bible directory listing page
		request = [NSURLRequest requestWithURL: [NSURL URLWithString: @"http://crosswire.org/ftpmirror/pub/sword/betaraw/modules/texts/ztext/"] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 30.0];
		responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
		if (!responseData) {
			betaBibles = [[NSMutableArray arrayWithObjects: nil] retain];
			[pool release];
			return;
		}
		
		dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
		
		// Parse out a listing :)
		betaBibles = [[NSMutableArray arrayWithObjects: nil] retain];
		while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
			dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
			dataRange = [dataString rangeOfString: @"\""];
			if (dataRange.location != NSNotFound) {
				NSString *item = [dataString substringToIndex: dataRange.location - 1];
				if (isalnum([item characterAtIndex: 0])) {
					[betaBibles addObject: item];
				}
			}
		}
	}
	
	NSLog(@"Module list fetched");
	
	[pool release];
}

- (float)getInstallationProgress {
	return installationProgress;
}

- (BOOL)installModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	installationProgress = 0.0;
	
	NSURLRequest *request;
	NSData *responseData;
	NSString *dataString;
	NSMutableArray *files;
	NSRange dataRange;
	NSString *moduleDir;
	NSString *link;
	
	if ([downloadableBibles containsObject: name]) {
		moduleDir = [NSString stringWithFormat: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/texts/ztext/%@/", name];
		link = [@"http://crosswire.org/ftpmirror/pub/sword/raw/mods.d/" stringByAppendingFormat: @"%@.conf", name];
	}
	else if ([betaBibles containsObject: name]) {
		moduleDir = [NSString stringWithFormat: @"http://crosswire.org/ftpmirror/pub/sword/betaraw/modules/texts/ztext/%@/", name];
		link = [@"http://crosswire.org/ftpmirror/pub/sword/betaraw/mods.d/" stringByAppendingFormat: @"%@.conf", name];
	}
	else if ([downloadableZCommentaries containsObject: name]) {
		moduleDir = [NSString stringWithFormat: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/comments/zcom/%@/", name];
		link = [@"http://crosswire.org/ftpmirror/pub/sword/raw/mods.d/" stringByAppendingFormat: @"%@.conf", name];
	}
	else if ([downloadableRawCommentaries containsObject: name]) {
		moduleDir = [NSString stringWithFormat: @"http://crosswire.org/ftpmirror/pub/sword/raw/modules/comments/rawcom/%@/", name];
		link = [@"http://crosswire.org/ftpmirror/pub/sword/raw/mods.d/" stringByAppendingFormat: @"%@.conf", name];
	}
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *installDir = [[paths objectAtIndex: 0] stringByAppendingString: @"/"];
	
	NSLog(@"Starting installation for module %@", name);
	
	// Get the mdoule directory listing
	request = [NSURLRequest requestWithURL: [NSURL URLWithString: moduleDir] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		NSLog(@"Couldn't list remote directory");
		[pool release];
		return NO;
	}
	
	dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	files = [NSMutableArray arrayWithObjects: nil];
	
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *item = [dataString substringToIndex: dataRange.location];
			if (isalnum([item characterAtIndex: 0])) {
				[files addObject: item];
			}
		}
	}
	
	installationProgress = 0.01;
	
	[[NSFileManager defaultManager] createDirectoryAtPath: [installDir stringByAppendingString: @"mods.d"]
							  withIntermediateDirectories: YES attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: [installDir stringByAppendingString: @"mods.d"]] != YES) {
		NSLog(@"Couldn't create mods.d");
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	
	// Download module configuration file
	request = [NSURLRequest requestWithURL: [NSURL URLWithString: link] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		NSLog(@"Couldn't retrieve file: %@", link);
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	if (![responseData writeToFile: [installDir stringByAppendingFormat: @"mods.d/%@.conf", name] atomically: YES]) {
		NSLog(@"Couldn't write file: %@.conf", name);
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	
	SWConfig cfg([[installDir stringByAppendingFormat: @"mods.d/%@.conf", name] UTF8String]);
	NSArray *components = [[NSString stringWithUTF8String: (*cfg.Sections.begin()).second["DataPath"].c_str()] componentsSeparatedByString: @"modules/"];
	NSString *dataDir = [installDir stringByAppendingFormat: @"modules/%@", [components objectAtIndex: [components count] - 1]];
	NSLog(@"Using data path: %@", dataDir);
	
	[[NSFileManager defaultManager] createDirectoryAtPath: dataDir
						   withIntermediateDirectories: YES attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: dataDir] != YES) {
		NSLog(@"Couldn't create module directory");
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	
	// Download the data files
	NSUInteger numFiles = [files count];
	for (NSUInteger i = 0; i < numFiles; ++i) {
		NSString *filename = [files objectAtIndex: i];
		NSString *link = [moduleDir stringByAppendingString: filename];
		request = [NSURLRequest requestWithURL: [NSURL URLWithString: link] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
		responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
		if (!responseData) {
			NSLog(@"Couldn't retrieve file: %@", link);
			installationProgress = -1.0;
			[pool release];
			return NO;
		}
		if (![responseData writeToFile: [dataDir stringByAppendingString: filename] atomically: YES]) {
			NSLog(@"Couldn't write file: %@", [dataDir stringByAppendingString: filename]);
			installationProgress = -1.0;
			[pool release];
			return NO;
		}
		
		installationProgress = (((float)i / numFiles) - 0.01);
	}
	
	NSLog(@"Module %@ installed successfully!", name);
	[pool release];
	
	installationProgress = 1.0;
	return YES;
}

- (BOOL)removeModule:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSLog(@"Removing module: %@", name);
	
	BOOL success = YES;
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *swordDir = [[paths objectAtIndex: 0] stringByAppendingString: @"/"];
	
	NSError *error;
	SWModule *module = library->getModule([name UTF8String]);
	
	if ([[NSFileManager defaultManager] removeItemAtPath: [NSString stringWithUTF8String: module->getConfigEntry("AbsoluteDataPath")] error: &error]) {
		NSLog(@"Deleted module directory");
	}
	else {
		NSLog(@"Module directory delete operation failed with error: %@", error);
		success = NO;
	}
	
	NSArray *pathComponents = [[NSString stringWithUTF8String: module->getConfigEntry("AbsoluteDataPath")] componentsSeparatedByString: @"/"];
	NSString *confName = [pathComponents objectAtIndex: [pathComponents count] - 2];
	if ([[NSFileManager defaultManager] removeItemAtPath: [swordDir stringByAppendingFormat: @"mods.d/%@.conf", confName] error: &error]) {
		NSLog(@"Deleted module conf");
	}
	else {
		NSLog(@"Path: %@", [swordDir stringByAppendingFormat: @"mods.d/%@.conf", confName]);
		NSLog(@"Module conf delete operation failed with error: %@", error);
		success = NO;
	}
		
	[self reload];
	[moduleTable reloadData];
	
	[pool release];
	return success;
}

// Installs the search index for the primary text
- (BOOL)installSearchIndex {
	if (!primaryText) {
		return NO;
	}
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *dataDir = [NSString stringWithUTF8String: primaryText->getConfigEntry("AbsoluteDataPath")];
	NSArray *components = [dataDir componentsSeparatedByString: @"/"];
	NSString *indexDir = [dataDir stringByAppendingPathComponent: @"lucene"];
	NSString *modName = [components objectAtIndex: [components count] - 2];
	NSString *remoteDir = [NSString stringWithFormat: @"http://pocketsword.net/indices/%@/", modName];
	
	// Get the index directory listing
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: remoteDir]
											 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	NSData *responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!responseData) {
		NSLog(@"Couldn't list remote directory");
		[pool release];
		return NO;
	}
	
	NSString *dataString = [[NSString alloc] initWithData: responseData encoding: [NSString defaultCStringEncoding]];
	NSMutableArray *files = [NSMutableArray arrayWithObjects: nil];
	NSRange dataRange;
	
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *item = [dataString substringToIndex: dataRange.location];
			if ([item UTF8String][0] != '/') {
				[files addObject: item];
			}
		}
	}
	
	installationProgress = 0.01;
	
	[[NSFileManager defaultManager] createDirectoryAtPath: indexDir withIntermediateDirectories: NO attributes: NULL error: NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath: indexDir] != YES) {
		NSLog(@"Couldn't create index directory");
		installationProgress = -1.0;
		[pool release];
		return NO;
	}
	
	// Download the data files
	NSUInteger numFiles = [files count];
	for (NSUInteger i = 0; i < numFiles; ++i) {
		NSString *filename = [files objectAtIndex: i];
		NSString *link = [remoteDir stringByAppendingString: filename];
		request = [NSURLRequest requestWithURL: [NSURL URLWithString: link] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
		responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
		if (!responseData) {
			NSLog(@"Couldn't retrieve file: %@", link);
			installationProgress = -1.0;
			[pool release];
			return NO;
		}
		if (![responseData writeToFile: [indexDir stringByAppendingPathComponent: filename] atomically: YES]) {
			NSLog(@"Couldn't write file: %@", [indexDir stringByAppendingPathComponent: filename]);
			installationProgress = -1.0;
			[pool release];
			return NO;
		}
		
		installationProgress = (((float)i / numFiles) - 0.01);
	}
	
	NSLog(@"Indices installed successfully");
	
	installationProgress = 1.0;
	[pool release];
	return YES;
}

// Grabs the text for a given chapter (e.g. "Gen 1")
- (NSString *)getChapter:(NSString *)chapter {	
	if (!primaryText) {
		[self reload];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *lastModule = [defaults stringForKey: @"lastModule"];
		NSMutableDictionary *prefs = [[defaults persistentDomainForName: [[NSBundle mainBundle] bundleIdentifier]] mutableCopy];
		
		if (lastModule != nil) {
			primaryText = library->getModule([lastModule UTF8String]);
		}
		
		if (!primaryText && [[self installedBibles] count] > 0) {
			primaryText = library->getModule([[[self installedBibles] objectAtIndex: 0] UTF8String]);
			[prefs removeObjectForKey: @"bookmarks"];
			[prefs setObject: [NSString stringWithUTF8String: primaryText->Name()] forKey: @"lastModule"];
			
			[defaults setPersistentDomain: prefs forName: [[NSBundle mainBundle] bundleIdentifier]];
		}
		else if (!primaryText) {
			return @"<font face=\"Helvetica\"><big><center>No modules installed.</center></big></font>";
		}
	}
	
	primaryText->setKey([chapter UTF8String]);
	SWKey lastKey;
	
	primaryText->RenderText();
	NSMutableString *verses = [@"" mutableCopy];
	NSString *ch = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	NSString *thisEntry = @"";
	NSString *lastEntry = @"";
	NSString *modType = [NSString stringWithUTF8String: primaryText->Type()];
	NSInteger i = 1;
	
	// Grab till the end of the chapter
	do {
		lastKey = primaryText->Key();
		thisEntry = [NSMutableString stringWithUTF8String: primaryText->RenderText()];
		if (![thisEntry isEqualToString: lastEntry]) {
			if ([modType isEqualToString: @"Commentaries"]) {
				[verses appendFormat: @"<p>%@</p>", thisEntry];
			}
			else {
				[verses appendFormat: @"&nbsp;<sup><small><b>%d</b></small></sup>%@", i, thisEntry];
			}
		}
		lastEntry = thisEntry;
		primaryText->Key()++;
		lastKey++;
		primaryText->RenderText();
		ref = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
		++i;
	} while ([ref isEqualToString: ch] && (primaryText->Key().Error() != KEYERR_OUTOFBOUNDS));
	
	primaryText->setKey([chapter UTF8String]);	// Set the key back to what we had it at
	
	NSString *fontSize = [[NSUserDefaults standardUserDefaults] stringForKey:@"font_preference"];
	NSString *text = [NSString stringWithFormat: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
					  <!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n\
					  \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n\
					  <html dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\"\n\
					  xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
					  xsi:schemaLocation=\"http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd\"\n\
					  xml:lang=\"en\" >\n\
					  <head>\n\
					  <style type=\"text/css\">\n\
					  body {\n\
					  font-size: %@pt;\n\
					  font-family: Helvetica;\n\
					  line-height: 130%%;\n\
					  }\n\
					  ruby { }\n\
					  </style>\n\
					  </head>\n\
					  <body><div>%@</div></body></html>", fontSize, verses];
	
	if (strcmp(primaryText->Name(), "KJV")) {	// If we are NOT using the KJV module, apply the ruby css
		text = [text stringByReplacingOccurrencesOfString: @"ruby { }\n" withString: @"ruby\n\
				{\n\
				display: inline-table;\n\
				text-align: center;\n\
				white-space: nowrap;\n\
				text-indent: 0;\n\
				margin: 0;\n\
				vertical-align: -10%%;\n\
				}\n\
				\n\
				ruby > rb, ruby > rbc\n\
				{\n\
				display: table-row-group;\n\
				line-height: 110%%;\n\
				}\n\
				\n\
				ruby > rt, ruby > rbc + rtc\n\
				{\n\
				display: table-header-group;\n\
				valign: top;\n\
				font-size: 60%%;\n\
				line-height: 40%%;\n\
				letter-spacing: 0;\n\
				}\n\
				\n\
				ruby > rbc + rtc + rtc\n\
				{\n\
				display: table-footer-group;\n\
				font-size: 60%%;\n\
				line-height: 40%%;\n\
				letter-spacing: 0;\n\
				}\n\
				\n\
				rbc > rb, rtc > rt\n\
				{\n\
				display: table-cell;\n\
				letter-spacing: 0;\n\
				}\n\
				\n\
				rtc > rt[rbspan] { display: table-caption; }\n\
				\n\
				rp { display: none; }\n"];
	}
	
	if (primaryText->Direction() == DIRECTION_RTL) {	// Fix RTL modules
		text = [text stringByReplacingOccurrencesOfString: @"dir=\"ltr\"" withString: @"dir=\"rtl\""];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject: chapter forKey: @"lastRef"];
	return text;
}

- (void)dealloc {
	[super dealloc];
}

@end
