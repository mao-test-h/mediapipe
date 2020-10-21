#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

//! Project version number for MediaPipeKit.
FOUNDATION_EXPORT double MediaPipeKitVersionNumber;

//! Project version string for MediaPipeKit.
FOUNDATION_EXPORT const unsigned char MediaPipeKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MediaPipeKit/PublicHeader.h>

#pragma mark - Structs

// A normalized version of Landmark proto. All coordiates should be within
// [0, 1].
typedef struct NormalizedLandmark {
    float x;
    float y;
    float z;
} NormalizedLandmark;

// A rectangle with rotation in normalized coordinates. The values of box center
// location and size are within [0, 1].
typedef struct NormalizedRect {
    // Location of the center of the rectangle in image coordinates.
    // The (0.0, 0.0) point is at the (top, left) corner.
    float x_center;
    float y_center;

    // Size of the rectangle.
    float height;
    float width;

    // Rotation angle is clockwise in radians.
    float rotation;

    // Optional unique id to help associate different NormalizedRects to each
    // other.
    int64_t rect_id;
} NormalizedRect;

typedef struct Handedness {
    // 0:None, 1:Left, 2:Right, 3:Left & Right
    uint8_t detect;
    // Index on the left hand side in two-handed mode. (If both hands are undetected, it is -1.)
    int left_index;
} Handedness;

typedef struct Detection {
    float score;
} Detection;


#pragma mark - Protocols

@class MediaPipeFramework;

@protocol MediaPipeFrameworkDelegate <NSObject>

@required

// NOTE: NSValue<Detection>
- (void)receiveFaceDetect:(MediaPipeFramework*)framework
       didOutputDetection:(NSValue*)detection;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveFace3dLandmarks:(MediaPipeFramework*)framework
            didOutputLandmarks:(NSArray*)landmarks
             withLandmarkCount:(int)landmarkCount;

// NOTE: NSValue<NormalizedRect>
- (void)receiveFaceRect:(MediaPipeFramework*)framework
          didOutputRect:(NSValue*)rect;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveEyeContour3dLandmarks:(MediaPipeFramework*)framework
                  didOutputLandmarks:(NSArray*)landmarks
                   withLandmarkCount:(int)landmarkCount
                       isLeftOrRight:(bool)isLeft;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveIris3dLandmarks:(MediaPipeFramework*)framework
            didOutputLandmarks:(NSArray*)landmarks
             withLandmarkCount:(int)landmarkCount
                 isLeftOrRight:(bool)isLeft;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveMultiHand3dLandmarks:(MediaPipeFramework*)framework
                 didOutputLandmarks:(NSArray*)landmarks
                  withLandmarkCount:(int)landmarkCount
                      withHandCount:(int)handCount;

// NOTE: NSArray<NormalizedRect>
- (void)receiveMultiHandRects:(MediaPipeFramework*)framework
               didOutputRects:(NSArray*)rects
                withHandCount:(int)handCount;

// NOTE: NSValue<Handedness>
- (void)receiveMultiHandedness:(MediaPipeFramework*)framework
           didOutputHandedness:(NSValue*)handedness;

@optional

- (void)receivePixelBufferRef:(CVPixelBufferRef)pixelBuffer;

@end


#pragma mark - Interfaces

@interface MediaPipeFramework : NSObject

- (instancetype)init;

- (void)startGraph;

- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer;

@property(weak, nonatomic) id <MediaPipeFrameworkDelegate> delegate;

@end
