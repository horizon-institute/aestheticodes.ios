//
//  MarkerDetector.m
//  Artcodes
//
//  Created by Kevin Glover on 20 Oct 2015.
//  Copyright © 2015 Horizon DER Institute. All rights reserved.
//

#import "MarkerDetector.h"
#import <vector>
#import <opencv2/opencv.hpp>
#import <UIKit/UIKit.h>
#import <artcodesScanner/artcodesScanner-Swift.h>

@interface MarkerDetector()

@property DetectionSettings* settings;

@end

const static int CHILD_NODE_INDEX = 2;
const static int NEXT_SIBLING_NODE_INDEX = 0;

@implementation MarkerDetector

- (id)initWithSettings:(DetectionSettings*)settings
{
	if (self = [super init])
	{
		self.settings = settings;
		return self;
	}
	return nil;
}

-(cv::Mat) process:(cv::Mat) image withOverlay:(cv::Mat) overlay
{
	std::vector<std::vector<cv::Point> > contours;
	std::vector<cv::Vec4i> hierarchy;
	cv::findContours(image, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);

	// This autoreleasepool prevents memory allocated in [self findMarkers] from leaking.
	@autoreleasepool {
		//detect markers
		NSArray* markers = [self findMarkers:hierarchy andImageContour:contours andOverlay:overlay];
		
		self.settings.detected = markers.count > 0;
		if(self.settings.handler != nil)
		{
			self.settings.handler(markers);
		}
	}

	return image;
}

-(NSArray*)findMarkers:(std::vector<cv::Vec4i>)hierarchy andImageContour:(std::vector<std::vector<cv::Point> >)contours andOverlay:(cv::Mat) overlay
{
	/*! Detected markers */
	NSMutableArray* markers = [[NSMutableArray alloc] init];
	//int skippedContours = 0;
	
	//NSLog(@"Contours %lu", contours.size());
	for (int i = 0; i < contours.size(); i++)
	{
		//if (contours[i].size() < self.cameraSettings.minimumContourSize)
		//{
		//	++skippedContours;
		//	continue;
		//}
		
		Marker* marker = [self createMarkerForNode:i imageHierarchy:hierarchy];
		if (marker != nil)
		{
			NSString* markerKey = [self getCodeKey:marker];
			if([self.settings.validCodes containsObject:markerKey])
			{
				[markers addObject: markerKey];
				
				[self drawMarker:markerKey atIndex:i onOverlay:overlay withContours:contours andHierarchy:hierarchy];
			}
		}
	}
	
	//NSLog(@"Skipped contours: %d/%lu",skippedContours,contours.size());
	return markers;
}

-(NSString*)getCodeKey:(Marker*)marker
{
	NSMutableString* codeStr = [[NSMutableString alloc] init];
	
	for (int i = 0; i < marker.regions.count; i++)
	{
		if(i != 0)
		{
			[codeStr appendString:@":"];
		}
		[codeStr appendFormat:@"%ld", (long)[marker.regions objectAtIndex:i].value];
	}
	
	return codeStr;
}

-(Marker*)createMarkerForNode:(int)nodeIndex imageHierarchy:(std::vector<cv::Vec4i>)imageHierarchy
{
	NSMutableArray* regions = nil;
	
	// Loop through the regions, verifing the value of each:
	for (int currentRegionIndex = imageHierarchy.at(nodeIndex)[CHILD_NODE_INDEX]; currentRegionIndex >= 0; currentRegionIndex = imageHierarchy.at(currentRegionIndex)[NEXT_SIBLING_NODE_INDEX])
	{
		MarkerRegion* region = [self createRegionForNode:currentRegionIndex inImageHierarchy:imageHierarchy];
		if(region != nil)
		{
			if(regions == nil)
			{
				regions = [[NSMutableArray alloc] init];
			}
			else if(regions.count >= self.settings.maxRegions)
			{
				// Too many regions.
				return nil;
			}
			[regions addObject:region];
		}
	}

	[self sortRegions:regions];
	if([self isValidRegionList:regions])
	{
		return [[Marker alloc] initWithIndex:nodeIndex regions:regions];
	}
	return nil;
}

-(void)sortRegions:(NSMutableArray*) regions
{
	[regions sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"value" ascending:YES]]];
}

