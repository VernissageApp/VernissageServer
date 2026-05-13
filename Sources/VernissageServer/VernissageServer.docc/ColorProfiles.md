# Color Profiles

This document describes the current behavior of two endpoints:
- `POST /api/v1/attachments` (``AttachmentsController/upload(request:)``)
- `POST /api/v1/attachments/:id/hdr` (``AttachmentsController/uploadHdr(request:)``)

The description reflects the current implementation in ``AttachmentsController`` and image helpers based on `SwiftGD/libgd`.

## Regular upload 

Action: ``AttachmentsController/upload(request:)``

### Accepted input
- The file is uploaded as `multipart/form-data`.
- Maximum file size is `imageSizeLimit` from settings (default: `10_485_760` bytes).
- Supported input extensions: `jpg`, `jpeg`, `png`, `webp`.

### Processing pipeline
1. The uploaded file is written to a temporary location.
2. The image is decoded in memory (`SwiftGD.Image`).
3. EXIF `Orientation` is read and the image is rotated accordingly.
4. The Vernissage "original" file is produced:
   - the rotated image is exported to JPEG,
   - export creates a new image stream (`gdImageJpeg`),
   - source metadata (including EXIF and embedded ICC profile) is not preserved.
5. The Vernissage "small" file is produced:
   - based on the rotated image,
   - resized to width `800 px` with preserved aspect ratio,
   - saved as JPEG,
   - source metadata is not preserved.
6. Both files are saved to storage.

### Size and geometry details
- `smallFile` always has width `800 px`; height is derived from aspect ratio.
- Resizing is always width-based (`800`), so small source images may be upscaled.
- `originalFile` dimensions stored in `FileInfo` come from `image.size` (the decoded source dimensions before rotation metadata is removed from representation).
- `smallFile` dimensions stored in `FileInfo` come from `resized.size`.

### EXIF and color profile
- EXIF is used only to determine orientation; it is not retained in output files.
- Embedded ICC profile from the source file is not retained.
- Practical result: output JPEGs are interpreted as sRGB by typical clients (browsers/OS viewers), but they do not carry the original embedded ICC profile.

## HDR upload 

Action: ``AttachmentsController/uploadHdr(request:)``

### Accepted input
- Requires an existing attachment owned by the authenticated user.
- Maximum HDR file size: `4_194_304` bytes.
- Only `avif` extension is accepted.

### Processing pipeline
1. The uploaded AVIF file is written to a temporary location.
2. The file is saved to storage as `originalHdrFile`.
3. No decode, rotate, resize, or re-encode step is performed.
4. `originalHdrFile` is attached in the database.
5. `originalHdrFile` dimensions in `FileInfo` are copied from the existing `originalFile` dimensions (they are not read from AVIF during `uploadHdr`).

### EXIF and color profile
- The HDR file is handled as binary payload and stored as-is.
- Metadata and color profile remain exactly as provided in the uploaded AVIF.

## Regular upload vs HDR upload at a glance

| Area | Regular upload | HDR upload |
|---|---|---|
| Image decode | Yes | No |
| EXIF-based rotation | Yes | No |
| Resize | Yes (`small` to 800 px width) | No |
| Re-encode | Yes (JPEG) | No |
| EXIF/ICC preservation | No (metadata removed in derived outputs) | Yes (file stored unchanged) |

## Why we currently standardize distribution output to sRGB

This is an intentional interoperability decision:
- sRGB offers the most predictable rendering across the open web (browsers, social media platforms, heterogeneous devices).
- For uncontrolled recipients, sRGB is the safest exchange space.
- Wider gamuts (for example Display P3 / Adobe RGB) are valuable mainly in controlled display or print pipelines.

Operationally:
- `upload` produces a web-safe distribution variant,
- `uploadHdr` keeps an additional high-fidelity original HDR asset.

This follows the recommended model: keep a wider-gamut master when needed, and publish a compatibility-focused web derivative.
