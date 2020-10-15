# Copyright 2019 The MediaPipe Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load(
    "@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
)

licenses(["notice"])

MIN_IOS_VERSION = "10.0"

alias(
    name = "FaceDetectionAndMultiHandTrackin",
    actual = "FaceDetectionAndMultiHandTrackinApp",
)

filegroup(
    name = "AppIcon",
    srcs = glob(["Assets.xcassets/AppIcon.appiconset/*"]),
    visibility = ["//mediapipe:__subpackages__"],
)

ios_application(
    name = "FaceDetectionAndMultiHandTrackinApp",
    app_icons = ["//mediapipe/examples/ios/common:AppIcon"],
    bundle_id = "jp.mao-personal.wildcard.FaceDetectionAndMultiHandTrackin",
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = ["Info.plist"],
    minimum_os_version = MIN_IOS_VERSION,
    provisioning_profile = "//mediapipe:provisioning_profile.mobileprovision",
    deps = [
        ":FaceDetectionAndMultiHandTrackinAppLibrary",
        "@ios_opencv//:OpencvFramework",
    ],
)

objc_library(
    name = "FaceDetectionAndMultiHandTrackinAppLibrary",
    srcs = [
        "AppDelegate.m",
        "SceneDelegate.m",
        "ViewController.mm",
        "main.m",
    ],
    hdrs = [
        "AppDelegate.h",
        "SceneDelegate.h",
        "ViewController.h",
    ],
    data = [
        "Base.lproj/LaunchScreen.storyboard",
        "Base.lproj/Main.storyboard",
        "//mediapipe/graphs/_development:multi_hand_tracking_mobile_gpu_binary_graph",
        "//mediapipe/models:hand_landmark.tflite",
        "//mediapipe/models:handedness.txt",
        "//mediapipe/models:palm_detection.tflite",
        "//mediapipe/models:palm_detection_labelmap.txt",
        "//mediapipe/models:face_detection_front.tflite",
        "//mediapipe/models:face_detection_front_labelmap.txt",
        "//mediapipe/modules/face_landmark:face_landmark.tflite",
        "//mediapipe/modules/iris_landmark:iris_landmark.tflite",
    ],
    sdk_frameworks = [
        "AVFoundation",
        "CoreGraphics",
        "CoreMedia",
        "UIKit",
    ],
    deps = [
        "//mediapipe/objc:mediapipe_framework_ios",
        "//mediapipe/objc:mediapipe_input_sources_ios",
        "//mediapipe/objc:mediapipe_layer_renderer",
    ] + select({
        "//mediapipe:ios_i386": [],
        "//mediapipe:ios_x86_64": [],
        "//conditions:default": [
            "//mediapipe/graphs/_development:multi_hand_mobile_calculators",
            "//mediapipe/framework/formats:detection_cc_proto",
            "//mediapipe/framework/formats:landmark_cc_proto",
            "//mediapipe/framework/formats:rect_cc_proto",
            "//mediapipe/framework/formats:classification_cc_proto",
        ],
    }),
)
