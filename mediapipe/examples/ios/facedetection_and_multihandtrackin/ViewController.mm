#import "ViewController.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/detection.pb.h"
#include "mediapipe/framework/formats/rect.pb.h"

static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";

static const char* kLandmarksOutputStream = "multi_hand_landmarks";
static const char* kFaceOutputStream = "face_detections";
static const char* kHandRectsOutputStream = "multi_hand_rects";

// "front" or "back"
static NSString* const kCameraPosition = @"front";


@interface MultiHandTracker () <MPPGraphDelegate>
@end

@implementation MultiHandTracker {

    // The MediaPipe graph currently in use. Initialized in viewDidLoad, started in viewWillAppear: and
    // sent video frames on _videoQueue.
    MPPGraph* _mediapipeGraph;
}

- (void)dealloc {
    _mediapipeGraph.delegate = nil;
    [_mediapipeGraph cancel];

    // Ignore errors since we're cleaning up.
    [_mediapipeGraph closeAllInputStreamsWithError:nil];
    [_mediapipeGraph waitUntilDoneWithError:nil];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
        _mediapipeGraph.delegate = self;
        // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
        _mediapipeGraph.maxFramesInFlight = 2;
    }
    return self;
}

- (void)startGraph {
    NSError* error;
    if (![_mediapipeGraph startWithError:&error]) {
        NSLog(@"Failed to start graph: %@", error);
    }
}

// Must be invoked on self.videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    [_mediapipeGraph sendPixelBuffer:imageBuffer
                          intoStream:kInputStream
                          packetType:MPPPacketTypePixelBuffer];
}

#pragma mark - MediaPipe graph methods

+ (MPPGraph*)loadGraphFromResource:(NSString*)resource {

    // Load the graph config resource.
    NSError* configLoadError = nil;
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    if (!resource || resource.length == 0) {
        return nil;
    }

    NSURL* graphURL = [bundle URLForResource:resource withExtension:@"binarypb"];
    NSData* data = [NSData dataWithContentsOfURL:graphURL options:0 error:&configLoadError];
    if (!data) {
        NSLog(@"Failed to load MediaPipe graph config: %@", configLoadError);
        return nil;
    }

    // Parse the graph config resource into mediapipe::CalculatorGraphConfig proto object.
    mediapipe::CalculatorGraphConfig config;
    config.ParseFromArray(data.bytes, data.length);

    // Create MediaPipe graph with mediapipe::CalculatorGraphConfig proto object.
    MPPGraph* newGraph = [[MPPGraph alloc] initWithGraphConfig:config];
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
    [newGraph addFrameOutputStream:kLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kFaceOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kHandRectsOutputStream outputPacketType:MPPPacketTypeRaw];
    return newGraph;
}

#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string &)streamName {
    if (streamName != kOutputStream) {return;}
    [_delegate multiHandTracker:self didOutputPixelBuffer:pixelBuffer];
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet &)packet
            fromStream:(const std::string &)streamName {

    if (streamName == kLandmarksOutputStream) {

        // multi-hands landmarks poins
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No hand landmarks", packet.Timestamp().Value());
            return;
        }

        const int kLandmarkCount = 21;
        NSMutableArray* resultLandmarks = [NSMutableArray array];
        const auto &multiHandLandmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
        for (int hand_index = 0; hand_index < multiHandLandmarks.size(); ++hand_index) {
            const auto &landmarks = multiHandLandmarks[hand_index];
            for (int i = 0; i < landmarks.landmark_size(); ++i) {
                Landmark landmark;
                landmark.x = landmarks.landmark(i).x();
                landmark.y = landmarks.landmark(i).y();
                landmark.z = landmarks.landmark(i).z();
                [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(Landmark)]];
            }

            if (kLandmarkCount != landmarks.landmark_size()) {
                NSLog(@"Different landmark count for A:[%d], B:[%d]", landmarks.landmark_size(), kLandmarkCount);
            }
        }

        [_delegate multiHandTracker:self
                 didOutputLandmarks:resultLandmarks
                      withHandCount:(int) multiHandLandmarks.size()
                  withLandmarkCount:kLandmarkCount];

    } else if (streamName == kFaceOutputStream) {

        //face landmarks poins
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No face landmarks", packet.Timestamp().Value());
            return;
        }

        const auto &multi_fac_dect = packet.Get<std::vector<::mediapipe::Detection>>();
        //NSLog(@"[TS:%lld] Number of face instances with rects: %lu", packet.Timestamp().Value(), multi_fac_dect.size());

        for (int face_index = 0; face_index < multi_fac_dect.size(); ++face_index) {

            const auto &location_data = multi_fac_dect[face_index].location_data();
            const auto &keypoints = location_data.relative_keypoints();
            //NSLog(@"\tNumber of landmarks for face[%d]: %d", face_index, keypoints.size());

            for (int i = 0; i < keypoints.size(); ++i) {
                const auto &keypoint = keypoints[i];
                //NSLog(@"\t\tFace Landmark[%d]: (%f, %f)", i, keypoint.x(), keypoint.y());
            }
        }
    } else if (streamName == kHandRectsOutputStream) {
    
        // multi-hands rects
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No face landmarks", packet.Timestamp().Value());
            return;
        }

        const auto &multiHandRects = packet.Get<std::vector<::mediapipe::NormalizedRect>>();
        NSLog(@"[TS:%lld] Number of Rect instances: %lu", packet.Timestamp().Value(), multiHandRects.size());
        
        for (int hand_index = 0; hand_index < multiHandRects.size(); ++hand_index) {
            const auto &rect = multiHandRects[hand_index];
            NSLog(@"\tHand rect[%d]: (%f, %f, %f, %f)", hand_index, rect.x_center(), rect.y_center(), rect.width(), rect.height());
        }
    }
}

