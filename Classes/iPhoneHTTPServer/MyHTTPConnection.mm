//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "MyHTTPConnection.h"
#import "HTTPServer.h"
#import "HTTPResponse.h"
#import "AsyncSocket.h"

#import "SwordManager.h"
#import "SwordModule.h"

@implementation MyHTTPConnection

/**
 * Returns whether or not the requested resource is browseable.
**/
- (BOOL)isBrowseable:(NSString *)path
{
	// Override me to provide custom configuration...
	// You can configure it for the entire server, or based on the current request
	
	return YES;
}


/**
 * This method creates a html browseable page.
 * Customize to fit your needs
**/
- (NSString *)createBrowseableIndex:(NSString *)path
{
    //NSArray *array = [[NSFileManager defaultManager] directoryContentsAtPath:path];
	SwordManager *manager = [SwordManager defaultManager];
	NSMutableArray *mods = [NSMutableArray arrayWithArray:[manager listModules]];
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor]; 
    [mods sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
    
    NSMutableString *outdata = [NSMutableString new];
	[outdata appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
	 <!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n\
	 <html dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\"\n\
	 xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
	 xsi:schemaLocation=\"http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd\"\n\
	 xml:lang=\"en\" >\n"];
	[outdata appendFormat:@"<head>\n<title>Installed Modules (%@)</title>\n", server.name];
    [outdata appendString:@"<style type=\"text/css\">html {background-color:#eeeeee} body { background-color:#FFFFFF; font-family:Helvetica,Tahoma,Arial,sans-serif; font-size:18x; margin-left:15%; margin-right:15%; border:3px groove #006600; padding:15px; } </style>\n"];
    [outdata appendString:@"</head>\n<body>\n"];
	[outdata appendFormat:@"<h1>Installed Modules (%@)</h1>\n", server.name];
    [outdata appendFormat:@"<bq>The following modules are currently installed in PocketSword on the iPhone %@:</bq>\n", server.name];
    [outdata appendString:@"<p>\n"];
	//[outdata appendFormat:@"<a href=\"..\">..</a><br />\n"];
    //for (NSString *fname in array)
    //{
		//NSDictionary *fileDict = [[NSFileManager defaultManager] fileAttributesAtPath:[path stringByAppendingPathComponent:fname] traverseLink:NO];
		//DLog(@"fileDict: %@", fileDict);
		//    NSString *modDate = [[fileDict objectForKey:NSFileModificationDate] description];
		//if ([[fileDict objectForKey:NSFileType] isEqualToString: @"NSFileTypeDirectory"]) fname = [fname stringByAppendingString:@"/"];
		//[outdata appendFormat:@"<a href=\"%@\">%@</a>		(%8.1f Kb, %@)<br />\n", fname, fname, [[fileDict objectForKey:NSFileSize] floatValue] / 1024, modDate];
	//}
	for (SwordModule *mod in mods) {
		[outdata appendFormat:@"&nbsp; &nbsp; <b> %@ </b> (<i>%@</i>)<br />\n", [mod name], [[mod descr] stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]];
	}
    [outdata appendString:@"</p>\n"];
	
	if ([self supportsPOST:path withSize:0])
	{
		[outdata appendString:@"<form action=\"\" method=\"post\" enctype=\"multipart/form-data\" name=\"form1\" id=\"form1\">\n"];
		[outdata appendString:@"<label>Upload &amp; install raw zipped module: "];
		[outdata appendString:@"<input type=\"file\" name=\"file\" id=\"file\" />"];
		[outdata appendString:@"</label>\n"];
		[outdata appendString:@"<label>"];
		[outdata appendString:@"<input type=\"submit\" name=\"button\" id=\"button\" value=\"Submit\" />"];
		[outdata appendString:@"</label>\n"];
		[outdata appendString:@"</form>\n"];
	}
	[outdata appendString:@"<p>The format of the raw zipped module expected is the same format as can be found in the <a href=\"http://crosswire.org/ftpmirror/pub/sword/packages/rawzip/\">Crosswire repository</a>.</p>\n\
	 <p>However, if you wish to be able to search in any modules installed in this way, you need to create the clucene indexes yourself & place them in the correct location within the zip file.</p>\n\
	 <p>If you haven't realised that this method of installing modules isn't for the faint of heart and is only suggested for those who know what they're doing.  It is provided as a courtesy for Module Maintainers.</p>\n\
	 <p>If the upload and install is successful, the new module will be added to the above list.  If it fails, it will fail silently.  This may be modified in the future if there are enough requests for improved functionality, but it is hoped and assumed that users will use the inbuilt module installer.</p>\n\
	 </body>\n</html>\n"];
    
	//DLog(@"outData: %@", outdata);
    return [outdata autorelease];
}


- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)relativePath
{
	if ([@"POST" isEqualToString:method])
	{
		return YES;
	}
	
	return [super supportsMethod:method atPath:relativePath];
}


/**
 * Returns whether or not the server will accept POSTs.
 * That is, whether the server will accept uploaded data for the given URI.
**/
- (BOOL)supportsPOST:(NSString *)path withSize:(UInt64)contentLength
{
	//NSLog(@"POST:%@ (aka, [[multipartData alloc] init]", path);
	
	dataStartIndex = 0;
	if(multipartData) {
		[multipartData release];
	}
	multipartData = [[[NSMutableArray alloc] init] retain];
	postHeaderOK = FALSE;
	
	return YES;
}


/**
 * This method is called to get a response for a request.
 * You may return any object that adopts the HTTPResponse protocol.
 * The HTTPServer comes with two such classes: HTTPFileResponse and HTTPDataResponse.
 * HTTPFileResponse is a wrapper for an NSFileHandle object, and is the preferred way to send a file response.
 * HTTPDataResopnse is a wrapper for an NSData object, and may be used to send a custom response.
**/
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	//DLog(@"httpResponseForURI: method:%@ path:%@", method, path);
	
	//NSData *requestData = [(NSData *)CFHTTPMessageCopySerializedMessage(request) autorelease];
	
	//NSString *requestStr = [[[NSString alloc] initWithData:requestData encoding:NSASCIIStringEncoding] autorelease];
	//DLog(@"\n=== Request ====================\n%@\n================================", requestStr);
	
	if (requestContentLength > 0)  // Process POST data
	{
		//DLog(@"\nprocessing post data: %i", requestContentLength);
		
		if ([multipartData count] < 2) {
			DLog(@"[multipartData count] < 2 so we're bailing");
			// TODO: make this return an error page
			return nil;
		}
		
		NSString* postInfo = [[NSString alloc] initWithBytes:[[multipartData objectAtIndex:1] bytes]
													  length:[[multipartData objectAtIndex:1] length]
													encoding:NSUTF8StringEncoding];
		
		NSArray* postInfoComponents = [postInfo componentsSeparatedByString:@"; filename="];
		postInfoComponents = [[postInfoComponents lastObject] componentsSeparatedByString:@"\""];
		postInfoComponents = [[postInfoComponents objectAtIndex:1] componentsSeparatedByString:@"\\"];
		NSString* filename = [postInfoComponents lastObject];
		
		if (![filename isEqualToString:@""]) //this makes sure we did not submitted upload form without selecting file
		{
			UInt16 separatorBytes = 0x0A0D;
			NSMutableData* separatorData = [NSMutableData dataWithBytes:&separatorBytes length:2];
			[separatorData appendData:[multipartData objectAtIndex:0]];
			int l = [separatorData length];
			int count = 2;	//number of times the separator shows up at the end of file data
			
			NSFileHandle* dataToTrim = [multipartData lastObject];
			//DLog(@"data: %@", dataToTrim);
			
			for (unsigned long long i = [dataToTrim offsetInFile] - l; i > 0; i--)
			{
				[dataToTrim seekToFileOffset:i];
				if ([[dataToTrim readDataOfLength:l] isEqualToData:separatorData])
				{
					[dataToTrim truncateFileAtOffset:i];
					i -= l;
					if (--count == 0) break;
				}
			}
			
			//DLog(@"NewFileUploaded: %@", filename);
			[[NSNotificationCenter defaultCenter] postNotificationName:@"NewFileUploaded" object:filename];
		}
		
		for (int n = 1; n < [multipartData count] - 1; n++) {
			DLog(@"%@", [[NSString alloc] initWithBytes:[[multipartData objectAtIndex:n] bytes] length:[[multipartData objectAtIndex:n] length] encoding:NSUTF8StringEncoding]);
		}
		
		[postInfo release];
		[multipartData release];
		requestContentLength = 0;
		
	}
	
	NSString *filePath = [self filePathForURI:path];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		return [[[HTTPFileResponse alloc] initWithFilePath:filePath] autorelease];
	}
	else
	{
		NSString *folder = [path isEqualToString:@"/"] ? [[server documentRoot] path] : [NSString stringWithFormat: @"%@%@", [[server documentRoot] path], path];

		if ([self isBrowseable:folder])
		{
			//DLog(@"folder: %@", folder);
			NSData *browseData = [[self createBrowseableIndex:folder] dataUsingEncoding:NSUTF8StringEncoding];
			return [[[HTTPDataResponse alloc] initWithData:browseData] autorelease];
		}
	}
	
	return nil;
}


