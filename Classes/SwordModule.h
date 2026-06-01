/*	SwordModule.h - Sword API wrapper for Modules.

    Copyright 2008 Manfred Bergmann
    Based on code by Will Thimbleby
  
	This program is free software; you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
	even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details. (http://www.gnu.org/licenses/gpl.html)
*/

#import "SwordModuleTextEntry.h"
#import "SwordVerseKey.h"

// NOTE: All C++ (sword::SWModule ivar, sword API includes, the
// My_SWDYNAMIC_CAST macro, and sword-typed methods) has been moved to the
// internal SwordModule+Cpp.h, imported only by .mm files. This public header
// is Foundation-only so it is safe to expose to the Swift bridging header.
// Do not re-add #include <sword...> / using sword:: / My_SWDYNAMIC_CAST here.

#define SW_OUTPUT_TEXT_KEY  @"OutputTextKey"
#define SW_OUTPUT_REF_KEY   @"OutputRefKey"

// defines for dictionary entries for passagestudy
#define ATTRTYPE_TYPE       @"type"
#define ATTRTYPE_PASSAGE    @"passage"
#define ATTRTYPE_MODULE     @"modulename"
#define ATTRTYPE_NOTENUMBER @"notenumber"
#define ATTRTYPE_ACTION     @"action"
#define ATTRTYPE_VALUE      @"value"

@class SwordManager;

typedef enum {
    TextTypeStripped = 1,
    TextTypeRendered
}TextPullType;

typedef enum {
	unknown_type = -1,
	bible       = 0x0001, 
    commentary  = 0x0002, 
    dictionary  = 0x0004,
    genbook     = 0x0008
    //devotional  = 0x0010 -- this is a ModuleCategory!
}ModuleType;

typedef enum {
	undefinedCategory	= 0x0000, 
	glossary			= 0x0001, 
	essay				= 0x0002, 
	devotional			= 0x0004, 
	cult				= 0x0008,
	errorCategory		= 0xFFFF
}ModuleCategory;

@protocol SwordModuleAccess

/** 
 number of entries
 abstract method, should be overriden by subclasses
 */
- (long)entryCount;

/**
 abstract method, override in subclass
 This method generates stripped text string for a given reference.
 @param[in] reference bible reference
 @return Array of SwordModuleTextEntry instances
 */
- (NSArray *)strippedTextEntriesForRef:(NSString *)reference;

/** 
 abstract method, override in subclass
 This method generates HTML string for a given reference.
 @param[in] reference bible reference
 @return Array of SwordModuleTextEntry instances
 */
- (NSArray *)renderedTextEntriesForRef:(NSString *)reference;

/** 
 write value to reference 
 */
- (void)writeEntry:(NSString *)value forRef:(NSString *)reference;

@end

@interface SwordModule : NSObject <SwordModuleAccess> {
    
    NSMutableDictionary *configEntries;
	ModuleType type;
	ModuleCategory cat;
    int status;
	SwordManager *swManager;	
	NSRecursiveLock *moduleLock;
    NSLock *indexLock;
    
    /** we store the name separately */
    NSString *name;
    
    /** yes, we have a delegate to report any action to */
    id delegate;

	// The sword::SWModule *swModule ivar lives in SwordModule+Cpp.h (internal).
}

// ------------- properties ---------------
@property (readwrite) ModuleType type;
@property (readwrite) ModuleCategory cat;
@property (readwrite) int status;
@property (strong, readwrite) NSRecursiveLock *moduleLock;
@property (strong, readwrite) NSLock *indexLock;
@property (copy, readwrite) NSString *name;
@property (strong, readwrite) SwordManager *swManager;

// -------------- class methods --------------
/**
 maps type string to ModuleType enum
 @param[in] typeStr type String as in -type(SwordModule)
 @return type according to ModuleType enum
 */
+ (ModuleType)moduleTypeForModuleTypeString:(NSString *)typeStr;
+ (NSString *)moduleTypeStringForModuleType:(ModuleType)type;

+ (ModuleCategory)moduleCategoryForModuleCategoryString:(NSString *)catStr;
+ (NSString *)moduleCategoryStringForModuleCategory:(ModuleCategory)cat;

// ------------- instance methods ---------------

- (id)initWithName:(NSString *)aName swordManager:(SwordManager *)aManager;
// C++ accessors (initWithSWModule:, initWithSWModule:swordManager:, swModule)
// live in SwordModule+Cpp.h, imported only by .mm files.
- (void)setPreferences;
- (void)resetPreferences;

- (NSInteger)error;
- (NSString *)descr;
- (NSString *)lang;
- (NSString *)langString;
- (NSString *)typeString;
- (NSString *)version;
- (NSString *)minVersion;
- (NSString *)aboutText;
- (NSString *)versification;
- (NSString *)fullAboutText:(NSString*)currentVersionString;
- (NSString *)fullAboutText;
- (NSString *)installSize;
- (BOOL)isUnicode;
- (BOOL)isEncrypted;
- (BOOL)isLocked;
- (BOOL)isEditable;
- (BOOL)isPersonalCommentary;
- (BOOL)isRTL;
- (BOOL)unlock:(NSString *)unlockKey;

- (void)aquireModuleLock;
- (void)releaseModuleLock;

- (BOOL)hasFeature:(NSString *)feature;
- (NSString *)configEntryForKey:(NSString *)entryKey;
- (BOOL)hasSearchIndex;

- (NSMutableArray *)search:(NSString *)istr withScope:(SwordVerseKey*)scope;
- (NSMutableArray *)search:(NSString *)istr;
- (void)setKeyString:(NSString *)aKeyString;

- (NSString *)renderedText;
- (NSString *)renderedTextFromString:(NSString *)aString;
- (NSString *)strippedText;
- (NSString *)strippedTextFromString:(NSString *)aString;


/**
 returns attribute values from the engine for notes, cross-refs and such for the given link type
 @return NSArray for references
 @return NSString for text data
 */
- (id)attributeValueForEntryData:(NSDictionary *)data;
- (id)attributeValueForEntryData:(NSDictionary *)data cleanFeed:(BOOL)clean;

- (SwordModuleTextEntry *)textEntryForKey:(NSString *)aKey textType:(TextPullType)aType;
- (NSString *)getChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS;
- (NSString *)setToNextChapter;
- (NSString *)setToPreviousChapter;
- (NSInteger)getVerseMax;
- (void)setChapter:(NSString *)chapter;
- (void)setIntroductions:(BOOL)intros;

/** Current key text (UTF-8, ISO-Latin-1 fallback). Foundation-only key getter. */
- (NSString *)keyText;
/** Sets the underlying verse key's text without re-stripping. Foundation-only. */
- (void)setVerseKeyText:(NSString *)text;

// ------- SwordModuleAccess ---------
- (NSArray *)strippedTextEntriesForRef:(NSString *)reference;
- (NSArray *)renderedTextEntriesForRef:(NSString *)reference;
- (long)entryCount;
- (void)writeEntry:(NSString *)value forRef:(NSString *)reference;

- (void)setPositionFromKeyString:(NSString *)aKeyString;
//- (void)setPositionFromVerseKey:(SwordVerseKey *)aVerseKey;

- (void)createSearchIndex;
- (void)deleteSearchIndex;

@end
