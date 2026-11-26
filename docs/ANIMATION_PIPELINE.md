# ANI-01/02 — Licensed locomotion source pipeline

Baseline R076 (commit 3e4e4a40a692faa232198b606e60a183c2f8e1bc); CI 97 import and smoke, desktop visual, static A/B and safe material stages passed at last check, Android/ARM export not yet completed. Master prompt unchanged.

## Source selection
- Quaternius Universal Animation Library Standard, CC0, original: https://quaternius.com/packs/universalanimationlibrary.html and https://quaternius.itch.io/universal-animation-library
- Pinned archive mirror: MightyBubble/Ludots-Assets commit fab331eff1cb9c552c60399ea10186ef675cd460; manifest.animations.json records source, archive and SHA-256 cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724.
- Only the free Standard archive is fetched into /tmp. No third-party scripts executed. No raw archive added to project or APK. License/provenance documented. Audit failure is reported separately and must not block a valid existing gameplay APK.
- Alternative Mixamo: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html permits use in games; do not redistribute standalone raw animation assets in this public repository. No Mixamo assets obtained.

## Actual work
tools/audit_animation_source.py verifies archive SHA-256, parses GLB v2 JSON, lists joint names, animation names, durations when accessor maxima are present, channels, target names, and conservative alias candidates. Ambiguous or missing roles remain null. Outputs /tmp/animation_source_audit.json and target audit artifact. Does not silently select an ambiguous skeleton or modify original RAZE GLB.

## Acceptance and next step
1. Inspect source audit and target rig audit. Select verified in-place clips for idle, forward walk, run, sprint, backward and strafes. Missing variants remain missing, do not infer from marketing pack counts.
2. Verify actual rest orientations and parent chains; review alias matches manually (especially pelvis/waist/spine). Prepare BoneMap using SkeletonProfileHumanoid or explicit retarget transforms; do not rename the live RAZE rig until weapon/IK compatibility tests exist.
3. Bake target rotations on a separate animation library with original target bone names. Keep translation/scale and skin of RAZE intact; in-place physics remains authoritative. Retarget proof with neutral pose and known joint rotations before using real clips.
4. Preview front/side/back and compare eight directions, foot contact, shoulder/hand grip and duration. Only enable clips after visual approval and existing regression tests. Preserve procedural fallback, blend torso/weapon IK, and prevent AnimationPlayer and procedural writer fighting over the same bones.
5. Implement BlendSpace2D / AnimationTree after clip coverage is established; compare mobile frame time. Test stop/reversal/jump/slide and Android controls.
Docs: https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html and https://docs.godotengine.org/en/4.6/tutorials/animation/animation_tree.html
Status: audit code and CI wiring implemented, source download and mapping evidence pending. No new commercial-quality clip integrated yet.
