#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "MenuBarIcon" asset catalog image resource.
static NSString * const ACImageNameMenuBarIcon AC_SWIFT_PRIVATE = @"MenuBarIcon";

/// The "chatgpt" asset catalog image resource.
static NSString * const ACImageNameChatgpt AC_SWIFT_PRIVATE = @"chatgpt";

/// The "claude" asset catalog image resource.
static NSString * const ACImageNameClaude AC_SWIFT_PRIVATE = @"claude";

/// The "duckduckgo" asset catalog image resource.
static NSString * const ACImageNameDuckduckgo AC_SWIFT_PRIVATE = @"duckduckgo";

/// The "gemini" asset catalog image resource.
static NSString * const ACImageNameGemini AC_SWIFT_PRIVATE = @"gemini";

/// The "google" asset catalog image resource.
static NSString * const ACImageNameGoogle AC_SWIFT_PRIVATE = @"google";

/// The "kagi" asset catalog image resource.
static NSString * const ACImageNameKagi AC_SWIFT_PRIVATE = @"kagi";

/// The "perplexity" asset catalog image resource.
static NSString * const ACImageNamePerplexity AC_SWIFT_PRIVATE = @"perplexity";

#undef AC_SWIFT_PRIVATE
