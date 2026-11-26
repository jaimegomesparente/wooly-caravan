// Ordered dithering on the world's pixels (4x4 Bayer matrix): a pixel takes the next level when
// its share of the way there passes its threshold, so a gradient turns into a fixed pixel pattern.

const float BAYER4[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Threshold (0-1) of the world pixel `pixel` (whole coordinates) in the pattern.
float bayer_threshold(vec2 pixel) {
	ivec2 cell = ivec2(mod(pixel, 4.0));
	return (BAYER4[cell.y * 4 + cell.x] + 0.5) / 16.0;
}
