# PDFBox's optional JPEG 2000 codec is not bundled. PDFBox handles its absence.
# Keep these rules scoped to the two optional classes referenced by JPXFilter.
-dontwarn com.gemalto.jp2.JP2Decoder
-dontwarn com.gemalto.jp2.JP2Encoder
