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

int padImageFilePOT(NSString *filePath)
{		
	if([[filePath lastPathComponent] isEqualToString:@"Default.png"]){
		NSLog(@"Skipping Default.png");
		return 0;
	}
	if([[filePath lastPathComponent] isEqualToString:@"Icon-Home.png"]){
		NSLog(@"Skipping Icon-Home.png");
		return 0;
	}
	if([[filePath lastPathComponent] isEqualToString:@"Icon-Small.png"]){
		NSLog(@"Skipping Icon-Small.png");
		return 0;
	}
	
	NSBitmapImageRep *inputBitmapImageRep	= BitmapImageRepFromNSImage([[[NSImage alloc] initWithContentsOfFile:filePath] autorelease]);
	CIImage *image							= [[[CIImage alloc] initWithBitmapImageRep:inputBitmapImageRep] autorelease];
	if(!image){
		NSLog(@"Failed to load image %@", filePath);
		return 0;
	}
	
	NSBitmapImageRep *outputBitmapImageRep	= outputBitmapImageRepFromCIImage(image);
	if(!outputBitmapImageRep){
		NSLog(@"Didn't expand image size %@", filePath);
		return 0;
	}
		
	NSData *outputData					= [outputBitmapImageRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSImageInterlaced, nil]];
	
	if(![outputData writeToFile:filePath atomically:YES]){
		NSLog(@"Failed to write image %@", filePath);
		return 0;
	}
	
	return 1;
}

@implementation POTImageOperation

// NSNotification name to tell the Window controller an image file as found
NSString *POTImageDidFinishNotification = @"POTImageDidFinishNotification";

// -------------------------------------------------------------------------------
//	initWithPath:path
// -------------------------------------------------------------------------------
- (id)initWithPath:(NSString *)path
{
	self = [super init];
    loadPath = [path retain];
    return self;
}

// -------------------------------------------------------------------------------
//	dealloc:
// -------------------------------------------------------------------------------
- (void)dealloc
{
    [loadPath release];
    [super dealloc];
}

// -------------------------------------------------------------------------------
//	isImageFile:filePath
//
//	Uses LaunchServices and UTIs to detect if a given file path is an image file.
// -------------------------------------------------------------------------------
- (BOOL)isImageFile:(NSString *)filePath
{
    BOOL isImageFile = NO;
    FSRef fileRef;
    Boolean isDirectory;
	
    if (FSPathMakeRef((const UInt8 *)[filePath fileSystemRepresentation], &fileRef, &isDirectory) == noErr)
    {
        // get the content type (UTI) of this file
        CFDictionaryRef values = NULL;
        CFStringRef attrs[1] = { kLSItemContentType };
        CFArrayRef attrNames = CFArrayCreate(NULL, (const void **)attrs, 1, NULL);
		
        if (LSCopyItemAttributes(&fileRef, kLSRolesViewer, attrNames, &values) == noErr)
        {
            // verify that this is a file that the Image I/O framework supports
            if (values != NULL)
            {
                CFTypeRef uti = CFDictionaryGetValue(values, kLSItemContentType);
                if (uti != NULL)
                {
                    CFArrayRef supportedTypes = CGImageSourceCopyTypeIdentifiers();
                    CFIndex i, typeCount = CFArrayGetCount(supportedTypes);
					
                    for (i = 0; i < typeCount; i++)
                    {
                        CFStringRef supportedUTI = CFArrayGetValueAtIndex(supportedTypes, i);
						
                        // make sure the supported UTI conforms only to "public.image" (this will skip PDF)
                        if (UTTypeConformsTo(supportedUTI, CFSTR("public.image")))
                        {
                            if (UTTypeConformsTo(uti, supportedUTI))
                            {
                                isImageFile = YES;
                                break;
                            }
                        }
                    }
					
                    CFRelease(supportedTypes);
                }
				
                CFRelease(values);
            }
        }
		
        CFRelease(attrNames);
    }
	
    return isImageFile;
}

// -------------------------------------------------------------------------------
//	main:
//
//	Examine the given file (from the NSURL "loadURL") to see it its an image file.
//	If an image file examine further and report its file attributes.
//
//	We could use NSFileManager, but to be on the safe side we will use the
//	File Manager APIs to get the file attributes.
// -------------------------------------------------------------------------------
-(void)main
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if (![self isCancelled])
	{
		// test to see if it's an image file
		if ([self isImageFile: loadPath])
		{
			// in this example, we just get the file's info (mod date, file size) and report it to the table view
			//
			FSRef ref;
			Boolean isDirectory;
			if (FSPathMakeRef((const UInt8 *)[loadPath fileSystemRepresentation], &ref, &isDirectory) == noErr)
			{
				FSCatalogInfo catInfo;
				if (FSGetCatalogInfo(&ref, (kFSCatInfoContentMod | kFSCatInfoDataSizes), &catInfo, nil, nil, nil) == noErr)
				{
					CFAbsoluteTime cfTime;
					if (UCConvertUTCDateTimeToCFAbsoluteTime(&catInfo.contentModDate, &cfTime) == noErr)
					{
						CFDateRef dateRef = nil;
						dateRef = CFDateCreate(kCFAllocatorDefault, cfTime);
						if (dateRef != nil)
						{
							if (![self isCancelled])
							{
								NSDateFormatter* formatter = [[[NSDateFormatter alloc] init] autorelease];
								[formatter setTimeStyle:NSDateFormatterNoStyle];
								[formatter setDateStyle:NSDateFormatterShortStyle];
								
								NSString *modDateStr = [formatter stringFromDate:(NSDate*)dateRef];
								
								NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
													  [loadPath lastPathComponent], @"name",
													  [loadPath stringByDeletingLastPathComponent], @"path",
													  modDateStr, @"modified",
													  [NSString stringWithFormat:@"%ld", catInfo.dataPhysicalSize], @"size",
													  [NSNumber numberWithInt:padImageFilePOT(loadPath)], @"result",
													  nil];
								
								NSLog(@"Image processed: %@ %d", [info objectForKey:@"name"], [[info objectForKey:@"result"] intValue]);
							}
							
							CFRelease(dateRef);
						}
					}
				}		
			}
		}
	}
	
	[pool release];
}

@end
