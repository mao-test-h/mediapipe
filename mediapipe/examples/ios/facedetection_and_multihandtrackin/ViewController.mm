#import "ViewController.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/detection.pb.h"
#include "mediapipe/framework/formats/rect.pb.h"
#include "mediapipe/framework/formats/classification.pb.h"

static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";

// Images coming into and out of the graph.
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";

// Face
static const char* kFaceDetectOutputStream = "face_detections";
static const char* kFaceRectOutputStream = "face_rect";
static const char* kFaceLandmarksOutputStream = "face_landmarks_with_iris";

// Left Eye
static const char* kLeftEyeContourLandmarksOutputStream = "left_eye_contour_landmarks";
static const char* kLeftIrisLandmarksOutputStream = "left_iris_landmarks";
// Right Eye
static const char* kRightEyeContourLandmarksOutputStream = "right_eye_contour_landmarks";
static const char* kRightIrisLandmarksOutputStream = "right_iris_landmarks";

// Multi-Hands
static const char* kMultiHand3dLandmarksOutputStream = "multi_hand_landmarks";
static const char* kMultiHandRectsOutputStream = "multi_hand_rects";
static const char* kMultiHandednessesOutputStream = "multi_handednesses";

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

    [newGraph addFrameOutputStream:kFaceDetectOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kFaceRectOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kFaceLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];

    [newGraph addFrameOutputStream:kLeftEyeContourLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kLeftIrisLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];

    [newGraph addFrameOutputStream:kRightEyeContourLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kRightIrisLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];

    [newGraph addFrameOutputStream:kMultiHand3dLandmarksOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kMultiHandRectsOutputStream outputPacketType:MPPPacketTypeRaw];
    [newGraph addFrameOutputStream:kMultiHandednessesOutputStream outputPacketType:MPPPacketTypeRaw];

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

    if (packet.IsEmpty()) {
        NSLog(@"[TS:%lld] No Packet", packet.Timestamp().Value());
        return;
    }

    [self printGraph:graph didOutputPacket:packet fromStream:streamName];
}

#pragma mark - mediapipeGraph print methods

