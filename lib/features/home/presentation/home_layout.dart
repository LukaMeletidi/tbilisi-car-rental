import 'package:flutter/material.dart';

/// The three photos of Home, bundled as assets (step 6b.6).
const homeHeroImage = 'assets/images/home/hero.jpg';
const homeProcessImage = 'assets/images/home/process.jpg';
const homeTrafficImage = 'assets/images/home/traffic.jpg';

/// The width and height of the hero photo, for its height on a phone.
const homeHeroImageAspectRatio = 1600 / 675;

/// The margin on the left and the right of every Home block.
const homeGutter = 16.0;

/// The rounded corners of the photos, as those of the cards.
const homeCornerRadius = 12.0;

/// Home is never wider than this; on a wide screen it stands in the middle.
const homeMaxWidth = 720.0;

/// The dark layer behind white text on a photo. With 60 % black, white text
/// is readable even where the photo is pure white (contrast about 5.7).
const homeScrimColor = Color(0x99000000);

/// The height of the soft edge where the dark layer fades into the photo.
const homeScrimFade = 24.0;
