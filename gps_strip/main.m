//
//  main.m
//  gps_strip
//
//  Created by Peter Hosey on 2013-11-23.
//  Copyright (c) 2013 Peter Hosey. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sysexits.h>

static NSDictionary *dictMinusGPS(NSDictionary *dict);

int main(int argc, char **argv) {
	__block int status = EXIT_SUCCESS;

	@autoreleasepool {
		NSEnumerator *argsEnum = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
		[argsEnum nextObject];
		dispatch_group_t group = dispatch_group_create();
		for (NSString *inputPath in argsEnum) {
			dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				NSString *inputPathMinusExtension = [inputPath stringByDeletingPathExtension];
				NSString *extension = [inputPath pathExtension];
				NSString *outputPath = [[inputPathMinusExtension stringByAppendingString:@"-degeolocated"] stringByAppendingPathExtension:extension];

				NSURL *inputURL = [NSURL fileURLWithPath:inputPath isDirectory:NO];
				NSURL *outputURL = [NSURL fileURLWithPath:outputPath isDirectory:NO];

				CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)(inputURL), /*options*/ (__bridge CFDictionaryRef)(@{}));
				if (source == NULL) {
					status = EX_NOINPUT;
					NSLog(@"Couldn't create source for %@", inputPath);
					return;
				}
				size_t numImages = CGImageSourceGetCount(source);
				CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)(outputURL), CGImageSourceGetType(source), numImages, /*options*/ NULL);
				if (dest == NULL) {
					status = EX_CANTCREAT;
					NSLog(@"Couldn't create destination at %@", outputPath);
					return;
				}

				NSDictionary *props = dictMinusGPS(CFBridgingRelease(CGImageSourceCopyProperties(source, (__bridge CFDictionaryRef)(@{}))));
				CGImageDestinationSetProperties(dest, (__bridge CFDictionaryRef)(props));

				for (size_t i = 0U; i < numImages; ++i) {
					NSDictionary *imageProps = dictMinusGPS(CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, i, /*options*/ NULL)));
					CGImageDestinationAddImageFromSource(dest, source, i, (__bridge CFDictionaryRef)(imageProps));
				}

				CGImageDestinationFinalize(dest);
				CFRelease(dest);
				CFRelease(source);
			});
		}

		dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, 600.0 * NSEC_PER_SEC));
		dispatch_release(group);
	}

    return status;
}

static NSDictionary *dictMinusGPS(NSDictionary *dict) {
	NSMutableDictionary *m = [dict mutableCopy];
	m[(NSString *)kCGImagePropertyGPSDictionary] = [NSNull null];
	return m;
}
