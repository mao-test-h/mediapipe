//#define ENABLE_DEBUG

#import "MediaPipeKit.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#include "mediapipe/framework/formats/landmark.pb.h"
#include "mediapipe/framework/formats/detection.pb.h"
#include "mediapipe/framework/formats/rect.pb.h"
#include "mediapipe/framework/formats/classification.pb.h"

static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

#ifdef ENABLE_DEBUG
static NSString* const kGraphName = @"debug_multi_hand_tracking_mobile_gpu";
#else
static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";
#endif

// Images coming into and out of the graph.
static const char* kInputStream = "input_video";

#ifdef ENABLE_DEBUG
static const char* kOutputStream = "output_video";
#endif

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


@interface MediaPipeFramework () <MPPGraphDelegate, MPPInputSourceDelegate>
@end

@implementation MediaPipeFramework {

    // The MediaPipe graph currently in use. Initialized in viewDidLoad, started in viewWillAppear: and
    // sent video frames on _videoQueue.
    MPPGraph* _mediapipeGraph;

    // Handles camera access via AVCaptureSession library.
    MPPCameraInputSource* _cameraSource;

    // Process camera frames on this queue.
    dispatch_queue_t _videoQueue;
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

- (void)startGraphWithCamera {

    dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(
            DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, /*relative_priority=*/0);
    _videoQueue = dispatch_queue_create(kVideoQueueLabel, qosAttribute);

    _cameraSource = [[MPPCameraInputSource alloc] init];
    [_cameraSource setDelegate:self queue:_videoQueue];
    _cameraSource.sessionPreset = AVCaptureSessionPreset640x480;

    // Use front camera.
    _cameraSource.cameraPosition = AVCaptureDevicePositionFront;
    // When using the front camera, mirror the input for a more natural look.
    _cameraSource.videoMirrored = YES;

    // The frame's native format is rotated with respect to the portrait orientation.
    _cameraSource.orientation = AVCaptureVideoOrientationPortrait;

    [_cameraSource requestCameraAccessWithCompletionHandler:^void(BOOL granted) {
        if (granted) {
            [self startGraph];
            dispatch_async(_videoQueue, ^{
                [_cameraSource start];
            });
        }
    }];
}

// MediaPipeFramework.processVideoFrame
// Must be invoked on self.videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer {
    [_mediapipeGraph sendPixelBuffer:imageBuffer
                          intoStream:kInputStream
                          packetType:MPPPacketTypePixelBuffer];
}

#pragma mark - MPPInputSourceDelegate methods

// MPPInputSourceDelegate.processVideoFrame
// Must be invoked on self.videoQueue.
- (void)processVideoFrame:(CVPixelBufferRef)imageBuffer
                timestamp:(CMTime)timestamp
               fromSource:(MPPInputSource*)source {

    if (source != _cameraSource) {
        NSLog(@"Unknown source: %@", source);
        return;
    }

    [self processVideoFrame:imageBuffer];
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

#ifdef ENABLE_DEBUG
    [newGraph addFrameOutputStream:kOutputStream outputPacketType:MPPPacketTypePixelBuffer];
#endif

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

#ifdef ENABLE_DEBUG

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string &)streamName {

    if (streamName != kOutputStream) {return;}
    [_delegate receivePixelBufferRef:pixelBuffer];
}

