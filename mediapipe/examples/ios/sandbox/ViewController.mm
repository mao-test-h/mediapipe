#import "ViewController.h"
#import "mediapipe/objc/MPPGraph.h"
#import "mediapipe/objc/MPPCameraInputSource.h"
#import "mediapipe/objc/MPPLayerRenderer.h"
#import "mediapipe/objc/MPPPlayerInputSource.h"
#include "mediapipe/framework/formats/landmark.pb.h"

static const char* kVideoQueueLabel = "com.google.mediapipe.example.videoQueue";

static const char* kInputStream = "input_video";
static const char* kOutputStream = "output_video";
static const char* kLandmarksOutputStream = "multi_hand_landmarks";

static NSString* const kCameraPosition = @"front";
static NSString* const kGraphName = @"multi_hand_tracking_mobile_gpu";
//static NSString* const kGraphName = @"mobile_gpu";


@interface ViewController() <MPPInputSourceDelegate, MPPGraphDelegate>
@end


@implementation ViewController {

    // Handles camera access via AVCaptureSession library.
    MPPCameraInputSource* _cameraSource;

    // Process camera frames on this queue.
    dispatch_queue_t _videoQueue;

    // Render frames in a layer.
    MPPLayerRenderer* _renderer;

    // The MediaPipe graph currently in use. Initialized in viewDidLoad, started in viewWillAppear: and
    // sent video frames on _videoQueue.
    MPPGraph* _mediapipeGraph;
}


#pragma mark - Cleanup methods

- (void)dealloc {
    _mediapipeGraph.delegate = nil;
    [_mediapipeGraph cancel];
  
    // Ignore errors since we're cleaning up.
    [_mediapipeGraph closeAllInputStreamsWithError:nil];
    [_mediapipeGraph waitUntilDoneWithError:nil];
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
    
    _mediapipeGraph = [[self class] loadGraphFromResource:kGraphName];
    _mediapipeGraph.delegate = self;
    // Set maxFramesInFlight to a small value to avoid memory contention for real-time processing.
    _mediapipeGraph.maxFramesInFlight = 2;
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
            NSError* error;
            if (![_mediapipeGraph startWithError:&error]) {
                NSLog(@"Failed to start graph: %@", error);
            }
            
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
    
    [_mediapipeGraph sendPixelBuffer:imageBuffer
                          intoStream:kInputStream
                          packetType:MPPPacketTypePixelBuffer];
}


#pragma mark - MPPGraphDelegate methods

// Receives CVPixelBufferRef from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
  didOutputPixelBuffer:(CVPixelBufferRef)pixelBuffer
            fromStream:(const std::string&)streamName {
  
    if (streamName == kOutputStream) {
        // Display the captured image on the screen.
        CVPixelBufferRetain(pixelBuffer);
        dispatch_async(dispatch_get_main_queue(), ^{
            [_renderer renderPixelBuffer:pixelBuffer];
            CVPixelBufferRelease(pixelBuffer);
        });
    }
}

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
       didOutputPacket:(const ::mediapipe::Packet&)packet
            fromStream:(const std::string&)streamName {
    
    if (streamName == kLandmarksOutputStream) {
        if (packet.IsEmpty()) {
            NSLog(@"[TS:%lld] No hand landmarks", packet.Timestamp().Value());
            return;
        }
        
        const auto& multi_hand_landmarks = packet.Get<std::vector<::mediapipe::NormalizedLandmarkList>>();
        NSLog(@"[TS:%lld] Number of hand instances with landmarks: %lu", packet.Timestamp().Value(), multi_hand_landmarks.size());
      
        for (int hand_index = 0; hand_index < multi_hand_landmarks.size(); ++hand_index) {
            const auto& landmarks = multi_hand_landmarks[hand_index];
            NSLog(@"\tNumber of landmarks for hand[%d]: %d", hand_index, landmarks.landmark_size());
            for (int i = 0; i < landmarks.landmark_size(); ++i) {
                NSLog(@"\t\tLandmark[%d]: (%f, %f, %f)", i, landmarks.landmark(i).x(), landmarks.landmark(i).y(), landmarks.landmark(i).z());
            }
        }
    }
}

@end
