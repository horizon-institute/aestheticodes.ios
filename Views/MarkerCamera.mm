//
//  ACCamera.mm
//  aestheticodes
//
//  Created by Kevin Glover on 09/06/2014.
//  Copyright (c) 2014 horizon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Marker.h"
#import "MarkerCamera.h"
#import "MarkerFoundDelegate.h"
#import "MarkerSettings.h"
#import <UIKit/UIKit.h>
#include <vector>
#include <opencv2/opencv.hpp>

#define DEGREES_RADIANS(angle) ((angle) / 180.0 * M_PI)

static int BRANCH_INVALID = -1;
static int BRANCH_EMPTY = 0;

@protocol CvVideoCameraDelegateMod <CvVideoCameraDelegate>
@end

@interface CvVideoCameraMod : CvVideoCamera

- (void)updateOrientation;
- (void)layoutPreviewLayer;

@end

@implementation CvVideoCameraMod

- (void)updateOrientation;
{
	self->customPreviewLayer.bounds = CGRectMake(0, 0, self.parentView.frame.size.width, self.parentView.frame.size.height);
	[self layoutPreviewLayer];
}

- (void)layoutPreviewLayer;
{
	if (self.parentView != nil)
	{
		CALayer* layer = self->customPreviewLayer;
		CGRect bounds = self->customPreviewLayer.bounds;
		int rotation_angle = 0;
		
		switch (defaultAVCaptureVideoOrientation) {
			case AVCaptureVideoOrientationLandscapeRight:
				rotation_angle = 180;
				break;
			case AVCaptureVideoOrientationPortraitUpsideDown:
				rotation_angle = 270;
				break;
			case AVCaptureVideoOrientationPortrait:
				rotation_angle = 0;
			case AVCaptureVideoOrientationLandscapeLeft:
				break;
			default:
				break;
		}
		
		layer.position = CGPointMake(self.parentView.frame.size.width/2., self.parentView.frame.size.height/2.);
		layer.affineTransform = CGAffineTransformMakeRotation( DEGREES_RADIANS(rotation_angle) );
		layer.bounds = bounds;
	}
}
@end

@interface MarkerCamera()
@property (nonatomic, retain) CvVideoCamera* videoCamera;
@property (nonatomic) bool rearCamera;
@property (nonatomic) cv::Rect markerRect;
@property (nonatomic) cv::Mat markerImage;
@property (nonatomic) cv::Mat outputImage;
@property bool detecting;
@end

@implementation MarkerCamera : NSObject

-(id)init
{
	self = [super init];
	if (self)
	{
		self.rearCamera = true;
		self.detecting = false;
	}
	return self;
}

- (void) start:(UIImageView*)imageView
{
	if(self.videoCamera == NULL)
	{
		self.videoCamera = [[CvVideoCameraMod alloc] initWithParentView:imageView];
		self.videoCamera.delegate = self;
		if(self.rearCamera)
		{
			self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
		}
		else
		{
			self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
		}
		self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetiFrame960x540;
		self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
		self.videoCamera.defaultFPS = 20;
		self.videoCamera.grayscaleMode = NO;
		self.videoCamera.rotateVideo = false;
		
		[self.videoCamera unlockFocus];
	}
	else
	{
		[self stop];
	}

	[self.videoCamera start];
}

- (void) flip:(UIImageView*)imageView
{
	[self stop];
	self.rearCamera = !self.rearCamera;
	self.videoCamera = nil;
	[self start:imageView];
}

- (void) stop
{
	self.detecting = false;
	if(self.videoCamera.running)
	{
		[self.videoCamera stop];
	}
}