/**
 * This method is called to handle data read from a POST.
 * The given data is part of the POST body.
**/
- (void)processDataChunk:(NSData *)postDataChunk
{
	// Override me to do something useful with a POST.
	// If the post is small, such as a simple form, you may want to simply append the data to the request.
	// If the post is big, such as a file upload, you may want to store the file to disk.
	// 
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	if(!multipartData) {
		DLog(@"WARNING: initing multipartData ourselves!");
		multipartData = [[[NSMutableArray alloc] init] retain];
	}
	//NSString *test = (multipartData) ? @"YES" : @"NO";
	//NSLog(@"processPostDataChunk:length = %d (%@)", [postDataChunk length], test);
	
	if (!postHeaderOK)
	{
		UInt16 separatorBytes = 0x0A0D;
		NSData* separatorData = [NSData dataWithBytes:&separatorBytes length:2];
		
		int l = [separatorData length];

		for (int i = 0; i < [postDataChunk length] - l; i++)
		{
			NSRange searchRange = {i, l};

			if ([[postDataChunk subdataWithRange:searchRange] isEqualToData:separatorData])
			{
				NSRange newDataRange = {dataStartIndex, i - dataStartIndex};
				dataStartIndex = i + l;
				i += l - 1;
				NSData *newData = [postDataChunk subdataWithRange:newDataRange];

				//NSLog(@"[newData length] = %d", [newData length]);
				if ([newData length])
				{
					[multipartData addObject:newData];
				}
				else
				{
					postHeaderOK = TRUE;
					//NSLog(@"multipartData: %@", multipartData);
					if(!multipartData)
						continue;
					NSString* postInfo = [[NSString alloc] initWithBytes:[[multipartData objectAtIndex:1] bytes] length:[[multipartData objectAtIndex:1] length] encoding:NSUTF8StringEncoding];
					//NSLog(@"postInfo: %@", postInfo);
					//if(![postInfo length] > 0)
						//continue;
					NSArray* postInfoComponents = [postInfo componentsSeparatedByString:@"; filename="];
					postInfoComponents = [[postInfoComponents lastObject] componentsSeparatedByString:@"\""];
					postInfoComponents = [[postInfoComponents objectAtIndex:1] componentsSeparatedByString:@"\\"];
					NSString* filename = [[[server documentRoot] path] stringByAppendingPathComponent:[postInfoComponents lastObject]];
					NSRange fileDataRange = {dataStartIndex, [postDataChunk length] - dataStartIndex};
					
					[[NSFileManager defaultManager] createFileAtPath:filename contents:[postDataChunk subdataWithRange:fileDataRange] attributes:nil];
					NSFileHandle *file = [[NSFileHandle fileHandleForUpdatingAtPath:filename] retain];
					
					//NSLog(@"filename = %@", filename);
					
					if (file)
					{
						[file seekToEndOfFile];
						[multipartData addObject:file];
						[file release];
					}
					
					[postInfo release];
					
					break;
				}
			}
		}
	}
	else
	{
		//NSLog(@"postHeaderOK");
		[(NSFileHandle*)[multipartData lastObject] writeData:postDataChunk];
	}
}

@end