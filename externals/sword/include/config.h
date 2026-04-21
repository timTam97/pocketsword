/* include/config.h.  Generated from config.h.in by configure.  */
/* include/config.h.in.  Generated from configure.ac by autoheader.  */

/* Define if building universal (internal helper macro) */
/* #undef AC_APPLE_UNIVERSAL_BUILD */

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the `z' library (-lz). */
#define HAVE_LIBZ 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to 1 if you have the `vsnprintf' function. */
#define HAVE_VSNPRINTF 1

// PocketSword: libcurl removed alongside the in-app module download feature.
// InstallMgr's transport-creation methods are now stubbed; the local
// installModule(destMgr, fromLocation, modName) path used for bundled-zip
// unpack does not require any transport.
// #define CURLAVAILABLE 1

// PocketSword: CLucene disabled. The iOS app drives search via PSSearchEngine
// (FTS5) directly against SwordModule text; SWModule::search() and friends are
// no longer called. Leaving this undefined neutralises the CLucene include,
// using-namespace directives, and search/createSearchFramework/deleteSearch
// Framework bodies in swmodule.cpp (all gated behind `USELUCENE`).
// #define USELUCENE 1

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* Name of package */
#define PACKAGE "sword"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "sword-bugs@crosswire.org"

/* Define to the full name of this package. */
#define PACKAGE_NAME "sword"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "sword 1.6.2"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "sword"

/* Define to the home page for this package. */
#define PACKAGE_URL "http://crosswire.org/sword"

/* Define to the version of this package. */
#define PACKAGE_VERSION "1.6.2"

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Version number of package */
#define VERSION "1.6.2"

/* Define WORDS_BIGENDIAN to 1 if your processor stores words with the most
   significant byte first (like Motorola and SPARC, unlike Intel). */
#if defined AC_APPLE_UNIVERSAL_BUILD
# if defined __BIG_ENDIAN__
#  define WORDS_BIGENDIAN 1
# endif
#else
# ifndef WORDS_BIGENDIAN
/* #  undef WORDS_BIGENDIAN */
# endif
#endif