#pragma mark - Protocol CvVideoCameraDelegate
- (void)processImage:(cv::Mat&)image
{
	if(!self.detecting)
	{
		self.markerRect = [self calculateMarkerImageSegmentArea:image];
		self.markerImage = cv::Mat(self.markerRect.width, self.markerRect.height, CV_8UC1);
		self.outputImage = cv::Mat(self.markerRect.width, self.markerRect.height, CV_8UC4);
		self.outputImage.setTo(cv::Scalar(0, 0, 0, 0));
	
		self.detecting = true;
		
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			while(self.detecting)
			{
				//apply threshold.
				cv::Mat image = self.markerImage.clone();
				adaptiveThreshold(image, image, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY, 91, 2);
				
				//find contours
				cv::vector<cv::vector<cv::Point>> contours;
				cv::vector<cv::Vec4i> hierarchy;
				cv::findContours(image, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE);
				
				//detect markers
				NSDictionary* markers = [self findMarkers:hierarchy andImageContour:contours];
				if([self.mode isEqualToString:@"outline"])
				{
					self.outputImage.setTo(cv::Scalar(0, 0, 0, 0));
					[self drawMarkerContours:markers forImage:self.outputImage withContours:contours andHierarchy:hierarchy];
				}
				else if([self.mode isEqualToString:@"threshold"])
				{
					cvtColor(image, self.outputImage, CV_GRAY2BGRA);
					//self.markerImage.copyTo(self.outputImage);
				}
				else
				{
					self.outputImage.setTo(cv::Scalar(0, 0, 0, 0));
					if(self.markerDelegate != nil)
					{
						[self.markerDelegate markersFound:markers];
					}
				}
				
				image.release();
				sleep(0.5);
			}
		});
	}
	
	//select image segement to be processed for marker detection.
	cv::Mat temp(image, self.markerRect);
	
	cvtColor(temp, self.markerImage, CV_BGRA2GRAY);
	
	for (int y = 0; y < self.outputImage.rows; y++)
	{
		cv::Vec4b* src_pixel = temp.ptr<cv::Vec4b>(y);
		const cv::Vec4b* ovl_pixel = self.outputImage.ptr<cv::Vec4b>(y);
		for (int x = 0; x < self.outputImage.cols; x++, ++src_pixel, ++ovl_pixel)
		{
			double alpha = (*ovl_pixel).val[3] / 255.0;
			for (int c = 0; c < 3; c++)
			{
				(*src_pixel).val[c] = (uchar) ((*ovl_pixel).val[c] * alpha + (*src_pixel).val[c] * (1.0 -alpha));
			}
		}
	}

	
//	temp += self.outputImage;
}

-(void)drawMarkerContours:(NSDictionary*)markers forImage:(cv::Mat)image withContours:(cv::vector<cv::vector<cv::Point>>)contours andHierarchy:(cv::vector<cv::Vec4i>)hierarchy
{
	//color to draw contours
	cv::Scalar markerColor = cv::Scalar(0, 255, 255, 255);
	cv::Scalar outlineColor = cv::Scalar(0, 0, 0, 255);
	
	cv::Rect rect = [self calculateMarkerImageSegmentArea:image];
	
	for (NSString *markerCode in markers)
	{
		Marker* marker = [markers objectForKey:markerCode];
		for (NSNumber *nodeIndex in marker.nodeIndexes)
		{
			cv::drawContours(image, contours, (int)[nodeIndex integerValue], outlineColor, 3, 8, hierarchy, 0, cv::Point(rect.x, rect.y));
			cv::drawContours(image, contours, (int)[nodeIndex integerValue], markerColor, 2, 8, hierarchy, 0, cv::Point(rect.x, rect.y));
		}
	}

	for(NSString *markerCode in markers)
	{
		Marker* marker = [markers objectForKey:markerCode];
		for (NSNumber *nodeIndex in marker.nodeIndexes)
		{
			cv::Rect markerBounds = boundingRect(contours[nodeIndex.integerValue]);
			markerBounds.x = markerBounds.x + rect.x;
			markerBounds.y = markerBounds.y + rect.y;

			cv::putText(image, markerCode.fileSystemRepresentation, markerBounds.tl(), cv::FONT_HERSHEY_SIMPLEX, 0.5, outlineColor, 3);
			cv::putText(image, markerCode.fileSystemRepresentation, markerBounds.tl(), cv::FONT_HERSHEY_SIMPLEX, 0.5, markerColor, 2);
		}
	}
}

//calculate region in the image which is used for marker detection.
-(cv::Rect) calculateMarkerImageSegmentArea:(cv::Mat&)image
{
	int width = image.cols;
	int height = image.rows;
	
	int size = MIN(width, height);
	
	int x = (width - size) / 2;
	int y = (height - size) / 2;
	
	return cv::Rect(x, y, size, size);
}

-(void)displayRectOnImage:(cv::Mat)image withColor:(cv::Scalar)color
{
	cv::Rect rect = [self calculateMarkerImageSegmentArea:image];
	
	int width = image.cols;
	int height = image.rows;
	
	cv::rectangle(image, cv::Point(0,0), cv::Point(width, rect.y), color, CV_FILLED);
	cv::rectangle(image, cv::Point(0, rect.y), cv::Point(rect.x, rect.y + rect.height), color, CV_FILLED);
	cv::rectangle(image, cv::Point(rect.x + rect.width, rect.y), cv::Point(width, rect.y + rect.height), color, CV_FILLED);
	cv::rectangle(image, cv::Point(0,rect.y + rect.height), cv::Point(width, height), color, CV_FILLED);
}

