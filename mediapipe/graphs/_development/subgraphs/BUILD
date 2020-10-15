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
    "//mediapipe/framework/tool:mediapipe_graph.bzl",
    "mediapipe_simple_subgraph",
)

licenses(["notice"])

package(default_visibility = ["//visibility:public"])

mediapipe_simple_subgraph(
    name = "multi_hand_renderer_gpu",
    graph = "multi_hand_renderer_gpu.pbtxt",
    register_as = "MultiHandRendererSubgraph",
    deps = [
        "//mediapipe/calculators/core:begin_loop_calculator",
        "//mediapipe/calculators/core:end_loop_calculator",
        "//mediapipe/calculators/util:annotation_overlay_calculator",
        "//mediapipe/calculators/util:detections_to_render_data_calculator",
        "//mediapipe/calculators/util:landmarks_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_data_calculator",
        "//mediapipe/graphs/_development/subgraphs:iris_and_depth_renderer_gpu",
    ],
)

mediapipe_simple_subgraph(
    name = "iris_tracking_gpu_binary_graph",
    graph = "iris_tracking_gpu.pbtxt",
    register_as = "IrisTrackingSubgraph",
    deps = [
        "//mediapipe/calculators/core:constant_side_packet_calculator",
        "//mediapipe/calculators/core:flow_limiter_calculator",
        "//mediapipe/calculators/core:split_vector_calculator",
        "//mediapipe/graphs/iris_tracking/calculators:update_face_landmarks_calculator",
        "//mediapipe/modules/face_landmark:face_landmark_front_gpu",
        "//mediapipe/modules/iris_landmark:iris_landmark_left_and_right_gpu",
    ],
)

mediapipe_simple_subgraph(
    name = "iris_and_depth_renderer_gpu",
    graph = "iris_and_depth_renderer_gpu.pbtxt",
    register_as = "IrisAndDepthRendererGpu",
    deps = [
        "//mediapipe/graphs/iris_tracking/calculators:iris_to_depth_calculator",
        "//mediapipe/calculators/core:concatenate_normalized_landmark_list_calculator",
        "//mediapipe/calculators/core:concatenate_vector_calculator",
        "//mediapipe/calculators/core:split_normalized_landmark_list_calculator",
        "//mediapipe/calculators/util:annotation_overlay_calculator",
        "//mediapipe/calculators/util:detection_label_id_to_text_calculator",
        "//mediapipe/calculators/util:detections_to_render_data_calculator",
        "//mediapipe/calculators/util:landmarks_to_render_data_calculator",
        "//mediapipe/calculators/util:rect_to_render_data_calculator",
        "//mediapipe/graphs/face_mesh/calculators:face_landmarks_to_render_data_calculator",
        "//mediapipe/graphs/iris_tracking/calculators:iris_to_render_data_calculator",
    ],
)
