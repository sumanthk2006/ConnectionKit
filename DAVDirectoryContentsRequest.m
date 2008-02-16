/*
 Copyright (c) 2004-2006, Greg Hulands <ghulands@mac.com>
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, 
 are permitted provided that the following conditions are met:
 
 Redistributions of source code must retain the above copyright notice, this list 
 of conditions and the following disclaimer.
 
 Redistributions in binary form must reproduce the above copyright notice, this 
 list of conditions and the following disclaimer in the documentation and/or other 
 materials provided with the distribution.
 
 Neither the name of Greg Hulands nor the names of its contributors may be used to 
 endorse or promote products derived from this software without specific prior 
 written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY 
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
 SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
 BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY 
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "DAVDirectoryContentsRequest.h"
#import "DAVDirectoryContentsResponse.h"

@implementation DAVDirectoryContentsRequest

+ (id)directoryContentsForPath:(NSString *)path
{
	return [[[DAVDirectoryContentsRequest alloc] initWithMethod:nil uri:path] autorelease];
}

- (id)initWithMethod:(NSString *)method uri:(NSString *)uri
{
	if (![uri hasPrefix:@"/"])
	{
		uri = [NSString stringWithFormat:@"/%@", uri];
	}
	if (![uri hasSuffix:@"/"])
	{
		uri = [NSString stringWithFormat:@"%@/", uri];
	}
	
	if (self = [super initWithMethod:@"PROPFIND" uri:uri])
	{
		[self setHeader:@"0" forKey:@"Depth"];
		
		myPath = [uri copy];
		
		NSMutableString *xml = [NSMutableString string];
		[xml appendString:@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n"];
		[xml appendString:@"<D:propfind xmlns:D=\"DAV:\">\n"];
		[xml appendString:@"<D:allprop/>\n"];
		[xml appendString:@"</D:propfind>\n"];
		
		[self setContentString:xml];
	}
	return self;
}

- (void)dealloc
{
	[myPath release];
	[super dealloc];
}

- (DAVResponse *)responseWithData:(NSData *)data
{
	NSRange r = [DAVResponse canConstructResponseWithData:data];
	if (r.location != NSNotFound)
	{
		return [DAVDirectoryContentsResponse responseWithRequest:self data:data];
	}
	return nil;
}

- (NSString *)path
{
	return myPath;
}

@end

