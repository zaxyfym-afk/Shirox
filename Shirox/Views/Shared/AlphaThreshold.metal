// The gooey blob's blur is cut back at half opacity on the GPU: the capsule and the circle
// join in a neck while close and part cleanly once far enough apart. Ported from the
// reference project's MorphingRefreshable (Balaji Venkatesh, Kavsoft), slightly simplified.

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[stitchable]] half4 alphaThreshold(float2 position, SwiftUI::Layer layer) {
    half4 color = layer.sample(position);
    half threshold = 0.5h;
    half edge = 0.02h;
    half alpha = smoothstep(threshold - edge, threshold + edge, color.a);
    return half4(color.rgb / max(color.a, 0.0001h), alpha);
}
