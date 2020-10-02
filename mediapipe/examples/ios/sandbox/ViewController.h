#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

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


/**
 * ViewController
 */
@interface ViewController : UIViewController

// Display the camera preview frames.
@property(strong, nonatomic) IBOutlet UIView* liveView;

@end
