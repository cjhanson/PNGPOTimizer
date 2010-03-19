#import <Foundation/Foundation.h>
#import "ImageOperations.h"

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    // insert code here...
	int totalConversions = 0;
	for(int i=1; i<argc; i++){
		NSAutoreleasePool *loopPool = [NSAutoreleasePool new];
		totalConversions += padImageFilePOT(argv[i]);
		[loopPool drain];
	}
/*
	const char *filePath = "../../../Git_iDance-uDance/Media/Images/Default.png";
	NSLog(@"Debug convert file %s", filePath);
	totalConversions += padImageFilePOT(filePath);
*/
	NSLog(@"Converted %d/%d images.", totalConversions, argc-1);
    [pool drain];
    return 0;
}

