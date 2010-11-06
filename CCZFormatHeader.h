/*
 Copyright (c) 2010 Andreas Loew / code-and-web.de
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
 associated documentation files (the "Software"), to deal in the Software without restriction, including without
 limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifndef __CCZ_FORMAT_H
#define __CCZ_FORMAT_H

// Format header
struct CCZHeader {
	uint8_t			sig[4];				// signature. Should be 'CCZ!' 4 bytes
	uint16_t		compression_type;	// See enums below
	uint16_t		version;			// should be 2
	uint32_t		reserved;			// Reserverd for users.
	uint32_t		len;				// size of the uncompressed file
};

enum {
	CCZ_COMPRESSION_ZLIB,			// zlib format.
	CCZ_COMPRESSION_BZIP2,			// bzip2 format
	CCZ_COMPRESSION_GZIP,			// gzip format
};

#endif //__CCZ_FORMAT_H
