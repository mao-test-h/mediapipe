
load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_framework",
)

MIN_IOS_VERSION = "10.0"

ios_framework(
    name = "MultiHandTrackingKit",
    hdrs = [
        "MultiHandTrackingKit.h",
    ],
    bundle_id = "com.mao.MultiHandTrackingKit",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Info.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    deps = [
        ":MultiHandTrackingLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "MultiHandTrackingLibrary",
    srcs = [
        "MultiHandTrackingKit.mm",
    ],
    hdrs = [
        "MultiHandTrackingKit.h",
    ],
    data = [
        "//mediapipe/graphs/hand_tracking:multi_hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/models:hand_landmark.tflite",
        "//mediapipe/models:handedness.txt",
        "//mediapipe/models:palm_detection.tflite",
        "//mediapipe/models:palm_detection_labelmap.txt",
    ],
    sdk_frameworks = [
        "Foundation",
        "CoreVideo",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/hand_tracking:multi_hand_mobile_calculators",
            "//mediapipe/framework/formats:landmark_cc_proto",
        ],
    }),
)