#endif

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet &)packet
            fromStream:(const std::string &)streamName {

    if (packet.IsEmpty()) {
        NSLog(@"[TS:%lld] No Packet", packet.Timestamp().Value());
        return;
    }

    int64_t ts = packet.Timestamp().Value();
    [self sendGraph:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
}

#pragma mark - mediapipeGraph send methods

- (void)sendGraph:(MPPGraph*)graph
  didOutputPacket:(const ::mediapipe::Packet &)packet
       fromStream:(const std::string &)streamName
        timeStamp:(int64_t)ts {

    // Face
    if (streamName == kFaceDetectOutputStream) {
        [self sendFaceDetect:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kFaceLandmarksOutputStream) {
        [self sendFace3dLandmarks:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kFaceRectOutputStream) {
        [self sendFaceRect:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];

        // Left Eye
    } else if (streamName == kLeftEyeContourLandmarksOutputStream) {
        [self sendEyeContour3dLandmarksOutputStream:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kLeftIrisLandmarksOutputStream) {
        [self sendIris3dLandmarks:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];

        // Right Eye
    } else if (streamName == kRightEyeContourLandmarksOutputStream) {
        [self sendEyeContour3dLandmarksOutputStream:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kRightIrisLandmarksOutputStream) {
        [self sendIris3dLandmarks:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];

        // Multi-Hands
    } else if (streamName == kMultiHand3dLandmarksOutputStream) {
        [self sendMultiHand3dLandmarks:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kMultiHandRectsOutputStream) {
        [self sendMultiHandRects:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    } else if (streamName == kMultiHandednessesOutputStream) {
        [self sendMultiHandednesses:graph didOutputPacket:packet fromStream:streamName timeStamp:ts];
    }
}

- (void)sendFaceDetect:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet &)packet
            fromStream:(const std::string &)streamName
             timeStamp:(int64_t)ts {

    float detectionScore = 0;
    const auto &detects = packet.Get<std::vector<::mediapipe::Detection>>();
    for (int faceIndex = 0; faceIndex < detects.size(); ++faceIndex) {
        const auto &detect = detects[faceIndex];
        for (int i = 0; i < detect.score_size(); ++i) {
            const auto &score = detect.score(i);
            detectionScore = score;
        }
    }

    Detection detection;
    detection.score = detectionScore;
    NSValue* result = [NSValue value:&detection withObjCType:@encode(Detection)];
    [_delegate receiveFaceDetect:self
              didOutputDetection:result
                       timeStamp:ts];
}

- (void)sendFace3dLandmarks:(MPPGraph*)graph
            didOutputPacket:(const ::mediapipe::Packet &)packet
                 fromStream:(const std::string &)streamName
                  timeStamp:(int64_t)ts {

    NSMutableArray* resultLandmarks = [NSMutableArray array];
    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        NormalizedLandmark landmark;
        landmark.x = landmarks.landmark(index).x();
        landmark.y = landmarks.landmark(index).y();
        landmark.z = landmarks.landmark(index).z();
        [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(NormalizedLandmark)]];
    }

    [_delegate receiveFace3dLandmarks:self
                   didOutputLandmarks:resultLandmarks
                    withLandmarkCount:landmarks.landmark_size()
                            timeStamp:ts];
}

- (void)sendFaceRect:(MPPGraph*)graph
     didOutputPacket:(const ::mediapipe::Packet &)packet
          fromStream:(const std::string &)streamName
           timeStamp:(int64_t)ts {

    const auto &rect = packet.Get<mediapipe::NormalizedRect>();
    NormalizedRect nRect;
    nRect.x_center = rect.x_center();
    nRect.y_center = rect.y_center();
    nRect.width = rect.width();
    nRect.height = rect.height();
    nRect.rotation = rect.rotation();
    nRect.rect_id = rect.rect_id();
    NSValue* result = [NSValue value:&nRect withObjCType:@encode(NormalizedRect)];
    [_delegate receiveFaceRect:self
                 didOutputRect:result
                     timeStamp:ts];
}

- (void)sendEyeContour3dLandmarksOutputStream:(MPPGraph*)graph
                              didOutputPacket:(const ::mediapipe::Packet &)packet
                                   fromStream:(const std::string &)streamName
                                    timeStamp:(int64_t)ts {

    NSMutableArray* resultLandmarks = [NSMutableArray array];
    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        NormalizedLandmark landmark;
        landmark.x = landmarks.landmark(index).x();
        landmark.y = landmarks.landmark(index).y();
        landmark.z = landmarks.landmark(index).z();
        [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(NormalizedLandmark)]];
    }

    [_delegate receiveEyeContour3dLandmarks:self
                         didOutputLandmarks:resultLandmarks
                          withLandmarkCount:landmarks.landmark_size()
                              isLeftOrRight:(streamName == kLeftEyeContourLandmarksOutputStream)
                                  timeStamp:ts];
}

- (void)sendIris3dLandmarks:(MPPGraph*)graph
            didOutputPacket:(const ::mediapipe::Packet &)packet
                 fromStream:(const std::string &)streamName
                  timeStamp:(int64_t)ts {

    NSMutableArray* resultLandmarks = [NSMutableArray array];
    const auto &landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
    for (int index = 0; index < landmarks.landmark_size(); ++index) {
        NormalizedLandmark landmark;
        landmark.x = landmarks.landmark(index).x();
        landmark.y = landmarks.landmark(index).y();
        landmark.z = landmarks.landmark(index).z();
        [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(NormalizedLandmark)]];
    }

    [_delegate receiveIris3dLandmarks:self
                   didOutputLandmarks:resultLandmarks
                    withLandmarkCount:landmarks.landmark_size()
                        isLeftOrRight:(streamName == kLeftIrisLandmarksOutputStream)
                            timeStamp:ts];
}

- (void)sendMultiHand3dLandmarks:(MPPGraph*)graph
                 didOutputPacket:(const ::mediapipe::Packet &)packet
                      fromStream:(const std::string &)streamName
                       timeStamp:(int64_t)ts {

    NSMutableArray* resultLandmarks = [NSMutableArray array];
    const auto &multiHandLandmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
    for (int handIndex = 0; handIndex < multiHandLandmarks.size(); ++handIndex) {
        const auto &hand = multiHandLandmarks[handIndex];
        const auto &landmarkSize = hand.landmark_size();
        for (int i = 0; i < landmarkSize; ++i) {
            NormalizedLandmark landmark;
            landmark.x = hand.landmark(i).x();
            landmark.y = hand.landmark(i).y();
            landmark.z = hand.landmark(i).z();
            [resultLandmarks addObject:[NSValue value:&landmark withObjCType:@encode(NormalizedLandmark)]];
        }
    }

    const int kLandmarkCount = 21;
    [_delegate receiveMultiHand3dLandmarks:self
                        didOutputLandmarks:resultLandmarks
                         withLandmarkCount:kLandmarkCount
                             withHandCount:(int) multiHandLandmarks.size()
                                 timeStamp:ts];
}

- (void)sendMultiHandRects:(MPPGraph*)graph
           didOutputPacket:(const ::mediapipe::Packet &)packet
                fromStream:(const std::string &)streamName
                 timeStamp:(int64_t)ts {

    NSMutableArray* resultRects = [NSMutableArray array];
    const auto &multiHandRects = packet.Get<std::vector<::mediapipe::NormalizedRect>>();
    for (int handIndex = 0; handIndex < multiHandRects.size(); ++handIndex) {
        const auto &rect = multiHandRects[handIndex];
        NormalizedRect nRect;
        nRect.x_center = rect.x_center();
        nRect.y_center = rect.y_center();
        nRect.width = rect.width();
        nRect.height = rect.height();
        nRect.rotation = rect.rotation();
        nRect.rect_id = rect.rect_id();
        [resultRects addObject:[NSValue value:&nRect withObjCType:@encode(NormalizedRect)]];
    }

    [_delegate receiveMultiHandRects:self
                      didOutputRects:resultRects
                       withHandCount:(int) multiHandRects.size()
                           timeStamp:ts];
}

- (void)sendMultiHandednesses:(MPPGraph*)graph
              didOutputPacket:(const ::mediapipe::Packet &)packet
                   fromStream:(const std::string &)streamName
                    timeStamp:(int64_t)ts {

    // 0:None, 1:Left, 2:Right, 3:Both(Left & Right), 4:Left & Left, 5:Right & Right, 6:Error
    uint8_t detect = 0;
    int leftCount = 0, rightCount = 0;
    int leftIndex = -1;

    const auto &multiHandClassifications = packet.Get<std::vector<::mediapipe::ClassificationList>>();
    for (int handIndex = 0; handIndex < multiHandClassifications.size(); ++handIndex) {
        const auto &classifications = multiHandClassifications[handIndex];
        for (int i = 0; i < classifications.classification_size(); ++i) {
            const auto &classification = classifications.classification(i);
            if (classification.label().compare("Left") == 0) {
                leftCount += 1;
                leftIndex = handIndex;
            } else if (classification.label().compare("Right") == 0) {
                rightCount += 1;
            }
        }
    }

    if (leftCount == 0 && rightCount == 0) {
        // 0:None
        detect = 0;
    } else if (leftCount == 1 && rightCount == 1) {
        // 3:Both
        detect = 3;
    } else if (leftCount == 1 && rightCount == 0) {
        // 1:Left
        detect = 1;
    } else if (leftCount == 0 && rightCount == 1) {
        // 2:Right
        detect = 2;
    } else if (leftCount == 2 && rightCount == 0) {
        // Left & Left
        detect = 4;
    } else if (leftCount == 0 && rightCount == 2) {
        // Right & Right
        detect = 5;
    } else {
        // Other (Treat as error.)
        detect = 6;
    }

    Handedness handedness;
    handedness.detect = detect;
    handedness.left_index = leftIndex;
    NSValue* result = [NSValue value:&handedness withObjCType:@encode(Handedness)];
    [_delegate receiveMultiHandedness:self
                  didOutputHandedness:result
                            timeStamp:ts];
}

@end
