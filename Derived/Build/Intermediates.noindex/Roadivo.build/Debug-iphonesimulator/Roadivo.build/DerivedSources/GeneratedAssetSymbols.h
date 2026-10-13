#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.example.roadivo";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "Asphalt" asset catalog color resource.
static NSString * const ACColorNameAsphalt AC_SWIFT_PRIVATE = @"Asphalt";

/// The "CanvasBackground" asset catalog color resource.
static NSString * const ACColorNameCanvasBackground AC_SWIFT_PRIVATE = @"CanvasBackground";

/// The "LaneYellow" asset catalog color resource.
static NSString * const ACColorNameLaneYellow AC_SWIFT_PRIVATE = @"LaneYellow";

/// The "LaunchBackground" asset catalog color resource.
static NSString * const ACColorNameLaunchBackground AC_SWIFT_PRIVATE = @"LaunchBackground";

/// The "LiveRed" asset catalog color resource.
static NSString * const ACColorNameLiveRed AC_SWIFT_PRIVATE = @"LiveRed";

/// The "SurfaceBackground" asset catalog color resource.
static NSString * const ACColorNameSurfaceBackground AC_SWIFT_PRIVATE = @"SurfaceBackground";

/// The "SurfaceElevated" asset catalog color resource.
static NSString * const ACColorNameSurfaceElevated AC_SWIFT_PRIVATE = @"SurfaceElevated";

#undef AC_SWIFT_PRIVATE