- (void)printGraph:(MPPGraph*)graph
   didOutputPacket:(const ::mediapipe::Packet &)packet
        fromStream:(const std::string &)streamName {

    // Face
    if (streamName == kFaceDetectOutputStream) {
        [self printFaceDetect:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kFaceRectOutputStream) {
        [self printFaceRect:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kFaceLandmarksOutputStream) {
        [self printFaceLandmarks:graph didOutputPacket:packet fromStream:streamName];

        // Left Eye
    } else if (streamName == kLeftEyeContourLandmarksOutputStream) {
        [self printEyeContourLandmarksOutputStream:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kLeftIrisLandmarksOutputStream) {
        [self printIrisLandmarks:graph didOutputPacket:packet fromStream:streamName];

        // Right Eye
    } else if (streamName == kRightEyeContourLandmarksOutputStream) {
        [self printEyeContourLandmarksOutputStream:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kRightIrisLandmarksOutputStream) {
        [self printIrisLandmarks:graph didOutputPacket:packet fromStream:streamName];

        // Multi-Hands
    } else if (streamName == kMultiHand3dLandmarksOutputStream) {
        [self printMultiHand3dLandmarks:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kMultiHandRectsOutputStream) {
        [self printMultiHandRects:graph didOutputPacket:packet fromStream:streamName];
    } else if (streamName == kMultiHandednessesOutputStream) {
        [self printMultiHandednesses:graph didOutputPacket:packet fromStream:streamName];
    }
}

- (void)printFaceDetect:(MPPGraph*)graph
        didOutputPacket:(const ::mediapipe::Packet &)packet
             fromStream:(const std::string &)streamName {

    const auto &detects = packet.Get<std::vector<::mediapipe::Detection>>();
    NSLog(@"[FaceDetect][TS:%lld] Number of face instances with detections: %lu", packet.Timestamp().Value(), detects.size());

    for (int faceIndex = 0; faceIndex < detects.size(); ++faceIndex) {
        const auto &locationData = detects[faceIndex].location_data();
        const auto &format = locationData.format();
        const auto &boundingBox = locationData.bounding_box();
        const auto &relativeBoundingBox = locationData.relative_bounding_box();
        const auto &keypointSize = locationData.relative_keypoints_size();

        NSLog(@"\t[FaceDetect][Index] %d", faceIndex);
        NSLog(@"\t[FaceDetect][Format] %d", format);
        NSLog(@"\t[FaceDetect][BoundingBox] (%f, %f, %f, %f)", boundingBox.xmin(), boundingBox.ymin(), boundingBox.width(), boundingBox.height());
        NSLog(@"\t[FaceDetect][RelativeBoundingBox] (%f, %f, %f, %f)", relativeBoundingBox.xmin(), relativeBoundingBox.ymin(), relativeBoundingBox.width(), relativeBoundingBox.height());
        NSLog(@"\t[FaceDetect][KeypointSize] %d", keypointSize);

        for (int i = 0; i < keypointSize; ++i) {
            const auto &keypoint = locationData.relative_keypoints(i);
            NSLog(@"\t\t[FaceDetect][Keypoint] (%f, %f, %s, %f)", keypoint.x(), keypoint.y(), keypoint.keypoint_label().c_str(), keypoint.score());
        }
    }
}

- (void)printFaceRect:(MPPGraph*)graph
      didOutputPacket:(const ::mediapipe::Packet &)packet
           fromStream:(const std::string &)streamName {

    const auto &rect = packet.Get<mediapipe::NormalizedRect>();
    NSLog(@"[FaceRect][TS:%lld]", packet.Timestamp().Value());
    NSLog(@"\t[FaceRect][RelativeBoundingBox] (%f, %f, %f, %f)", rect.x_center(), rect.y_center(), rect.width(), rect.height());
}

- (void)printFaceLandmarks:(MPPGraph*)graph
           didOutputPacket:(const ::mediapipe::Packet &)packet
                fromStream:(const std::string &)streamName {

    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    NSLog(@"[FaceLandmark][TS:%lld]", packet.Timestamp().Value());
    NSLog(@"\t[FaceLandmark][LandmarkSize] %d", landmarks.landmark_size());

    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        const auto &landmark = landmarks.landmark(index);
        NSLog(@"\t\t[FaceLandmark] [%d](%f, %f, %f)", index, landmark.x(), landmark.y(), landmark.z());
    }
}

- (void)printEyeContourLandmarksOutputStream:(MPPGraph*)graph
                             didOutputPacket:(const ::mediapipe::Packet &)packet
                                  fromStream:(const std::string &)streamName {

    NSString* stream = (streamName == kLeftEyeContourLandmarksOutputStream) ? @"Left" : @"Right";
    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();

    NSLog(@"[%@EyeContourLamdmark][TS:%lld]", stream, packet.Timestamp().Value());
    NSLog(@"\t[%@EyeContourLamdmark][LandmarkSize] %d", stream, landmarks.landmark_size());

    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        const auto &landmark = landmarks.landmark(index);
        NSLog(@"\t\t[%@EyeContourLamdmark] [%d](%f, %f, %f)", stream, index, landmark.x(), landmark.y(), landmark.z());
    }
}

- (void)printIrisLandmarks:(MPPGraph*)graph
           didOutputPacket:(const ::mediapipe::Packet &)packet
                fromStream:(const std::string &)streamName {

    NSString* stream = (streamName == kLeftEyeContourLandmarksOutputStream) ? @"Left" : @"Right";
    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();

    NSLog(@"[%@IrisLamdmark][TS:%lld]", stream, packet.Timestamp().Value());
    NSLog(@"\t[%@IrisLamdmark][LandmarkSize] %d", stream, landmarks.landmark_size());

    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        const auto &landmark = landmarks.landmark(index);
        NSLog(@"\t\t[%@IrisLamdmark] [%d](%f, %f, %f)", stream, index, landmark.x(), landmark.y(), landmark.z());
    }
}

- (void)printMultiHand3dLandmarks:(MPPGraph*)graph
                  didOutputPacket:(const ::mediapipe::Packet &)packet
                       fromStream:(const std::string &)streamName {

    NSMutableArray* resultLandmarks = [NSMutableArray array];
    const auto &multiHandLandmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
    NSLog(@"[MultiHand3dLandmarks][TS:%lld] Number of hand instances with landmarks: %lu", packet.Timestamp().Value(), multiHandLandmarks.size());

    for (int handIndex = 0; handIndex < multiHandLandmarks.size(); ++handIndex) {
        const auto &hand = multiHandLandmarks[handIndex];
        const auto &landmarkSize = hand.landmark_size();

        NSLog(@"\t[MultiHand3dLandmarks][Index] %d", handIndex);
        NSLog(@"\t[MultiHand3dLandmarks][LandmarkSize] %d", landmarkSize);

        for (int i = 0; i < landmarkSize; ++i) {
            Landmark landmark;
            landmark.x = hand.landmark(i).x();
            landmark.y = hand.landmark(i).y();
            landmark.z = hand.landmark(i).z();
            [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(Landmark)]];

            const auto &landmark_ = hand.landmark(i);
            NSLog(@"\t\t[MultiHand3dLandmarks][Point] (%f, %f, %f)", landmark_.x(), landmark_.y(), landmark_.z());
            NSLog(@"\t\t[MultiHand3dLandmarks][Visibility] %f", landmark_.visibility());
            NSLog(@"\t\t[MultiHand3dLandmarks][Presence] %f", landmark_.presence());
        }
    }

    const int kLandmarkCount = 21;
    [_delegate multiHandTracker:self
             didOutputLandmarks:resultLandmarks
                  withHandCount:(int) multiHandLandmarks.size()
              withLandmarkCount:kLandmarkCount];
}

- (void)printMultiHandRects:(MPPGraph*)graph
            didOutputPacket:(const ::mediapipe::Packet &)packet
                 fromStream:(const std::string &)streamName {

    const auto &multiHandRects = packet.Get<std::vector<::mediapipe::NormalizedRect>>();
    NSLog(@"[MultiHandRects][TS:%lld] Number of hand instances with rects: %lu", packet.Timestamp().Value(), multiHandRects.size());

    for (int handIndex = 0; handIndex < multiHandRects.size(); ++handIndex) {
        const auto &rect = multiHandRects[handIndex];
        NSLog(@"\t[MultiHandRects][Index] %d", handIndex);
        NSLog(@"\t[MultiHandRects][Rect] (%f, %f, %f, %f)", rect.x_center(), rect.y_center(), rect.width(), rect.height());
    }
}

- (void)printMultiHandednesses:(MPPGraph*)graph
               didOutputPacket:(const ::mediapipe::Packet &)packet
                    fromStream:(const std::string &)streamName {

    const auto &multiHandClassifications = packet.Get<std::vector<::mediapipe::ClassificationList>>();
    NSLog(@"[MultiHandednesses][TS:%lld] Number of hand instances with Handedness: %lu", packet.Timestamp().Value(), multiHandClassifications.size());

    for (int handIndex = 0; handIndex < multiHandClassifications.size(); ++handIndex) {
        const auto &classifications = multiHandClassifications[handIndex];
        const auto &size = classifications.classification_size();

        NSLog(@"\t[MultiHandednesses][Index] %d", handIndex);
        NSLog(@"\t[MultiHandednesses][Size] %d", size);

        for (int i = 0; i < size; ++i) {
            const auto &classification = classifications.classification(i);

            NSLog(@"\t\t[MultiHandednesses][Index] %d", classification.index());
            NSLog(@"\t\t[MultiHandednesses][Score] %f", classification.score());
            NSLog(@"\t\t[MultiHandednesses][Label] %s", classification.label().c_str());
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
