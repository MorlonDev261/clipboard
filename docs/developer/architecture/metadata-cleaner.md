# Metadata cleaner ("Deganeo")

Code: `lib/features/cleaner/` — `domain/` (report + options), `data/` (format
handlers, detector, pipeline), `application/` (isolate-backed service),
`presentation/` (page + report card). Tests: `test/cleaner/`.

## Strategy: lossless, allowlist-based, verified

No pixel is decoded or re-encoded (no quality loss, works on large files). Each
handler walks the *real* structure of its container and keeps only what is
needed to render/play; everything else is dropped or blanked **and reported**.
Unknown elements are removed by default, never kept by default. Malformed input
throws `FormatException` → `failed`; content we recognise but cannot clean
safely throws `UnsupportedContent` → `unsupported`. In both cases no output
file is produced and the original is untouched.

| Format | Kept | Removed / blanked |
|---|---|---|
| JPEG | image segments, JFIF (thumbnail zeroed), Adobe APP14, ICC (option) | EXIF, XMP, IPTC, COM, MPF, other APPn, data after EOI |
| PNG | rendering chunks, iCCP (option), APNG | tEXt/zTXt/iTXt (prompts…), tIME, eXIf, XMP, C2PA, unknown ancillary, data after IEND |
| WebP | image/animation chunks, ICCP (option); VP8X flags fixed | EXIF, XMP, unknown |
| GIF | image data, graphic control, loop extension | comments, plain-text, XMP/vendor extensions |
| TIFF | pixel tags only (allowlist), edited **in place** | Make/Model/Software/dates/artist/XMP/IPTC/GPS/Exif IFD (bytes zeroed). RAW/DNG/BigTIFF refused |
| MP4 / MOV / M4V | ftyp, moov(mvhd, tracks…), mdat, moof | `udta`, `meta` (GPS, make, model, Live-Photo id), uuid/XMP, padding, timed-metadata tracks **and their bytes in `mdat` (zeroed)**; timestamps, handler names and codec compressor names blanked; x264/HEVC user-data SEI turned into same-length filler NALs; `stco`/`co64` remapped |
| HEIC / AVIF | image items, properties, `iloc` remapped | `Exif` / `mime` (XMP) / `uri` items removed from `iinf`/`iloc`/`iref`/`ipma`, their bytes zeroed |
| MKV / WebM | everything | Tags, Info (Title, MuxingApp, WritingApp, DateUTC, file links), track names — overwritten in place by EBML `Void` of identical size (no offset moves), CRC-32 elements invalidated by an edit |
| AVI | everything else | `LIST INFO`, `IDIT` |
| PDF | everything reachable from `/Root`, rewritten as a fresh classic file | Info dict, XMP, `/PieceInfo`, thumbnails, annotation author/date, trailer `/ID`, **obsolete objects of incremental saves**, EXIF/XMP inside embedded JPEG images. Encrypted PDFs refused |

**Orientation:** removing EXIF drops the rotation flag, so a minimal EXIF holding
only the orientation tag is written back (`CleanOptions.preserveOrientation`).

## Verification (what "verified" means)

After writing, the output is re-parsed by the same handler in read-only mode and
cross-checked by `SignatureScanner` (XMP / IPTC / C2PA byte signatures, no
shared parsing code). `verifiedClean` = nothing sensitive left;
`cleanedWithCaveats` = clean plus a documented limit (`CleanCaveat`);
`residualFound` = something survived. The report lists before / after per
category — with the **actual values** where the format exposes them
(`MetadataFinding.entries`; shown in two small tables, total vs removed, with a
hide-values toggle; never logged). Every string is localised (fr / en / mg — mg is best-effort, have it
reviewed by a native speaker).

How it was validated beyond unit tests:

* `test/cleaner/fuzz_test.dart`: truncated / bit-flipped inputs for every
  format never crash, hang, or leave a partial output.
* Real files (iPhone HEIC + Live-Photo MOV, TikTok-style H.264 MP4, AVIF, Edge
  PDF, Pillow JPEG/PNG/WebP/GIF/TIFF): pixels identical after cleaning; for
  video, every sample of every kept track byte-identical except the SEI units.
  Windows' own decoders confirm playback: `Windows.Data.Pdf` renders the cleaned
  PDF pixel-identically and `StorageFile.GetThumbnailAsync` decodes identical
  frames from the cleaned MP4 / MOV (HEVC) / HEIC.

## Remaining limits (stated in the UI, not hidden)

* Video in codecs other than H.264 / HEVC: container metadata is cleaned but
  encoder text inside the stream is not inspected (`unsupportedCodecStream`).
* MKV/WebM attachments (fonts, cover art) are kept (`attachmentsKept`).
* RAW/DNG, BigTIFF, encrypted PDF, unknown formats: reported `unsupported`, not
  modified. PDF text content, images' *pixels*, visible watermarks and
  steganography are out of scope by nature.
* Chrome-style PDFs with predictor-encoded object streams are refused.
