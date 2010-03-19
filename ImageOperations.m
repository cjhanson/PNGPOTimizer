/*
 *  ImageOperations.c
 *  PNGPOTimizer
 *
 *  Created by CJ Hanson on 3/19/10.
 *  Copyright 2010 Hanson Interactive. All rights reserved.
 *
 */

#include "ImageOperations.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

static NSBitmapImageRep *BitmapImageRepFromNSImage(NSImage *nsImage);

static unsigned int nextPOT(unsigned int x)
{
	if(x < 3)return 2;
    x = x - 1;
    x = x | (x >> 1);
    x = x | (x >> 2);
    x = x | (x >> 4);
    x = x | (x >> 8);
    x = x | (x >>16);
    return x + 1;
}

static NSBitmapImageRep *BitmapImageRepFromNSImage(NSImage *nsImage) {
    // See if the NSImage has an NSBitmapImageRep.  If so, return the first NSBitmapImageRep encountered.  An NSImage that is initialized by loading the contents of a bitmap image file (such as JPEG, TIFF, or PNG) and, not subsequently rescaled, will usually have a single NSBitmapImageRep.
    NSEnumerator *enumerator = [[nsImage representations] objectEnumerator];
    NSImageRep *representation;
    while (representation = [enumerator nextObject]) {
        if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
            return (NSBitmapImageRep *)representation;
        }
    }
	
    // If we didn't find an NSBitmapImageRep (perhaps because we received a PDF image), we can create one using one of two approaches: (1) lock focus on the NSImage, and create the bitmap using -[NSBitmapImageRep initWithFocusedViewRect:], or (2) (Tiger and later) create an NSBitmapImageRep, and an NSGraphicsContext that draws into it using +[NSGraphicsContext graphicsContextWithBitmapImageRep:], and composite the NSImage into the bitmap graphics context.  We'll use approach (1) here, since it is simple and supported on all versions of Mac OS X.
    NSSize size = [nsImage size];
    [nsImage lockFocus];
    NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, size.width, size.height)];
    [nsImage unlockFocus];
	
    return [bitmapImageRep autorelease];
}

NSBitmapImageRep *outputBitmapImageRepFromCIImage(CIImage *ciImage)
{
    NSBitmapImageRep *bitmapImageRep = nil;
	
    if (ciImage != nil) {
		
        // Get the CIImage's extents.  The filters we're using in this example should always produce an output image of finite extent, but in the general case one needs to account for the possibility of the output image being infinite in extent.
        CGRect extent = [ciImage extent];
        if (CGRectIsInfinite(extent)) {
            extent.size.width = 1024;
            extent.size.height = 1024;
            NSLog(@"Trimmed infinite rect to arbitrary finite rect");
        }
		
		unsigned int POTWide	= nextPOT(extent.size.width);
		unsigned int POTHigh	= nextPOT(extent.size.height);
		unsigned int imgWide	= extent.size.width;
		unsigned int imgHigh	= extent.size.height;
		
        // Compute size of output bitmap.
        NSSize outputBitmapSize = NSMakeSize(POTWide, POTHigh);
		
		if(outputBitmapSize.width == extent.size.width && outputBitmapSize.height == extent.size.height){
			NSLog(@"Bitmap already POT");
			return nil;
		}
		
        // Create a new NSBitmapImageRep that matches the CIImage's extents.
        bitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:outputBitmapSize.width pixelsHigh:outputBitmapSize.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
		
        // Create an NSGraphicsContext that draws into the NSBitmapImageRep, and make it current.
        NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapImageRep];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:nsContext];
		
        // Clear the bitmap to zero alpha.
        [[NSColor clearColor] set];
        NSRectFill(NSMakeRect(0, 0, [bitmapImageRep pixelsWide], [bitmapImageRep pixelsHigh]));
		
        // Decide where the image will go.
        CGRect imageDestinationRect = CGRectMake(0.0, [bitmapImageRep pixelsHigh] - extent.size.height, extent.size.width, extent.size.height);
		
        // Get a CIContext from the NSGraphicsContext, and use it to draw the CIImage into the NSBitmapImageRep.
        CIContext *ciContext = [nsContext CIContext];
        [ciContext drawImage:ciImage atPoint:imageDestinationRect.origin fromRect:extent];
		
		// Restore the previous NSGraphicsContext.
        [NSGraphicsContext restoreGraphicsState];
		
		//Fill the expanded area by repeating the edge pixel out to the new edge
		{
			int x, y;
			
			NSColor *fillColor;
			
			//fill right
			if(imgWide < POTWide){
				unsigned int startX = imgWide-1;
				for (y = 0, x = startX; y < imgHigh; y++, x = startX){
					fillColor = [bitmapImageRep colorAtX:x y:y];
					for (x; x < POTWide; x++){
						[bitmapImageRep setColor:fillColor atX:x y:y];
					}
				}
			}
			
			//fill down
			if(imgHigh < POTHigh){
				unsigned int startY = imgHigh-1;
				for (x = 0, y = startY; x < POTWide; x++, y=startY){
					fillColor = [bitmapImageRep colorAtX:x y:y];
					for (y; y < POTHigh; y++){
						[bitmapImageRep setColor:fillColor atX:x y:y];
					}
				}
			}
		}
    }
	
    // Return the new NSBitmapImageRep.
    return [bitmapImageRep autorelease];
}

int padImageFilePOT(const char *filePath)
{	
	NSString *filePathString				= [NSString stringWithCString:filePath encoding:NSUTF8StringEncoding];
	
	NSBitmapImageRep *inputBitmapImageRep	= BitmapImageRepFromNSImage([[[NSImage alloc] initWithContentsOfFile:filePathString] autorelease]);
	CIImage *image							= [[[CIImage alloc] initWithBitmapImageRep:inputBitmapImageRep] autorelease];
	if(!image){
		NSLog(@"Failed to load image %s", filePath);
		return 0;
	}
	
	NSBitmapImageRep *outputBitmapImageRep	= outputBitmapImageRepFromCIImage(image);
	if(!outputBitmapImageRep){
		NSLog(@"Didn't expand image size %s", filePath);
		return 0;
	}
		
	NSString *filePathDest				= filePathString;//[[[filePathString stringByDeletingPathExtension] stringByAppendingString:@"_POT"] stringByAppendingPathExtension:@"png"];

	NSData *outputData					= [outputBitmapImageRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSImageInterlaced, nil]];
	
	if(![outputData writeToFile:filePathDest atomically:YES]){
		NSLog(@"Failed to write image %s", filePath);
		return 0;
	}
	
	return 1;
}
