# MobileCLIP Model Placement

Place a compiled `MobileCLIP.mlmodelc` directory here to enable CLIP-based
mood clustering. Without it, Loom falls back to Vision's feature-print
(still functional, slightly less semantic).

## How to get the model

1. Clone Apple's ml-mobileclip:
   ```
   git clone https://github.com/apple/ml-mobileclip
   ```

2. Export the image encoder to CoreML (Python):
   ```python
   import coremltools as ct
   import torch
   # Load MobileCLIP-S2 image encoder (smallest that's still accurate)
   model = ...  # see ml-mobileclip README
   traced = torch.jit.trace(model.image_encoder, dummy_input)
   mlmodel = ct.convert(traced, inputs=[ct.ImageType(shape=(1, 3, 256, 256))])
   mlmodel.save("MobileCLIP.mlpackage")
   ```

3. Compile:
   ```
   xcrun coremlcompiler compile MobileCLIP.mlpackage .
   ```

4. Move `MobileCLIP.mlmodelc/` into this directory.

The resulting app size increase is ~40–60 MB depending on the variant.
