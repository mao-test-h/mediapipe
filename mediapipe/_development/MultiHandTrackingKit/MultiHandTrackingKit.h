#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

//! Project version number for MultiHandTrackingKit.
FOUNDATION_EXPORT double MultiHandTrackingKitVersionNumber;

//! Project version string for MultiHandTrackingKit.
FOUNDATION_EXPORT const unsigned char MultiHandTrackingKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MultiHandTrackingKit/PublicHeader.h>

@class MultiHandTracker;

@protocol MultiHandTrackerDelegate <NSObject>

@required
- (void)multiHandTracker:(MultiHandTracker*)tracker
      didOutputLandmarks:(NSArray*)landmarks
           withHandCount:(int)handCount
       withLandmarkCount:(int)landmarkCount;

@optional
- (void)multiHandTracker:(MultiHandTracker*)tracker
    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end


@interface MultiHandTracker : NSObject

- (instancetype)init;

- (void)startGraph;

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;

@property(weak, nonatomic) id <MultiHandTrackerDelegate> delegate;

@end


typedef struct Landmark {
    float x;
    float y;
    float z;
} Landmark;
