#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

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
    // 0:None, 1:Left, 2:Right, 3:Both(Left & Right), 4:Left & Left, 5:Right & Right, 6:Error
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
       didOutputDetection:(NSValue*)detection
                timeStamp:(int64_t)ts;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveFace3dLandmarks:(MediaPipeFramework*)framework
            didOutputLandmarks:(NSArray*)landmarks
             withLandmarkCount:(int)landmarkCount
                     timeStamp:(int64_t)ts;

// NOTE: NSValue<NormalizedRect>
- (void)receiveFaceRect:(MediaPipeFramework*)framework
          didOutputRect:(NSValue*)rect
              timeStamp:(int64_t)ts;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveEyeContour3dLandmarks:(MediaPipeFramework*)framework
                  didOutputLandmarks:(NSArray*)landmarks
                   withLandmarkCount:(int)landmarkCount
                       isLeftOrRight:(bool)isLeft
                           timeStamp:(int64_t)ts;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveIris3dLandmarks:(MediaPipeFramework*)framework
            didOutputLandmarks:(NSArray*)landmarks
             withLandmarkCount:(int)landmarkCount
                 isLeftOrRight:(bool)isLeft
                     timeStamp:(int64_t)ts;

// NOTE: NSArray<NormalizedLandmark>
- (void)receiveMultiHand3dLandmarks:(MediaPipeFramework*)framework
                 didOutputLandmarks:(NSArray*)landmarks
                  withLandmarkCount:(int)landmarkCount
                      withHandCount:(int)handCount
                          timeStamp:(int64_t)ts;

// NOTE: NSArray<NormalizedRect>
- (void)receiveMultiHandRects:(MediaPipeFramework*)framework
               didOutputRects:(NSArray*)rects
                withHandCount:(int)handCount
                    timeStamp:(int64_t)ts;

// NOTE: NSValue<Handedness>
- (void)receiveMultiHandedness:(MediaPipeFramework*)framework
           didOutputHandedness:(NSValue*)handedness
                     timeStamp:(int64_t)ts;

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

/**
 * ViewController
 */
@interface ViewController : UIViewController

// Display the camera preview frames.
@property(strong, nonatomic) IBOutlet UIView* liveView;

@end
