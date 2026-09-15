# Lip contour precision

## Current implementation

The macOS FaceMesh path uses a 192×192 full-face Core ML model. The mouth occupies only part of that input. `LipContourRefiner` adds bounded local boundary fitting against the original BGRA camera frame after temporal filtering, before deriving lip contours and mouth anchors.

- Outer boundary: search perpendicular to each contour segment for a local lip-to-skin chromatic transition.
- Inner boundary: search for the lip-to-dark-cavity transition. Bright teeth do not provide this evidence, so the mesh remains the fallback there.
- Closed mouth: only nearby upper/lower pairs with evidence of a narrow dark contact line share one position. A broad opening must remain open.
- Keep corrections within a small search band (at most 5 pixels), regularize displacement between neighbors, reject inverted upper/lower fits, and leave all non-lip points and depth unchanged.
- Keep the mesh unchanged for weak evidence, small mouths, invalid coordinates, clipped contours, or unsupported buffer formats. This implementation is used by the FaceMesh tracker; the separate Apple Vision tracker is unchanged.

The lipstick mask now includes inner corner landmarks 78 and 308 rather than substituting outer corners 61 and 291. Ribbons explicitly connect the outer and inner endpoints.

This is image-guided contour refinement, **not a newly trained model or semantic lip segmentation**. It cannot recover large model errors, guarantee every point, or reliably resolve all lighting, skin/pigment, occlusion and teeth conditions. It does not replace the original model. Live video is still required to assess temporal stability and real accuracy.

## Model upgrade path

Google's [Attention Mesh documentation](https://github.com/google-ai-edge/mediapipe/blob/master/docs/solutions/face_mesh.md#attention-mesh-model) describes additional attention to lips and eyes; see the [Attention Mesh paper](https://arxiv.org/abs/2006.10962). It is a suitable candidate for a separately benchmarked model upgrade. The current bundled Core ML model does not gain this capability by increasing its output count or enabling a renderer option. Integrating the actual model/runtime and validating coordinate mapping, frame time, and lip accuracy is separate work.

## Validation

Run `test/lip_contour_regression.swift` using the command at its top. It covers weak evidence, invalid/clipped input, closure, open cavity, rotated mouth, image boundary recovery and preservation of unrelated landmarks. `test/face_mesh_scale_regression.swift` exercises stationary tracking and off-center zoom on a real image. RunnerTests checks mask coverage at distinct inner corners and no artificial center gap on closed lips, alongside existing makeup and reshape tests.

Verification on 2026-09-15: 23 RunnerTests passed, the standalone contour regression passed, and stationary/off-center zoom tracking passed on `assets/images/demo_portrait.png`. These checks validate behavior; they do not establish a measured accuracy improvement on live users.

For camera acceptance, compare raw and painted output with neutral expression, speech, smile, visible teeth, head roll, low light and different lipstick colors. Measure point-to-annotated-boundary distance on raw frames and processing time. The cropped, already-painted screenshot in the report is a symptom reference, not ground truth for the original detector.
