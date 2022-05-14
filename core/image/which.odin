package image

import "core:os"

Which_File_Type :: enum {
	Unknown,

	BMP,
	EXR,
	GIF,
	HDR, // Radiance RGBE HDR
	JPEG,
	PBM, PGM, PPM, // NetPBM family
	PIC, // Softimage PIC
	PNG,
	PSD, // Photoshop PSD
	QOI,
	SGI_RGB, // Silicon Graphics Image RGB file format
	Sun_Rast, // Sun Raster Graphic
	TGA, // Targa Truevision
	TIFF,
	WebP,
	XBM, // X BitMap
}

which :: proc{
	which_bytes,
	which_file,
}

which_bytes :: proc(data: []byte) -> Which_File_Type {
	test_tga :: proc(s: string) -> bool {
		get8 :: #force_inline proc(s: ^string) -> u8 {
			v := s[0]
			s^ = s[1:]
			return v
		}
		get16le :: #force_inline  proc(s: ^string) -> u16 {
			v := u16(s[0]) | u16(s[1])<<16
			s^ = s[2:]
			return v
		}
		s := s
		s = s[1:] // skip offset

		color_type := get8(&s)
		if color_type > 1 {
			return false
		}
		image_type := get8(&s) // image type
		if color_type == 1 { // Colormap (Paletted) Image
			if image_type != 1 && image_type != 9 { // color type requires 1 or 9
				return false
			}
			s = s[4:] // skip index of first colormap
			bpcme := get8(&s) // check bits per colormap entry
			if bpcme != 8 && bpcme != 15 && bpcme != 16 && bpcme != 24 && bpcme != 32 {
				return false
			}
			s = s[4:] // skip image origin (x, y)
		} else { // Normal image without colormap
			if image_type != 2 && image_type != 3 && image_type != 10 && image_type != 11 {
				return false
			}
			s = s[9:] // skip colormap specification
		}
		if get16le(&s) < 1 || get16le(&s) < 1 { // test width and height
			return false
		}
		bpp := get8(&s) // bits per pixel
		if color_type == 1 && bpp != 8 && bpp != 16 {
			return false
		}
		if bpp != 8 && bpp != 15 && bpp != 16 && bpp != 24 && bpp != 32 {
			return false
		}
		return true
	}

	header: [128]byte
	copy(header[:], data)
	s := string(header[:])

	switch {
	case s[:2] == "BM":
		return .BMP
	case s[:4] == "\x76\x2f\x31\x01":
		return .EXR
	case s[:6] == "GIF87a", s[:6] == "GIF89a":
		return .GIF
	case s[6:10] == "JFIF", s[6:10] == "Exif":
		return .JPEG
	case s[:4] == "\xff\xd8\xff\xdb":
		return .JPEG
	case s[0] == 'P':
		switch s[2] {
		case '\t', '\n', '\r':
			switch s[1] {
			case '1', '4':
				return .PBM
			case '2', '5':
				return .PGM
			case '3', '6':
				return .PPM
			}
		}
	case s[:8] == "\x89PNG\r\n\x1a\n":
		return .PNG
	case s[:4] == "qoif":
		return .QOI
	case s[:2] == "\x01\xda":
		return .SGI_RGB
	case s[:4] == "\x59\xA6\x6A\x95":
		return .Sun_Rast
	case s[:2] == "MM", s[:2] == "II":
		return .TIFF
	case s[:4] == "RIFF" && s[8:12] == "WEBP":
		return .WebP
	case s[:8] == "#define ":
		return .XBM

	case s[:11] == "#?RADIANCE\n", s[:7] == "#?RGBE\n":
		return .HDR
	case s[:4] == "\x38\x42\x50\x53":
		return .PSD
	case s[:4] != "\x53\x80\xF6\x34" && s[88:92] == "PICT":
		return .PIC
	case:
		// More complex formats
		if test_tga(s) {
			return .TGA
		}


	}
	return .Unknown
}


which_file :: proc(path: string) -> Which_File_Type {
	f, err := os.open(path)
	if err != 0 {
		return .Unknown
	}
	header: [128]byte
	os.read(f, header[:])
	file_type := which_bytes(header[:])
	os.close(f)
	return file_type
}