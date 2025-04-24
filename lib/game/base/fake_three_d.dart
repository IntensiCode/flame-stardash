import 'dart:math';
import 'dart:ui';

/// Calculates a scale factor based on depth (gridZ) using perspective projection.
///
/// Interpolates between [outerScale] (at gridZ=0) and [deepScale] (at gridZ=1)
/// using the square root of the normalized gridZ for a perspective effect.
///
/// Allows extrapolation beyond the 0.0 to 1.0 range.
double perspective_scale_factor(double gridZ, double outerScale, double deepScale) {
  // Use gridZ directly for extrapolation. Handle potential negative values in sqrt.
  final normalizedZ = gridZ;

  // Apply perspective using square root. Allow negative inputs for sqrt
  // by taking sqrt of absolute value and applying sign afterwards if needed,
  // although lerpDouble handles t < 0, sqrt needs non-negative.
  // For lerp, t < 0 means extrapolating towards outerScale, t > 1 towards deepScale.
  // Let's stick to standard sqrt behavior: negative gridZ will result in NaN if not handled.
  // The simplest approach is to let lerpDouble handle extrapolation based on normalizedZ directly.
  // However, the sqrt is key to the *perspective* feel.
  // Let's calculate tPerspective based on magnitude and apply sign if needed for lerp.

  // If gridZ is negative, we want to scale *up* from outerScale.
  // If gridZ is positive, we scale *down* towards deepScale.
  // The sqrt creates the non-linear perspective effect.

  // Calculate the perspective factor based on the absolute distance from 0.
  final tPerspective = sqrt(normalizedZ.abs());

  // Apply sign to tPerspective for lerpDouble to control direction.
  final signedTPerspective = normalizedZ < 0 ? -tPerspective : tPerspective;

  // Interpolate/Extrapolate between outer and deep scales
  // When signedTPerspective < 0, it extrapolates beyond outerScale.
  // When signedTPerspective > 1, it extrapolates beyond deepScale.
  return lerpDouble(outerScale, deepScale, signedTPerspective) ?? outerScale;
}

/// Defines the *nominal* Z range used for perspective scaling calculations,
/// where gridZ=0 maps to outerScale and gridZ=1 maps to deepScale.
/// Scaling will extrapolate beyond this range.
const double perspectiveNominalMinZ = 0.0;
const double perspectiveNominalMaxZ = 1.0;

// Consider if we need to expose level's outer/deep scale factors here,
// or if they should always be passed in. Passing them seems more flexible. 

/// Mixin for components that have a position within the fake 3D grid space.
///
/// Provides a common interface for accessing grid coordinates (X, Y, Z),
/// primarily intended for Z-aware collision detection.
mixin HasFakeThreeDee {
  /// The position along the path or primary horizontal axis in grid space.
  double get grid_x;

  /// The height or vertical offset from the path/plane in grid space.
  /// Implementations should return 0.0 if the concept is not applicable.
  double get grid_y;

  /// The depth position in grid space (0.0=foreground, 1.0=nominal background).
  /// Implementations should return 0.0 if the concept is not applicable.
  double get grid_z;
} 