-(BOOL)isValidRegionList:(NSArray*) regions
{
	if (regions == nil)
	{
		// No Code
		return false;
	}
	else if (regions.count < self.settings.minRegions)
	{
		// Too Short
		return false;
	}
	else if (regions.count > self.settings.maxRegions)
	{
		 // Too long
		return false;
	}
	
	for (MarkerRegion* region in regions)
	{
		//check if leaves are using in accepted range.
		if (region.value > self.settings.maxRegionValue)
		{
			return false; // value is too Big
		}
	}
	
	return [self hasValidChecksum:regions];
}

-(BOOL)hasValidChecksum:(NSArray*) regions
{
	if (self.settings.checksum <= 1)
	{
		return true;
	}
	int numberOfLeaves = 0;
	for (MarkerRegion* region in regions)
	{
		numberOfLeaves += region.value;
	}
	return (numberOfLeaves % self.settings.checksum) == 0;
}

-(MarkerRegion*)createRegionForNode:(int)regionIndex inImageHierarchy:(std::vector<cv::Vec4i>)imageHierarchy
{
	// Find the first dot index:
	cv::Vec4i nodes = imageHierarchy.at(regionIndex);
	int currentDotIndex = nodes[CHILD_NODE_INDEX];
	if (currentDotIndex < 0)
	{
		// There are no dots.
		return nil;
	}
	
	// Count all the dots and check if they are leaf nodes in the hierarchy:
	int dotCount = 0;
	while (currentDotIndex >= 0)
	{
		if ([self isValidLeaf:currentDotIndex inImageHierarchy:imageHierarchy])
		{
			dotCount++;
			// Get the next dot index:
			nodes = imageHierarchy.at(currentDotIndex);
			currentDotIndex = nodes[NEXT_SIBLING_NODE_INDEX];
			
			if (dotCount > self.settings.maxRegionValue)
			{
				// Too many dots
				return nil;
			}
		}
		else
		{
			// Not a leaf
			return nil;
		}
	}
	
	return [[MarkerRegion alloc] initWithIndex:regionIndex value:dotCount];
}

-(bool)isValidLeaf:(int)nodeIndex inImageHierarchy:(std::vector<cv::Vec4i>)imageHierarchy
{
	cv::Vec4i nodes = imageHierarchy.at(nodeIndex);
	return nodes[CHILD_NODE_INDEX] < 0;
}

-(void)drawMarker:(NSString*)marker atIndex:(int)index onOverlay:(cv::Mat) overlay withContours:(std::vector<std::vector<cv::Point>>)contours andHierarchy:(std::vector<cv::Vec4i>)hierarchy
{
	//color to draw contours
	cv::Scalar markerColor = cv::Scalar(0, 255, 255, 255);
	cv::Scalar regionColor = cv::Scalar(0, 128, 255, 255);
	cv::Scalar outlineColor = cv::Scalar(0, 0, 0, 255);
	
	if(self.settings.displayOutline > 0)
	{
		cv::Vec4i nodes = hierarchy.at(index);
		int currentRegionIndex= nodes[CHILD_NODE_INDEX];
		// Loop through the regions, verifing the value of each:
		if(self.settings.displayOutline == 2)
		{
			while (currentRegionIndex >= 0)
			{
				cv::drawContours(overlay, contours, currentRegionIndex, outlineColor, 3, 8, hierarchy, 0, cv::Point(0, 0));
				cv::drawContours(overlay, contours, currentRegionIndex, regionColor, 2, 8, hierarchy, 0, cv::Point(0, 0));
				
				// Get next region:
				nodes = hierarchy.at(currentRegionIndex);
				currentRegionIndex = nodes[NEXT_SIBLING_NODE_INDEX];
			}
		}
		
		cv::drawContours(overlay, contours, index, outlineColor, 3, 8, hierarchy, 0, cv::Point(0, 0));
		cv::drawContours(overlay, contours, index, markerColor, 2, 8, hierarchy, 0, cv::Point(0, 0));
	}
	
	// draw code:
	if(self.settings.displayText == 1)
	{
		cv::Rect markerBounds = boundingRect(contours[index]);
		markerBounds.x = markerBounds.x;
		markerBounds.y = markerBounds.y;
		
		cv::putText(overlay, marker.fileSystemRepresentation, markerBounds.tl(), cv::FONT_HERSHEY_SIMPLEX, 0.5, outlineColor, 3);
		cv::putText(overlay, marker.fileSystemRepresentation, markerBounds.tl(), cv::FONT_HERSHEY_SIMPLEX, 0.5, markerColor, 2);
	}
}

@end
