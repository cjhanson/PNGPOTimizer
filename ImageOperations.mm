/*
 *  ImageOperations.mm
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

#include "ImageOperations.h"
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

#import "CCZFormatHeader.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <zlib.h>
#include <architecture/byte_order.h>

#import "PVRTexLib.h"
using namespace pvrtexlib;

#define REMOTE_TMP_FILE 1

static int SaveBitmapImageToPVR(NSBitmapImageRep *bitmapImage, NSString *outPath)
{
	PVRTRY {
		uint width = bitmapImage.size.width;
		uint height = bitmapImage.size.height;
		unsigned char *pPixelData = bitmapImage.bitmapData;
		
		// get the utilities instance
		PVRTextureUtilities *PVRU = PVRTextureUtilities::getPointer();
		// make a CPVRTexture instance with data passed
		CPVRTexture sOriginalTexture(
									 width,		// u32Width
									 height,	// u32Height
									 0,			// u32MipMapCount 
									 1,			// u32NumSurfaces 
									 false,		// bBorder
									 false,		// bTwiddled 
									 false,		// bCubeMap
									 false,		// bVolume
									 false,		// bFalseMips
									 true,		// bHasAlpha
									 false,		// bVerticallyFlipped
									 eInt8StandardPixelType,	// ePixelType
									 0.0f,		// fNormalMap,
									 pPixelData	// pPixelData
									 );
		// make an empty header for the destination of the preprocessing
		// copying the existing texture header settings
		CPVRTextureHeader sProcessHeader(sOriginalTexture.getHeader());
		PVRU->ProcessRawPVR(
							sOriginalTexture,//sInputTexture
							sProcessHeader,	//sProcessHeader
							false,			//bDoBleeding
							0.0f,			//fBleedRed
							0.0f,			//fBleedGreen
							0.0f,			//fBleedBlue
							true,			//bPremultAlpha
							eRESIZE_BICUBIC	//eResizeMode
							);
		
		// create texture to encode to
		CPVRTexture sCompressedTexture(sOriginalTexture.getHeader());
		sCompressedTexture.setPixelType(OGL_BGRA_8888);
		
		PVRU->CompressPVR(sOriginalTexture,sCompressedTexture);
		
		// write to file specified (second param is version. Current is 2.)
		size_t writeResult = sCompressedTexture.writeToFile([[NSFileManager defaultManager] fileSystemRepresentationWithPath:outPath]);
		NSLog(@"PVR wrote %d bytes to %@", writeResult, [outPath lastPathComponent]);
		
		return 1;
	} PVRCATCH(myException) {
		// handle any exceptions here
		printf("Exception in example 2: %s\n",myException.what());
		
		return -1;
	}
}

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
	NSArray *filesToSkip = [NSArray arrayWithObjects:
							@"iTunesArtwork",
							@"Default.png",
							@"Icon.png",
							@"Icon@2x.png",
							@"Icon-Small.png",
							@"Icon-Small@2x.png",
							@"Icon-Small-50.png",
							@"Icon-72.png",
						nil];
	NSString *fileName	= [filePath lastPathComponent];
	for(NSString *skipName in filesToSkip){
		if([skipName isEqualToString:fileName]){
			NSLog(@"Skipping %@", fileName);
			return 0;
		}
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
	
	NSString *pvrPath	= [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pvr"];
	int result = SaveBitmapImageToPVR(outputBitmapImageRep, pvrPath);
	if(result < 1){
		NSLog(@"Failed to save PVR %@", pvrPath);
		return 0;
	}
	
	NSData *data			= [[NSData alloc] initWithContentsOfFile:pvrPath];
#if REMOTE_TMP_FILE	
	//remove pvr temp file	
	NSError *saveError;
	if(![[NSFileManager defaultManager] removeItemAtPath:pvrPath error:&saveError])
	{
		NSLog(@"Failed to cleanup temp pvr: %@", pvrPath);
	}
#endif
	
	if(data){
		const unsigned char *d = (const unsigned char *)[data bytes];   
		if(!d){
			NSLog(@"Failed to load PVR data");
			[data release];
			data = nil;
		}
		
		struct CCZHeader *header;
		uint32 headerSize	= sizeof(*header);
		NSLog(@"Header size %d", headerSize);
		
		uLongf sourceLen	= [data length];
		uLongf destLen		= compressBound(sourceLen);
		
		NSMutableData *compressed = [[NSMutableData alloc] initWithLength:destLen + headerSize];
		if(!compressed){
			NSLog(@"Failed to allocate memory for compressed data");
			[data release];
			data = nil;
		}
		
		Bytef *md = (Bytef *)[compressed mutableBytes];
		md += headerSize;
		
		if(Z_OK != compress2(md, &destLen, d, sourceLen, Z_BEST_COMPRESSION)){
			NSLog(@"Failed to allocate memory for compressed data");
			[compressed release];
			compressed = nil;
			[data release];
			data = nil;
		}
		
		md -= headerSize;
		
		NSLog(@"Compressed size w/o header %d, full orig %d, Temp byte size %d", destLen, sourceLen, [compressed length]);
		
		compressed.length = destLen+headerSize;
		
		header = (struct CCZHeader*) md;
		header->sig[0] = 'C';
		header->sig[1] = 'C';
		header->sig[2] = 'Z';
		header->sig[3] = '!';
#if DEBUG		
		char c[5];
		c[0]	= header->sig[0];
		c[1]	= header->sig[1];
		c[2]	= header->sig[2];
		c[3]	= header->sig[3];
		c[4]	= '\0';
		
		if(header->sig[0] != 'C' || header->sig[1] != 'C' || header->sig[2] != 'Z' || header->sig[3] != '!'){
			NSLog(@"cocos2d: Invalid CCZ file");
		}else{
			NSLog(@"CCZ Header: %@", [NSString stringWithCString:c encoding:NSASCIIStringEncoding]);
		}
#endif	
		uint32_t myFlags			= 0;
		myFlags						|= 0x1;//First flag means should parse flag
		myFlags						|= 0x2;//Second flag means alpha premultiplied
		header->len					= OSSwapHostToBigInt32(sourceLen);
		header->version				= OSSwapHostToBigInt16(2);
		header->compression_type	= OSSwapHostToBigInt16(CCZ_COMPRESSION_ZLIB);
		header->reserved			= OSSwapHostToBigInt32(myFlags);
		
		[data release];
		data = compressed;
		compressed = nil;
	}
	
	//Save PNG
	//NSData *data					= [[outputBitmapImageRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], NSImageInterlaced, nil]] retain];
	
	NSString *cczPath	= [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pvr.ccz"];
	if(![data writeToFile:cczPath atomically:YES]){
		NSLog(@"Failed to write output image %@", cczPath);
		[data release];
		return 0;
	}
	
	[data release];
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
                CFTypeRef uti = (CFStringRef)CFDictionaryGetValue(values, kLSItemContentType);
                if (uti != NULL)
                {
                    CFArrayRef supportedTypes = CGImageSourceCopyTypeIdentifiers();
                    CFIndex i, typeCount = CFArrayGetCount(supportedTypes);
					
                    for (i = 0; i < typeCount; i++)
                    {
                        CFStringRef supportedUTI = (CFStringRef)CFArrayGetValueAtIndex(supportedTypes, i);
						
                        // make sure the supported UTI conforms only to "public.image" (this will skip PDF)
                        if (UTTypeConformsTo(supportedUTI, CFSTR("public.image")))
                        {
                            if (UTTypeConformsTo((CFStringRef)uti, supportedUTI))
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
								
								NSLog(@"Image processed: %@ result: %d", [info objectForKey:@"name"], [[info objectForKey:@"result"] intValue]);
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
