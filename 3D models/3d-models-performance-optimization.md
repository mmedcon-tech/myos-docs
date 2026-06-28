### 3D GLB load performance 
The real cost was uncompressed GLBs (morph-target/blendshape data, not textures):
- Compressed all heavy avatars via meshopt + vertex quantization + WebP textures (scripts/optimize-avatars.mjs): avatar-1 13→2 MB, avatar-2 12→2.6 MB, kids-female 19→0.3 MB, kids-male 5→0.4 MB. All 66 morph/viseme lip-sync targets preserved (--no-simplify). Decodes natively via drei's bundled MeshoptDecoder — no extra loader config. Originals backed up in public/avatars/.originals/.
- Idle preload: preloadChatbotAvatar() warms the GLTF cache on requestIdleCallback, so opening a call resolves from cache in ms instead of suspending.
- Canvas now clamps dpr={[1,1.5]} and requests a high-performance GPU.
- Replaced the "Loading 3D model…" box with a lightweight poster (the avatar thumbnail) shown only during the now-sub-second decode.