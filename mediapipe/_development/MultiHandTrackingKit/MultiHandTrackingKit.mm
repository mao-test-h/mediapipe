#import "MultiHandTrackingKit.h"
#import "mediapipe/objc/MPPGraph.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";
static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "multi_hand_landmarks";


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

    if (streamName != kLandmarksOutputStream) {return;}

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
}

@end