@end


@interface ViewController () <MPPInputSourceDelegate, MultiHandTrackerDelegate>
@end

@implementation ViewController {

    // Render frames in a layer.
    MPPLayerRenderer* _renderer;

    // Handles camera access via AVCaptureSession library.
    MPPCameraInputSource* _cameraSource;

    // Process camera frames on this queue.
    dispatch_queue_t _videoQueue;

    // MultiHandTracker module.
    MultiHandTracker* _multiHandTracker;
}

#pragma mark - UIViewController methods

- (void)viewDidLoad {
    [super viewDidLoad];

    _renderer = [[MPPLayerRenderer alloc] init];
    _renderer.layer.frame = _liveView.layer.bounds;
    [_liveView.layer addSublayer:_renderer.layer];
    _renderer.frameScaleMode = MPPFrameScaleModeFillAndCrop;

    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0);
    _videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);

    _multiHandTracker = [[MultiHandTracker alloc] init];
    _multiHandTracker.delegate = self;
}


// In this application, there is only one ViewController which has no navigation to other view
// controllers, and there is only one View with live display showing the result of running the
// MediaPipe graph on the live video feed. If more view controllers are needed later, the graph
// setup/teardown and camera start/stop logic should be updated appropriately in response to the
// appearance/disappearance of this ViewController, as viewWillAppear: can be invoked multiple times
// depending on the application navigation flow in that case.
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    _cameraSource = [[MPPCameraInputSource alloc] init];
    [_cameraSource setDelegate:self queue:_videoQueue];
    _cameraSource.sessionPreset = AVCaptureSessionPresetHigh;

    if (kCameraPosition.length > 0 && [kCameraPosition isEqualToString:@"back"]) {
        _cameraSource.cameraPosition = AVCaptureDevicePositionBack;
    } else {
        _cameraSource.cameraPosition = AVCaptureDevicePositionFront;
        // When using the front camera, mirror the input for a more natural look.
        _cameraSource.videoMirrored = YES;
    }

    // The frame's native format is rotated with respect to the portrait orientation.
    _cameraSource.orientation = AVCaptureVideoOrientationPortrait;

    [_cameraSource requestCameraAccessWithCompletionHandler:^void(BOOL granted) {
        if (granted) {
            [_multiHandTracker startGraph];
            dispatch_async(_videoQueue, ^{
                [_cameraSource start];
            });
        }
    }];
}

#pragma mark - MPPInputSourceDelegate methods

// Must be invoked on self.videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                timestamp:(CMTime)timestamp
               fromSource:(MPPInputSource*)source {

    if (source != _cameraSource) {
        NSLog(@"Unknown source: %@", source);
        return;
    }

    [_multiHandTracker processVideoFrame:imageBuffer];
}

#pragma mark - MultiHandTrackerDelegate methods

- (void)multiHandTracker:(MultiHandTracker*)tracker
      didOutputLandmarks:(NSArray*)landmarks
           withHandCount:(int)handCount
       withLandmarkCount:(int)landmarkCount {

    NSLog(@"Number of hand instances with landmarks: %d", handCount);
    NSLog(@"\tNumber of landmarks: %d", landmarkCount);
    for (int i = 0; i < handCount; ++i) {
        for (int j = 0; j < landmarkCount; ++j) {

            int index = j + (i * landmarkCount);
            Landmark landmark;
            [landmarks[static_cast<NSUInteger>(index)] getValue:&landmark size:sizeof(Landmark)];
            NSLog(@"\t\tLandmark[%d][%d]: (%f, %f, %f)", i, index, landmark.x, landmark.y, landmark.z);
        }
    }
}

- (void)multiHandTracker:(MultiHandTracker*)tracker
    didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer {

    // Display the captured image on the screen.
    CVPixelBufferRetain(pixelBuffer);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_renderer renderPixelBuffer:pixelBuffer];
        CVPixelBufferRelease(pixelBuffer);
    });
}

@end
