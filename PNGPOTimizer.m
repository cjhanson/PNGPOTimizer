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


