/*
 *  ImageOperations.h
 *  PNGPOTimizer
 *
 *  Created by CJ Hanson on 3/19/10.
 *  Copyright 2010 Hanson Interactive. All rights reserved.
 *
 */

int padImageFilePOT(NSString *filePath);

// NSNotification name to tell the Window controller an image file as found
extern NSString *POTImageDidFinishNotification;

@interface POTImageOperation : NSOperation
{
	NSString *loadPath;
}

- (id)initWithPath:(NSString *)path;
@end