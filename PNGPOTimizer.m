/*
 *  PNGPOTimizer.m
 *  PNGPOTimizer
 *
 *  Created by CJ Hanson on 3/19/10.
 *  Copyright 2010 Hanson Interactive.
 
 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any damages
 arising from the use of this software.
 
 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:
 
 1. The origin of this software must not be misrepresented; you must not
 claim that you wrote the original software. If you use this software
 in a product, an acknowledgment in the product documentation would be
 appreciated but is not required.
 2. Altered source versions must be plainly marked as such, and must not be
 misrepresented as being the original software.
 3. This notice may not be removed or altered from any source distribution.
 
 * 
 */

#import <Foundation/Foundation.h>
#import "GetPathsOperation.h"
#import "ImageOperations.h"

NSString *getStringPathFromCString(const char *path);

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSOperationQueue *opQueue	= [[NSOperationQueue alloc] init];
	Class opClass				= [POTImageOperation class];
    // insert code here...
	for(int i=1; i<argc; i++){
		NSAutoreleasePool *loopPool = [NSAutoreleasePool new];
		NSString *path				= [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
		NSOperation *anOp			= [[[GetPathsOperation alloc] initWithRootPath:path operationClass:opClass queue:opQueue] autorelease];
		[opQueue addOperation:anOp];
		[loopPool drain];
	}
	
	[opQueue waitUntilAllOperationsAreFinished];
	
	[opQueue release];
	
    [pool drain];
    return 0;
}


