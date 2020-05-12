﻿include_guard( DIRECTORY )

if(TARGET_EMSCRIPTEN)

  set(DISABLE_COLLATION TRUE CACHE BOOL "UCONFIG_NO_COLLATION")

  set(DISABLE_FORMATTING TRUE CACHE BOOL "UCONFIG_NO_FORMATTING")

elseif(TARGET_EMSCRIPTEN)

  set(DISABLE_COLLATION FALSE CACHE BOOL "UCONFIG_NO_COLLATION")

  set(DISABLE_FORMATTING FALSE CACHE BOOL "UCONFIG_NO_FORMATTING")

endif(TARGET_EMSCRIPTEN)