const int CHILD_NODE_INDEX = 2;
const int NEXT_SIBLING_NODE_INDEX = 0;


-(NSDictionary*)findMarkers:(cv::vector<cv::Vec4i>)hierarchy andImageContour:(cv::vector<cv::vector<cv::Point>>)contours
{
	NSMutableDictionary* markers = [NSMutableDictionary dictionary];
	for (int i = 0; i < contours.size(); i++)
	{
		NSArray* markerCode = [self createMarkerForNode:i imageHierarchy:hierarchy];
		NSString* markerKey = [Marker getCodeKey:markerCode];
		if (markerKey != nil)
		{
			//if code is already detected.
			Marker *marker = [markers objectForKey:markerKey];
			if (marker != nil)
			{
				[marker.nodeIndexes addObject:[[NSNumber alloc] initWithInt:i]];
			}
			else
			{
				marker = [[Marker alloc] initWithCode:markerCode andKey:markerKey];
				[marker.nodeIndexes addObject:[[NSNumber alloc] initWithInt:i]];
				[markers setObject:marker forKey:marker.codeKey];
			}
		}
	}
	return markers;
}


-(NSArray*)createMarkerForNode:(int)nodeIndex imageHierarchy:(cv::vector<cv::Vec4i>)imageHierarchy
{
	int currentBranchIndex;
	int numOfBranches = 0;
	int numOfEmptyBranches = 0;
	
	NSMutableArray* markerCode = [[NSMutableArray alloc] init];
	
	//get the nodes of the root node.
	cv::Vec4i nodes = imageHierarchy.at(nodeIndex);
	//get the first child node.
	currentBranchIndex = nodes[CHILD_NODE_INDEX];
	//if there is a branch node then verify branches.
	if (currentBranchIndex >= 0)
	{
		//loop until there is a branch node.
		while (currentBranchIndex >= 0)
		{
			int regionCode = [self getCodeForNodeIndex:currentBranchIndex imageHierarchy:imageHierarchy];
			if (regionCode == BRANCH_EMPTY)
			{
				numOfEmptyBranches++;
				if(numOfEmptyBranches > [MarkerSettings settings].maxEmptyRegions)
				{
					return nil;
				}
			}
			
			if (regionCode != BRANCH_INVALID)
			{
				[markerCode addObject:[[NSNumber alloc] initWithInt:regionCode]];
				numOfBranches++;
				nodes = imageHierarchy.at(currentBranchIndex);
				currentBranchIndex = nodes[NEXT_SIBLING_NODE_INDEX];
				if(numOfBranches > [MarkerSettings settings].maxRegions)
				{
					return nil;
				}
			}
			else
			{
				break;
			}
		}
	}
	if ([[MarkerSettings settings] isValid:markerCode])
	{
		return [markerCode sortedArrayUsingSelector: @selector(compare:)];
	}
	return nil;
}

-(int)getCodeForNodeIndex:(int)branchNodeIndex imageHierarchy:(cv::vector<cv::Vec4i>)imageHierarchy
{
	int currentLeafIndex;
	int leafCount = 0;
	
	cv::Vec4i nodes = imageHierarchy.at(branchNodeIndex);
	currentLeafIndex = nodes[CHILD_NODE_INDEX];
	//if there is a leaf node
	if (currentLeafIndex >= 0)
	{
		while (currentLeafIndex >= 0)
		{
			if ([self isValidLeaf:currentLeafIndex imageHierarchy:imageHierarchy])
			{
				leafCount++;
				nodes = imageHierarchy.at(currentLeafIndex);
				//get sibling of the leaf node.
				currentLeafIndex = nodes[NEXT_SIBLING_NODE_INDEX];
			}
			else
			{
				leafCount = -1;
				break;
			}
		}
	}
	
	return leafCount;
}

-(bool)isValidLeaf:(int)leafNodeIndex imageHierarchy:(cv::vector<cv::Vec4i>)imageHierarchy
{
	cv::Vec4i nodes = imageHierarchy.at(leafNodeIndex);
	//if leaf has child node
	return nodes[CHILD_NODE_INDEX] < 0;
}

@end