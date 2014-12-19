/*	SwordModule.mm - Sword API wrapper for Modules.

	Copyright 2008 Manfred Bergmann
	Based on code by Will Thimbleby

	This program is free software; you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
	even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details. (http://www.gnu.org/licenses/gpl.html)
*/

#import "SwordModule.h"
#import "rtfhtml.h"
#import "utils.h"
#import "SwordManager.h"
#import "globals.h"
#import "PSModuleController.h"
#import "PSLanguageCode.h"
#import "PSBookmarks.h"

@interface SwordModule (/* Private, class continuation */)
/** private property */
@property(readwrite, retain) NSMutableDictionary *configEntries;
@end

@interface SwordModule (PrivateAPI)

- (void)mainInit;

@end

@implementation SwordModule (PrivateAPI)

- (void)mainInit {
    // set type
    [self setType:[SwordModule moduleTypeForModuleTypeString:[self typeString]]];
	// set category
	[self setCat:[SwordModule moduleCategoryForModuleCategoryString:[self configEntryForKey:SWMOD_CONFENTRY_CATEGORY]]];
    // init lock
    self.moduleLock = [[NSRecursiveLock alloc] init];
    self.indexLock = [[NSLock alloc] init];
    // nil values
    self.configEntries = [NSMutableDictionary dictionary];
    // set name
    self.name = [NSString stringWithCString:swModule->getName() encoding:NSUTF8StringEncoding];
}

@end

@implementation SwordModule

// -------------- property implementations -----------------
@synthesize configEntries;
@synthesize type;
@synthesize cat;
@synthesize status;
@synthesize moduleLock;
@synthesize indexLock;
@synthesize swManager;
@synthesize name;

/**
 \brief maps type string to ModuleType enum
 @param[in] typeStr type String as in -moduleType(SwordModule)
 @return type according to ModuleType enum
 */
+ (ModuleType)moduleTypeForModuleTypeString:(NSString *)typeStr {
	ModuleType ret = bible;
    
    if(typeStr == nil) {
        ALog(@"have a nil typeStr!");
        return ret;
    }
    
    if([typeStr isEqualToString:SWMOD_CATEGORY_BIBLES]) {
        ret = bible;
    } else if([typeStr isEqualToString:SWMOD_CATEGORY_COMMENTARIES]) {
        ret = commentary;
    } else if([typeStr isEqualToString:SWMOD_CATEGORY_DICTIONARIES]) {
        ret = dictionary;
    } else if([typeStr isEqualToString:SWMOD_CATEGORY_GENBOOKS]) {
        ret = genbook;
    }
    
    return ret;
}

+ (ModuleCategory)moduleCategoryForModuleCategoryString:(NSString *)catStr
{
	ModuleCategory ret = undefinedCategory;
	
	if(!catStr)
		return ret;
	
	if([catStr isEqualToString:SWMOD_CATEGORY_CULTS]) {
		ret = cult;
	} else if([catStr isEqualToString:SWMOD_CATEGORY_ESSAYS]) {
		ret = essay;
	} else if([catStr isEqualToString:SWMOD_CATEGORY_GLOSSARIES]) {
		ret = glossary;
	} else if([catStr isEqualToString:SWMOD_CATEGORY_DAILYDEVS]) {
		ret = devotional;
	}
	
	return ret;
}

+ (NSString *)moduleCategoryStringForModuleCategory:(ModuleCategory)cat
{
	NSString *ret = nil;
	
	if(((cat & glossary) == glossary)) {
		ret = SWMOD_CATEGORY_GLOSSARIES;
	} else if((cat & devotional) == devotional) {
		ret = SWMOD_CATEGORY_DAILYDEVS;
	} else if((cat & essay) == essay) {
		ret = SWMOD_CATEGORY_ESSAYS;
	} else if((cat & cult) == cult) {
		ret = SWMOD_CATEGORY_CULTS;
	}
	
	return ret;
}

+ (NSString *)moduleTypeStringForModuleType:(ModuleType)type {
	NSString *ret = SWMOD_CATEGORY_BIBLES;
    
	if(((type & bible) == bible)) {
		ret = SWMOD_CATEGORY_BIBLES;
	} else if(((type & commentary) == commentary)) {
		ret = SWMOD_CATEGORY_COMMENTARIES;
	} else if(((type & dictionary) == dictionary)) {
		ret = SWMOD_CATEGORY_DICTIONARIES;
	} else if(((type & genbook) == genbook)) {
		ret = SWMOD_CATEGORY_GENBOOKS;
	}
    
    return ret;
}

// initalises the module from a manager
- (id)initWithName:(NSString *)aName swordManager:(SwordManager *)aManager {
    self = [super init];
	if(self) {
        // get the sword module
		swModule = [aManager getSWModuleWithName:aName];
        // set manager
        self.swManager = aManager;
        
        // main init
        [self mainInit];
	}
	
	return self;
}

- (id)initWithSWModule:(sword::SWModule *)aModule {
    return [self initWithSWModule:aModule swordManager:nil];
}

/** init with given SWModule */
- (id)initWithSWModule:(sword::SWModule *)aModule swordManager:(SwordManager *)aManager {    
    self = [super init];
    if(self) {
        // copy the module instance
        swModule = aModule;
        // init with nil and whenever it is used within here, use the default manager
        self.swManager = aManager;
        
        // main init
        [self mainInit];
    }
    
    return self;
}

/**
 gc will cleanup
 */
- (void)finalize {    
	[super finalize];
}

- (void)dealloc {
	[configEntries release];
	[swManager release];
	[moduleLock release];
	[indexLock release];
	[name release];
	//if(swModule != nil)
	//	delete swModule;
	[super dealloc];
}

- (void)aquireModuleLock {
    [moduleLock lock];
}

- (void)releaseModuleLock {
    [moduleLock unlock];
}

- (void)setPreferences {
	if(swManager) {
		BOOL redLetter = GetBoolPrefForMod(DefaultsRedLetterPreference, self.name);
		BOOL strongs = GetBoolPrefForMod(DefaultsStrongsPreference, self.name);
		BOOL morphs = GetBoolPrefForMod(DefaultsMorphPreference, self.name);
		BOOL greekAccents = GetBoolPrefForMod(DefaultsGreekAccentsPreference, self.name);
		BOOL HVP = GetBoolPrefForMod(DefaultsHVPPreference, self.name);
		BOOL hebrewCantillation = GetBoolPrefForMod(DefaultsHebrewCantillationPreference, self.name);
		BOOL scriptRefs = GetBoolPrefForMod(DefaultsScriptRefsPreference, self.name);
		BOOL footnotes = GetBoolPrefForMod(DefaultsFootnotesPreference, self.name);
		BOOL headings = GetBoolPrefForMod(DefaultsHeadingsPreference, self.name);
		BOOL glosses = GetBoolPrefForMod(DefaultsGlossesPreference, self.name);
		
		[swManager setGlobalOption: SW_OPTION_SCRIPTREFS value: ((scriptRefs) ? SW_ON : SW_OFF)];
		[swManager setGlobalOption: SW_OPTION_STRONGS value: ((strongs) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_MORPHS value: ((morphs) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_HEADINGS value: ((headings) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_FOOTNOTES value: ((footnotes) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_GLOSSES value: ((glosses) ? SW_ON : SW_OFF)];
		[swManager setGlobalOption: SW_OPTION_REDLETTERWORDS value: ((redLetter) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_VARIANTS value: SW_OPTION_VARIANTS_PRIMARY ];//could make this an option?
		[swManager setGlobalOption: SW_OPTION_GREEKACCENTS value: ((greekAccents) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_HEBREWPOINTS value: ((HVP) ? SW_ON : SW_OFF) ];
		[swManager setGlobalOption: SW_OPTION_HEBREWCANTILLATION value: ((hebrewCantillation) ? SW_ON : SW_OFF) ];
	}
}

- (void)resetPreferences {
	// warning:: this will remove all the module-specific preferences for this module!
	
	RemovePrefForMod(DefaultsRedLetterPreference, self.name);
	RemovePrefForMod(DefaultsStrongsPreference, self.name);
	RemovePrefForMod(DefaultsMorphPreference, self.name);
	RemovePrefForMod(DefaultsGreekAccentsPreference, self.name);
	RemovePrefForMod(DefaultsHVPPreference, self.name);
	RemovePrefForMod(DefaultsHebrewCantillationPreference, self.name);
	RemovePrefForMod(DefaultsScriptRefsPreference, self.name);
	RemovePrefForMod(DefaultsFootnotesPreference, self.name);
	RemovePrefForMod(DefaultsHeadingsPreference, self.name);
	RemovePrefForMod(DefaultsGlossesPreference, self.name);
	
	RemovePrefForMod(DefaultsFontSizePreference, self.name);
	RemovePrefForMod(DefaultsFontNamePreference, self.name);
}

#pragma mark - convenience methods

- (NSString *)fullAboutText {
	return [self fullAboutText:nil];
}

- (NSString *)fullAboutText:(NSString*)currentVersionString {
    NSMutableString *ret = [[[NSMutableString alloc] init] autorelease];
    
    // module name
	[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleName", @""), [self name]];
	
    // module description
	[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleDescription", @""), [self descr]];
	
	// module locked status
	if([self isLocked]) {
		[ret appendFormat:@"<p><b>%@</b></p>", NSLocalizedString(@"AboutModuleLocked", @"")];
	}
    
	// module LCSH -- Library of Congress Subject Heading
	NSString *lcsh = [self configEntryForKey:@"LCSH"];
	if(lcsh)
		[ret appendFormat:@"<p><b>%@</b><br />&nbsp; &nbsp; &nbsp; %@</p>", NSLocalizedString(@"AboutModuleLCSH", @"Library of Congress Subject Heading"), lcsh];
    
    // module type
	[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleType", @""), [self typeString]];
    
    // module lang
	[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleLang", @""), [self langString]];
    
    // module version
	if(currentVersionString) {
		[ret appendFormat:@"<p><b>%@</b>%@<br /><i><b>%@</b>%@</i></p>", NSLocalizedString(@"AboutModuleVersion", @""), [self version], NSLocalizedString(@"AboutModuleCurrentVersion", @""), currentVersionString];
	} else {
		[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleVersion", @""), [self version]];
	}
	
	// module licence info
	NSString *licence = [self configEntryForKey:@"DistributionLicense"];
	if(licence)
		[ret appendFormat:@"<p><b>%@</b>%@</p>", NSLocalizedString(@"AboutModuleLicence", @""), licence];
    
	//
	// Features that this module supports:
	//
	NSMutableString *featuresAboutString = [@"" mutableCopy];
	if([self hasFeature: SWMOD_FEATURE_STRONGS] || [self hasFeature: SWMOD_CONF_FEATURE_STRONGS])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsStrongsNumbers", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_MORPH])//contains Morphological tags
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsMorphTags", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_FOOTNOTES])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsFootnotes", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_HEADINGS]) //not currently supported in PocketSword
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsHeadings", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_REDLETTERWORDS])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsRedLetterWords", @"")];
	
//	if([self hasFeature: SWMOD_FEATURE_VARIANTS]) //not currently supported in PocketSword
//		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsVariants", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_GREEKACCENTS])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsGreekAccents", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_SCRIPTREF])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsScriptref", @"")];
	
//	if([self hasFeature: SWMOD_FEATURE_LEMMA])
//		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsLemma", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_CANTILLATION])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsCantillation", @"")];
	
	if([self hasFeature: SWMOD_FEATURE_HEBREWPOINTS])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsHebrewPoints", @"")];
	
	if([self hasFeature: @"MorphSegmentation"])//morpheme segmented Hebrew
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsMorphSegmentation", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_GREEKDEF])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsGreekDef", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_HEBREWDEF])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsHebrewDef", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_GREEKPARSE])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsGreekParse", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_HEBREWPARSE])//CrossWire doesn't currently have any mod with this in it!
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsHebrewParse", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_DAILYDEVOTION])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsDailyDevotion", @"")];
	
	if([self hasFeature: SWMOD_CONF_FEATURE_IMAGES])
		[featuresAboutString appendFormat: @"&#8226; %@<br />", NSLocalizedString(@"AboutModuleContainsImages", @"")];

	if(![featuresAboutString isEqualToString:@""]) {
		[ret appendFormat: @"<p><b>%@</b><br />", NSLocalizedString(@"AboutModuleFeaturesTitle", @"")];
		[ret appendString: featuresAboutString];
		[ret appendString: @"</p>"];
	}
	[featuresAboutString release];
	
    // module about
	[ret appendString:[NSString stringWithFormat:@"<p><b>%@</b><br />%@</p>", NSLocalizedString(@"AboutModuleAboutText", @""), [self aboutText]]];
	
	[ret appendString: @"<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"];

    return ret;
}

- (NSInteger)error {
    return swModule->Error();
}

- (NSString *)descr {
	NSString *res = [NSString stringWithCString:swModule->getDescription() encoding:NSUTF8StringEncoding];
	if(!res) {
		res = [NSString stringWithCString:swModule->getDescription() encoding:NSISOLatin1StringEncoding];
	}
	return res;
}

- (NSString *)lang {
    NSString *str = [NSString stringWithCString:swModule->getLanguage() encoding:NSUTF8StringEncoding];
    if(!str) {
        str = [NSString stringWithCString:swModule->getLanguage() encoding:NSISOLatin1StringEncoding];
	}
	return str;
}

- (NSString *)langString {
	PSLanguageCode *lang = [[PSLanguageCode alloc] initWithCode:[self lang]];
	NSString *ret = [NSString stringWithString:[lang descr]];
	[lang release];
	return ret;
}

- (NSString *)typeString {
    NSString *str = [NSString stringWithCString:swModule->getType() encoding:NSUTF8StringEncoding];
    if(!str) {
        str = [NSString stringWithCString:swModule->getType() encoding:NSISOLatin1StringEncoding];
    }
    return str;
}

- (NSString *)cipherKey {
    NSString *cipherKey = [configEntries objectForKey:SWMOD_CONFENTRY_CIPHERKEY];
    if(cipherKey == nil) {
        cipherKey = [self configEntryForKey:SWMOD_CONFENTRY_CIPHERKEY];
        if(cipherKey != nil) {
            [configEntries setObject:cipherKey forKey:SWMOD_CONFENTRY_CIPHERKEY];
		} else {
			NSMutableDictionary	*cipherKeys = [NSMutableDictionary dictionaryWithDictionary:[userDefaults objectForKey:DefaultsModuleCipherKeysKey]];
			cipherKey = [cipherKeys objectForKey:[self name]];
			if(cipherKey != nil) {
				[configEntries setObject:cipherKey forKey:SWMOD_CONFENTRY_CIPHERKEY];
			}
		}
    }
		
    return cipherKey;
}

- (NSString *)version {
    NSString *version = [configEntries objectForKey:SWMOD_CONFENTRY_VERSION];
    if(version == nil) {
        version = [self configEntryForKey:SWMOD_CONFENTRY_VERSION];
        if(version != nil) {
            [configEntries setObject:version forKey:SWMOD_CONFENTRY_VERSION];
        }
    }
    if(!version) {
		version = NSLocalizedString(@"AboutModuleVersionUnspecified", @"");
	}
    return version;
}

- (NSString *)minVersion {
    NSString *minVersion = [configEntries objectForKey:SWMOD_CONFENTRY_MINVERSION];
    if(minVersion == nil) {
        minVersion = [self configEntryForKey:SWMOD_CONFENTRY_MINVERSION];
        if(minVersion != nil) {
            [configEntries setObject:minVersion forKey:SWMOD_CONFENTRY_MINVERSION];
        }
    }
    
    return minVersion;
}

/** Install Size in config */
- (NSString *)installSize {
    NSString *installSize = [configEntries objectForKey:SWMOD_CONFENTRY_INSTALLSIZE];
    if(!installSize) {
        installSize = [self configEntryForKey:SWMOD_CONFENTRY_INSTALLSIZE];
        if(installSize) {
            [configEntries setObject:installSize forKey:SWMOD_CONFENTRY_INSTALLSIZE];
        }
    }
	
	if(installSize) {
		//convert to be in format x.yMB or x.yKB instead of in bytes
		float size = [installSize floatValue];
		if(size == 0.0)
			return nil;
		size /= 1024.0;
		if(size >= 1.0) {
			// more than 1KB:
			size /= 1024.0;
			if(size >= 1.0) {
				// more than 1MB:
				installSize = [NSString stringWithFormat:@"%.2f MB", size];
			} else {
				// more than 1KB, less than 1MB:
				installSize = [NSString stringWithFormat:@"%.2f KB", (size*1024)];
			}
		} else {
			// less than 1KB:
			installSize = [NSString stringWithFormat:@"%@ Bytes", installSize];
		}
	}
	if(!installSize)
		return @"";
    
    return installSize;
}

- (BOOL)charIsDigit:(unichar)c
{
	if( c == '0' || c == '1' || c == '2' || c == '3' || c == '4' || c == '5' || c == '6' || c == '7' || c == '8' || c == '9' )
		return YES;
	return NO;
}

/** this might be RTF string  but the return value will be converted to UTF8 */
- (NSString *)aboutText {
    NSMutableString *aboutText = [configEntries objectForKey:SWMOD_CONFENTRY_ABOUT];
    if(aboutText == nil) {
        aboutText = [[[self configEntryForKey:SWMOD_CONFENTRY_ABOUT] mutableCopy] autorelease];
        if(aboutText != nil) {
			//search & replace the RTF markup:
			// "\\qc"		- for centering							--->>>  ignore these
			// "\\pard"		- for resetting paragraph attributes	--->>>  ignore these
			// "\\par"		- for paragraph breaks					--->>>  honour these
			// "\\u{num}?"	- for unicode characters				--->>>  honour these
			[aboutText replaceOccurrencesOfString:@"\\qc" withString:@"" options:0 range:NSMakeRange(0, [aboutText length])];
			[aboutText replaceOccurrencesOfString:@"\\pard" withString:@"" options:0 range:NSMakeRange(0, [aboutText length])];
			[aboutText replaceOccurrencesOfString:@"\\par" withString:@"<br />" options:0 range:NSMakeRange(0, [aboutText length])];

			NSMutableString *retStr = [[@"" mutableCopy] autorelease];
			for(NSUInteger i=0; i<[aboutText length]; i++) {
				unichar c = [aboutText characterAtIndex:i];

				if(c == '\\' && ((i+1) < [aboutText length])) {
					unichar d = [aboutText characterAtIndex:(i+1)];
					if (d == 'u') {
						//we have an unicode character!
						@try {
							NSUInteger unicodeChar = 0;
							NSMutableString *unicodeCharString = [[@"" mutableCopy] autorelease];
							int j = 0;
							BOOL negative = NO;
							if ([aboutText characterAtIndex:(i+2)] == '-') {
								//we have a negative unicode char
								negative = YES;
								j++;//skip past the '-'
							}
							while(isdigit([aboutText characterAtIndex:(i+2+j)])) {
								[unicodeCharString appendFormat:@"%C", [aboutText characterAtIndex:(i+2+j)]];
								j++;
							}
							unicodeChar = [unicodeCharString integerValue];
							if (negative) unicodeChar = 65536 - unicodeChar;
							i += j+2;
							[retStr appendFormat:@"%u", unicodeChar];
						}
						@catch (NSException * e) {
							[retStr appendFormat:@"%C", c];
						}
						//end dealing with the unicode character.
					} else {
						[retStr appendFormat:@"%C", c];
					}
				} else {
					[retStr appendFormat:@"%C", c];
				}
			}
			
			//NSLog(@"\naboutText: %@", retStr);
            [configEntries setObject:retStr forKey:SWMOD_CONFENTRY_ABOUT];
			aboutText = retStr;
        }
    }
    
    return aboutText;    
}

/** versification scheme in config */
- (NSString *)versification {
    NSString *versification = [configEntries objectForKey:SWMOD_CONFENTRY_VERSIFICATION];
    if(versification == nil) {
        versification = [self configEntryForKey:SWMOD_CONFENTRY_VERSIFICATION];
        if(versification != nil) {
            [configEntries setObject:versification forKey:SWMOD_CONFENTRY_VERSIFICATION];
        }
    }
    
    // if still nil, use KJV versification
    if(versification == nil) {
        versification = @"KJV";
    }
    
    return versification;
}

- (BOOL)isEditable {
    BOOL ret = NO;
    NSString *editable = [configEntries objectForKey:SWMOD_CONFENTRY_EDITABLE];
    if(editable == nil) {
        editable = [self configEntryForKey:SWMOD_CONFENTRY_EDITABLE];
        if(editable != nil) {
            [configEntries setObject:editable forKey:SWMOD_CONFENTRY_EDITABLE];
        }
    }
    
    if(editable) {
        if([editable isEqualToString:@"YES"]) {
            ret = YES;
        }
    }
    
    return ret;
}

- (BOOL)isPersonalCommentary {
    BOOL ret = NO;
    NSString *modDrv = [configEntries objectForKey:SWMOD_CONFENTRY_MODDRV];
    if(modDrv == nil) {
        modDrv = [self configEntryForKey:SWMOD_CONFENTRY_MODDRV];
        if(modDrv != nil) {
            [configEntries setObject:modDrv forKey:SWMOD_CONFENTRY_MODDRV];
        }
    }
    
    if(modDrv) {
        if([modDrv isEqualToString:SWMOD_CONF_MODDRV]) {
            ret = YES;
        }
    }
    
    return ret;
}

- (BOOL)isRTL {
    BOOL ret = NO;
    NSString *direction = [configEntries objectForKey:SWMOD_CONFENTRY_DIRECTION];
    if(direction == nil) {
        direction = [self configEntryForKey:SWMOD_CONFENTRY_DIRECTION];
        if(direction != nil) {
            [configEntries setObject:direction forKey:SWMOD_CONFENTRY_DIRECTION];
        }
    }
    
    if(direction) {
        if([direction isEqualToString:SW_DIRECTION_RTL]) {
            ret = YES;
        }
    }
    
    return ret;    
}

- (BOOL)isUnicode {    
    return swModule->isUnicode();
}

- (BOOL)isEncrypted {
    BOOL encrypted = YES;
    if([self cipherKey] == nil) {
        encrypted = NO;
    }
    
    return encrypted;
}

/** is module locked/has cipherkey config entry but cipherkey entry is empty */
- (BOOL)isLocked {
    BOOL locked = NO;
    NSString *key = [self cipherKey];
    if(key != nil) {
        // check user defaults, that's where we store the entered keys
        NSDictionary *cipherKeys = [userDefaults objectForKey:DefaultsModuleCipherKeysKey];
        if([key length] == 0 && [[cipherKeys allKeys] containsObject:[self name]] == NO) {
            locked = YES;
        }
    }
    
    return locked;
}

- (BOOL)unlock:(NSString *)unlockKey {
    
	if (![self isEncrypted]) {
		return NO;
    }
    
    NSMutableDictionary	*cipherKeys = [NSMutableDictionary dictionaryWithDictionary:[userDefaults objectForKey:DefaultsModuleCipherKeysKey]];
	if(unlockKey)
		[cipherKeys setObject:unlockKey forKey:[self name]];
	else
		[cipherKeys removeObjectForKey:[self name]];
    [userDefaults setObject:cipherKeys forKey:DefaultsModuleCipherKeysKey];
    
	[swManager setCipherKey:unlockKey forModuleNamed:[self name]];
    
	return YES;
}
- (id)attributeValueForEntryData:(NSDictionary *)data {
	return [self attributeValueForEntryData:data cleanFeed:NO];
}

- (id)attributeValueForEntryData:(NSDictionary *)data cleanFeed:(BOOL)clean {

    id ret = nil;
    
    // first set module to key
    [moduleLock lock];
	[self setPreferences];
	if(clean) {
		[swManager setGlobalOption: SW_OPTION_STRONGS value: SW_OFF ];
		[swManager setGlobalOption: SW_OPTION_MORPHS value: SW_OFF ];
		[swManager setGlobalOption: SW_OPTION_HEADINGS value: SW_OFF ];
		[swManager setGlobalOption: SW_OPTION_FOOTNOTES value: SW_OFF ];
		[swManager setGlobalOption: SW_OPTION_SCRIPTREFS value: SW_OFF ];
	}
    NSString *passage = [data objectForKey:ATTRTYPE_PASSAGE];
    if(passage) {
        passage = [[passage stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    } 
    NSString *attrType = [data objectForKey:ATTRTYPE_TYPE];
    if([attrType isEqualToString:@"n"]) {
        if([self isUnicode]) {
            swModule->setKey([passage UTF8String]);
        } else {
            swModule->setKey([passage cStringUsingEncoding:NSISOLatin1StringEncoding]);
        }
        //swModule->RenderText(); // force processing of key
        swModule->stripText(); // force processing of key
        
        sword::SWBuf footnoteText = swModule->getEntryAttributes()["Footnote"][[[data objectForKey:ATTRTYPE_VALUE] UTF8String]]["body"].c_str();
        // convert from base markup to display markup
        //char *fText = (char *)swModule->StripText(footnoteText);
		sword::SWBuf fText = swModule->renderText(footnoteText);
        ret = [NSString stringWithUTF8String:fText.c_str()];
    } else if([attrType isEqualToString:@"x"]) {
        if([self isUnicode]) {
            swModule->setKey([passage UTF8String]);
        } else {
            swModule->setKey([passage cStringUsingEncoding:NSISOLatin1StringEncoding]);
        }
        //swModule->RenderText(); // force processing of key
        swModule->stripText(); // force processing of key
        
        sword::SWBuf refList = swModule->getEntryAttributes()["Footnote"][[[data objectForKey:ATTRTYPE_VALUE] UTF8String]]["refList"];
        sword::VerseKey parser([passage UTF8String]);
        parser.setVersificationSystem([[self versification] UTF8String]);
        sword::ListKey refs = parser.parseVerseList(refList, parser, true);
        
        ret = [NSMutableArray array];
        // collect references
        for(refs = sword::TOP; !refs.popError(); refs++) {
            swModule->setKey(refs);
            if(![self error]) {
                NSString *key = [NSString stringWithUTF8String:swModule->getKeyText()];
                NSString *text = [NSString stringWithUTF8String:swModule->stripText()];
                
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
                [dict setObject:text forKey:SW_OUTPUT_TEXT_KEY];
                [dict setObject:key forKey:SW_OUTPUT_REF_KEY];
                [ret addObject:dict];
            }
        }
    } else if([attrType isEqualToString:@"scriptRef"] || [attrType isEqualToString:@"scripRef"]) {
		NSString *rawKey = [[[data objectForKey:ATTRTYPE_VALUE] stringByReplacingOccurrencesOfString:@"+"
                                                                                       withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		[self setChapter:[PSModuleController getCurrentBibleRef]];
		sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
		sword::VerseKey parser(curKey->getShortText());
		parser.setVersificationSystem([[self versification] UTF8String]);
		DLog(@"%@", rawKey);
		sword::ListKey refs = parser.parseVerseList([rawKey UTF8String], parser, true);
        
		ret = [NSMutableArray array];
		// collect references
		for(refs = sword::TOP; !refs.popError(); refs++) {
			swModule->setKey(refs);
			if(![self error]) {
				NSString *key = [NSString stringWithUTF8String:swModule->getKeyText()];
				//NSString *text = [NSString stringWithUTF8String:swModule->StripText()];
				NSString *text = [NSString stringWithUTF8String:swModule->renderText()];
				
				NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
				[dict setObject:text forKey:SW_OUTPUT_TEXT_KEY];
				[dict setObject:key forKey:SW_OUTPUT_REF_KEY];
				[ret addObject:dict];                
			}
		}
    } else if([attrType isEqualToString:@"Greek"] || [attrType isEqualToString:@"Hebrew"]) {
        NSString *key = [data objectForKey:ATTRTYPE_VALUE];        

        swModule->setKey([key UTF8String]);
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
        ret = dict;
        if(![self error]) {
            NSString *text = [NSString stringWithUTF8String:swModule->stripText()];
            
            [dict setObject:text forKey:SW_OUTPUT_TEXT_KEY];
            [dict setObject:key forKey:SW_OUTPUT_REF_KEY];            
        }        
    }
    if(clean) {
		[self setPreferences];
	}
    [moduleLock unlock];
    
    return ret;
}

- (SwordModuleTextEntry *)textEntryForKey:(NSString *)aKey textType:(TextPullType)aType {
    SwordModuleTextEntry *ret = nil;
    
    if(aKey && [aKey length] > 0) {
        [self setPositionFromKeyString:aKey];
        if(![self error]) {
            //const char *keyCStr = swModule->getKeyText();
            NSString *key = aKey;
            NSString *txt = nil;
            if(aType == TextTypeRendered) {
				txt = [NSString stringWithUTF8String:swModule->renderText()];
				if(!txt) {
					txt = [NSString stringWithCString:swModule->renderText() encoding:NSISOLatin1StringEncoding];
				}
            } else {
				txt = [NSString stringWithUTF8String:swModule->stripText()];
				if(!txt) {
					txt = [NSString stringWithCString:swModule->stripText() encoding:NSISOLatin1StringEncoding];
				}
            }
            
            // add to dict
            if(key && txt) {
                ret = [SwordModuleTextEntry textEntryForKey:key andText:txt];
            } else {
                ALog(@"nil key");
            }            
        }        
    }
    
    return ret;
}

#pragma mark - SwordModuleAccess

/** 
 number of entries
 abstract method, should be overriden by subclasses
 */
- (long)entryCount {
    return 0;
}

- (NSArray *)strippedTextEntriesForRef:(NSString *)reference {
    NSArray *ret = nil;
    
    [moduleLock lock];
    SwordModuleTextEntry *entry = [self textEntryForKey:reference textType:TextTypeStripped];
    if(entry) {
        ret = [NSArray arrayWithObject:entry];
    }
    [moduleLock unlock];    
    
    return ret;    
}

- (NSArray *)renderedTextEntriesForRef:(NSString *)reference {
    NSArray *ret = nil;
    
    [moduleLock lock];
    SwordModuleTextEntry *entry = [self textEntryForKey:reference textType:TextTypeRendered];
    if(entry) {
        ret = [NSArray arrayWithObject:entry];
    }
    [moduleLock unlock];
    
    return ret;
}

/**
 subclasses need to implement this
 */
- (void)writeEntry:(NSString *)value forRef:(NSString *)reference {
}

- (void)setKeyString:(NSString *)aKeyString {
    swModule->setKey([aKeyString UTF8String]);
}

- (NSString *)description {
    return [self name];
}

- (NSString *)renderedText {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->renderText()];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->renderText() encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)renderedTextFromString:(NSString *)aString {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->renderText([aString UTF8String])];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->renderText([aString UTF8String]) encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)strippedText {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->stripText()];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->stripText() encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)strippedTextFromString:(NSString *)aString {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->renderText([aString UTF8String])];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->renderText([aString UTF8String]) encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}


#pragma mark - lowlevel access

// general feature access
- (BOOL)hasFeature:(NSString *)feature {
	BOOL has = NO;
	
	[moduleLock lock];
	if(swModule->getConfig().has("Feature", [feature UTF8String])) {
		has = YES;
    } else if (swModule->getConfig().has("GlobalOptionFilter", [[NSString stringWithFormat:@"GBF%@", feature] UTF8String])) {
 		has = YES;
    } else if (swModule->getConfig().has("GlobalOptionFilter", [[NSString stringWithFormat:@"ThML%@", feature] UTF8String])) {
 		has = YES;
    } else if (swModule->getConfig().has("GlobalOptionFilter", [[NSString stringWithFormat:@"UTF8%@", feature] UTF8String])) {
 		has = YES;
    } else if (swModule->getConfig().has("GlobalOptionFilter", [[NSString stringWithFormat:@"OSIS%@", feature] UTF8String])) {
 		has = YES;
    } else if (swModule->getConfig().has("GlobalOptionFilter", [feature UTF8String])) {
 		has = YES;
    }
	[moduleLock unlock];
	
	return has;
}

- (BOOL)hasSearchIndex {

	NSString *test = [self configEntryForKey:@"AbsoluteDataPath"];
	test = [test stringByAppendingPathComponent: @"lucene"];
	test = [test stringByAppendingPathComponent: @"segments"];

	if ([[NSFileManager defaultManager] fileExistsAtPath: test]) {
		return YES;
	} else {
		return NO;
	}
}

- (NSMutableArray *)search:(NSString *)istr withScope:(SwordVerseKey*)scope {
	sword::ListKey results;
	NSMutableArray *retArray = [NSMutableArray arrayWithObjects: nil];
	if(scope) {
		results = swModule->search([istr UTF8String], -4, 0, [scope swVerseKey]);
	} else {
		//SwordListKey *testScope = [SwordListKey listKeyWithRef:@"matt-rev" v11n:[self versification]];
		//results = swModule->search([istr UTF8String], -4, 0, [testScope swListKey]);
		results = swModule->search([istr UTF8String], -4);
	}
	results.sort();
	if(results.Count() > 0) {
		while(!results.popError()) {
			SwordModuleTextEntry *entry = [[SwordModuleTextEntry alloc] initWithKey: [NSString stringWithUTF8String: results.getText()] andText: nil];
			[retArray addObject: entry];
			[entry release];
			results++;
		}
	}
	return retArray;
}

- (NSMutableArray *)search:(NSString *)istr {
	return [self search:istr withScope:nil];
}

/** wrapper around getConfigEntry() */
- (NSString *)configEntryForKey:(NSString *)entryKey {
	NSString *result = nil;	
    
	[moduleLock lock];
    const char *entryStr = swModule->getConfigEntry([entryKey UTF8String]);
	if(entryStr) {
		result = [NSString stringWithUTF8String:entryStr];
		if(!result) {
			result = [NSString stringWithCString:entryStr encoding:NSISOLatin1StringEncoding];
		}
    }
	[moduleLock unlock];
	
	return result;
}

- (sword::SWModule *)swModule {
	return swModule;
}

- (void)setIntroductions:(BOOL)intros {
	((sword::VerseKey *)(swModule->getKey()))->setIntros(intros);
}

- (void)setChapter:(NSString *)chapter {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);
	swModule->stripText();
}

- (NSString *)setToNextChapter {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	int c = curKey->getChapter();
	curKey->setChapter(c+1);
	//swModule->RenderText();
	swModule->stripText();
	
	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	return ref;
}

- (NSString *)setToPreviousChapter {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	int c = curKey->getChapter();
	curKey->setChapter(c-1);
	//swModule->RenderText();
	swModule->stripText();

	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	return ref;
}

- (NSInteger)getVerseMax {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	//int v = curKey->getVerseMax();
	return curKey->getVerseMax();
}

- (NSRange)findNextBlockElement:(NSString*)searchString range:(NSRange)range {
	
	NSRange currentStartRange = [searchString rangeOfString:@"<" options:0 range:range];
	if(currentStartRange.location == NSNotFound) {
		return currentStartRange;
	}
	
	NSRange currentEndRange;
	currentEndRange = [searchString rangeOfString:@">" options:0 range:NSMakeRange(currentStartRange.location, ([searchString length] - currentStartRange.location))];
	if(currentEndRange.location == NSNotFound) {
		ALog(@"\nERROR: could not find corresponding '>'");
		return currentStartRange;
	}
	
	if([searchString characterAtIndex:(currentEndRange.location-1)] == '/') {
		// not a block element, simply an empty tag.
		return [self findNextBlockElement:searchString range:NSMakeRange(currentEndRange.location, ([searchString length] - currentEndRange.location))];
	}
	
	NSRange returnRange = NSMakeRange(currentStartRange.location, (currentEndRange.location + 1 - currentStartRange.location));
	
	//DLog(@"\nFound a tag: %@", [searchString substringWithRange:returnRange]);
	
	return returnRange;
}

- (NSMutableString *)hackChapterToAccommodateBrokenLG:(NSString *)chapterString {
	
	NSMutableString *returnChapter = [NSMutableString stringWithString:chapterString];
	BOOL inLG = NO;
	NSRange currentTagRange = [self findNextBlockElement:returnChapter range:NSMakeRange(0, [returnChapter length])];
	NSString *oneTag = nil;
	NSString *twoTag = nil;
	NSString *threeTag = nil;
	NSString *fourTag = nil;
	NSString *fiveTag = nil;
	NSString *sixTag = nil;
	NSInteger oneI = 0, twoI = 0, threeI = 0, fourI = 0, fiveI = 0, sixI = 0;
	
	while(currentTagRange.location != NSNotFound) {
		// interested in: @"<blockquote class=\"lg\">"
		//		@"<div class=\"indentedLineOfWidth-"    <div class="indentedLineOfWidth
		//		@"</blockquote>"
		NSInteger newStart = currentTagRange.location + currentTagRange.length;
		NSString *currentTag = [returnChapter substringWithRange:currentTagRange];
		if([returnChapter compare:@"<blockquote class=\"lg\">" options:NSAnchoredSearch range:currentTagRange] == NSOrderedSame) {
			inLG = YES;
		} else if([returnChapter compare:@"</blockquote>" options:NSAnchoredSearch range:currentTagRange] == NSOrderedSame) {
			inLG = NO;
		} else if(!inLG && [currentTag hasPrefix:@"<div class=\"indentedLineOfWidth-"]) {
			// TODO: if the previous tag is "</span>" & it closes an empty verse highlighting span, move the blockquote to just before it.
			// TODO: if the previous tag is "</a>" from a verse number, move the blockquote to before the verse number!
			if(oneTag && [oneTag isEqualToString:@"</span>"] && threeTag && [threeTag isEqualToString:@"</a>"] && sixTag && [sixTag hasPrefix:@"<a href=\"pocketsword:versemenu:"]) {
				// highlighted verse && this is the start of the verse. insert the blockquote at the start of this verse.
				[returnChapter insertString:@"<blockquote class=\"lg\">" atIndex:sixI];
			} else if(oneTag && [oneTag isEqualToString:@"</a>"] && twoTag && [twoTag hasPrefix:@"<a href=\"pocketsword:versemenu:"]) {
				// this is the start of the verse. insert the blockquote at the start of this verse.
				[returnChapter insertString:@"<blockquote class=\"lg\">" atIndex:twoI];
			} else {
				[returnChapter insertString:@"<blockquote class=\"lg\">" atIndex:currentTagRange.location];
			}
			inLG = YES;
			newStart += [@"<blockquote class=\"lg\">" length];
		}
		sixTag = fiveTag;
		sixI = fiveI;
		fiveTag = fourTag;
		fiveI = fourI;
		fourTag = threeTag;
		fourI = threeI;
		threeTag = twoTag;
		threeI = twoI;
		twoTag = oneTag;
		twoI = oneI;
		oneTag = currentTag;
		oneI = currentTagRange.location;
		currentTagRange = [self findNextBlockElement:returnChapter range:NSMakeRange(newStart, ([returnChapter length] - newStart))];
	}
	
	return returnChapter;
}

- (NSString *)highlightVerse:(NSString *)verseHTML withClass:(NSString *)cssClass {
	
	NSString *spanOpen = [NSString stringWithFormat:@"<span class=\"highlightedVerse\" style=\"background-color:%@;color:black;\">", cssClass];
	static NSString *spanClose = @"</span>";
	NSMutableString *currentVerse = [NSMutableString stringWithString:verseHTML];
	
	// go past initial block tags & then add <span class=\"<cssClass>\"> and increment blocksOpen;
	// add </span> before any block opens or closes & then reopen the span after that.
	// close the span at the end of the verse!
	
	NSRange currentBlockRange = [self findNextBlockElement:currentVerse range:NSMakeRange(0, [currentVerse length])];
	if(currentBlockRange.location == NSNotFound) {
		[currentVerse insertString:spanOpen atIndex:0];
	} else if(currentBlockRange.location != 0) {
		[currentVerse insertString:spanOpen atIndex:0];
		currentBlockRange.location += [spanOpen length];
	} else {
		NSInteger testLoc = currentBlockRange.length;
		NSRange testRange = [self findNextBlockElement:currentVerse range:NSMakeRange(testLoc, ([currentVerse length] - testLoc))];
		//while(testRange.location == (testLoc + 1)) {
		while(testRange.location == (testLoc)) {
			// skip all consecutive blocks at start of the verse
			//testLoc += testRange.length + 1;
			testLoc += testRange.length;
			testRange = [self findNextBlockElement:currentVerse range:NSMakeRange(testLoc, ([currentVerse length] - testLoc))];
		}
		[currentVerse insertString:spanOpen atIndex:testLoc];
		NSInteger newStart = testLoc + [spanOpen length];
		currentBlockRange = [self findNextBlockElement:currentVerse range:NSMakeRange(newStart, ([currentVerse length] - newStart))];
	}
	
	while(currentBlockRange.location != NSNotFound) {
		
		[currentVerse insertString:spanClose atIndex:currentBlockRange.location];
		currentBlockRange.location += [spanClose length];
		NSInteger newStart = currentBlockRange.location + currentBlockRange.length;
		[currentVerse insertString:spanOpen atIndex:newStart];
		newStart += [spanOpen length];
		currentBlockRange = [self findNextBlockElement:currentVerse range:NSMakeRange(newStart, ([currentVerse length] - newStart))];
		
	}
	
	[currentVerse insertString:spanClose atIndex:[currentVerse length]];
	
	return currentVerse;
}

// Grabs the text for a given chapter (e.g. "Gen 1")
- (NSString *)getChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS 
{
    [moduleLock lock];

	[self setPreferences];

	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	curKey->setIntros(YES);
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);
	curKey->setVerse(0);
	
	swModule->stripText();
	NSMutableString *verses = [NSMutableString stringWithString:@""];
	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];

	//NSLog(@"ch  = %@", ch);
	NSString *ref = nil;
	NSString *thisEntry = @"";
	NSString *lastEntry = @"";
	NSString *preverseHeading;
	//NSString *interverseHeading;
	NSString *modType = [NSString stringWithUTF8String: swModule->getType()];
	NSInteger i = 0;
	BOOL vpl = GetBoolPrefForMod(DefaultsVPLPreference, self.name);
	BOOL headings = GetBoolPrefForMod(DefaultsHeadingsPreference, self.name);
	BOOL rawFile = [self isPersonalCommentary];
	
	// Grab till the end of the chapter
	do {
		thisEntry = (rawFile) ? [NSString stringWithUTF8String: swModule->getRawEntry()] : [NSString stringWithUTF8String: swModule->renderText(0, -1, true)];
		//replace *X and *N with simply X and N for xrefs and footnotes
		thisEntry = [thisEntry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
		thisEntry = [thisEntry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
		NSRange nonWhitespaceRange = [thisEntry rangeOfCharacterFromSet:[[NSCharacterSet whitespaceAndNewlineCharacterSet] invertedSet]];
		if(nonWhitespaceRange.location != NSNotFound && nonWhitespaceRange.location != 0) {
			thisEntry = [thisEntry substringFromIndex:nonWhitespaceRange.location];
		}
		
		if (![thisEntry isEqualToString: lastEntry] && ![thisEntry isEqualToString:@""]) {

			NSString  *canonicalHeading = [NSString stringWithUTF8String:swModule->getEntryAttributes()["Heading"]["0"]["canonical"].c_str()];
			if((headings || [canonicalHeading isEqualToString:@"true"])) {
				preverseHeading = [NSString stringWithUTF8String:swModule->getEntryAttributes()["Heading"]["Preverse"]["0"].c_str()];
				//interverseHeading = [NSString stringWithUTF8String:swModule->getEntryAttributes()["Heading"]["Interverse"]["0"].c_str()];
				if(preverseHeading && ![preverseHeading isEqualToString:@""]) {
					//NSLog(@"preverseHeading (i=%d) = '%@'", i, preverseHeading);
					preverseHeading = [NSString stringWithUTF8String:swModule->renderText([preverseHeading UTF8String])];
					//NSLog(@"RenderText(preverseHeading) = '%@'\n", preverseHeading);
					preverseHeading = [preverseHeading stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
					preverseHeading = [preverseHeading stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
					[verses appendFormat:@"<p><b>%@</b></p>", preverseHeading];
				}
//				else if(interverseHeading && ![interverseHeading isEqualToString:@""]) {
//					//NSLog(@"interverseHeading (i=%d) = '%@'", i, interverseHeading);
//					interverseHeading = [NSString stringWithUTF8String:swModule->renderText([interverseHeading UTF8String])];
//					interverseHeading = [interverseHeading stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
//					interverseHeading = [interverseHeading stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];
//					//NSLog(@"RenderText(interverseHeading) = '%@'\n", interverseHeading);
//					if((preverseHeading && ![preverseHeading isEqualToString:interverseHeading]) || !preverseHeading) {
//						[verses appendFormat:@"<p><b>%@</b></p>", interverseHeading];
//					}
//				}
			}
			
			if ([modType isEqualToString: SWMOD_CATEGORY_COMMENTARIES]) {
				if(i == 0) {
					[verses appendString:thisEntry];
				} else {
					[verses appendFormat: @"<p><a href=\"#verse%d\" id=\"vv%d\" class=\"verse\">%d</a><br />%@</p>\n", i, i, i, thisEntry];
				}
			} else {
				NSString *entryToAppend = thisEntry;
				// paragraphing can be annoying, as different module creators can do things differently!
				entryToAppend = [entryToAppend stringByReplacingOccurrencesOfString:@"<br /> <!P><br /><br />" withString:@"<br /> <br />"];
				entryToAppend = [entryToAppend stringByReplacingOccurrencesOfString:@"<br /><!P><br /><br />" withString:@"<br /> <br />"];
				entryToAppend = [entryToAppend stringByReplacingOccurrencesOfString:@"<br /> <!P><br /><!P><br />" withString:@"<br /> <br />"];
				entryToAppend = [entryToAppend stringByReplacingOccurrencesOfString:@"</blockquote><br />" withString:@"</blockquote>"];
				
				if(i == 0) {
					if([entryToAppend isEqualToString:@"<br />"]) {
						entryToAppend = @"";
					}
				} else if(vpl) {
					entryToAppend = [NSString stringWithFormat:@"<a href=\"pocketsword:versemenu:%d\" id=\"vv%d\" class=\"verse\">%d</a><span id=\"vvv%d\">%@</span><br />\n", i, i, i, i, entryToAppend];
				} else {
					
					BOOL insertedVerse = NO;
					if([verses hasSuffix:@"\">\n"]) {
						// if the end of verses is "\">\n", then check to see if the previous tag is a div of class "indentedLineOfWidth=X" & if so, need to move the verse a href to before that div.
						// this is found in the WEB module.
						//   Don't think we'll bother fixing this. :P
					}
					
					if([entryToAppend hasPrefix:@"<blockquote class=\"lg\">"]) {
						// if this verse starts a blockquote, we want the verse number to be within the blockquote.
						entryToAppend = [NSString stringWithFormat:@"<blockquote class=\"lg\"><a href=\"pocketsword:versemenu:%d\" id=\"vv%d\" class=\"verse\">%d</a>%@\n", i, i, i, [entryToAppend substringFromIndex:23]];
						insertedVerse = YES;
					}
					
					if(!insertedVerse) {
						entryToAppend = [NSString stringWithFormat:@"<a href=\"pocketsword:versemenu:%d\" id=\"vv%d\" class=\"verse\">%d</a>%@\n", i, i, i, entryToAppend];
					}
				}
				
				NSString *highlightColour = [PSBookmarks getHighlightRGBColourStringForBookAndChapterRef:[PSModuleController createRefString:chapter] withVerse:i];
				if(highlightColour) {
					entryToAppend = [self highlightVerse:entryToAppend withClass:highlightColour];
				}
				
				[verses appendString:entryToAppend];
			}
		}
		lastEntry = thisEntry;
		(*swModule->getKey())++;
		swModule->stripText();
		ref = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
		//NSLog(@"ref = %@ (%d)", ref, i);
		++i;
	} while ([ref isEqualToString: ch] && (swModule->getKey()->popError() != KEYERR_OUTOFBOUNDS));
	
	if([verses rangeOfString:@"<div class=\"indentedLineOfWidth-"].location != NSNotFound) {
		verses = [self hackChapterToAccommodateBrokenLG:verses];
	}
	
	if([verses rangeOfString:@"<blockquote class=\"lg\">"].location != NSNotFound && [verses rangeOfString:@"</blockquote>"].location == NSNotFound) {
		[verses appendString:@"</blockquote>"];
	}
	
	if([verses isEqualToString:@""]) {
		[verses appendFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@ (%@)</p>", NSLocalizedString(@"EmptyChapterWarning", @"This chapter is empty for this module."), ch];
	}

	[verses appendString:@"<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"];
//	if([modType isEqualToString: SWMOD_CATEGORY_BIBLES]) {
//		//only pad the bottom if it's a Bible, don't for commentaries
//		NSInteger fs = [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsFontSizePreference];
//		fs = (fs == 0) ? 14 : fs;
//		if(fs <= 17) {
//			for(int i=fs;i<18;i++) {
//				if(i!=14)
//					[verses appendString:@"<p>&nbsp;</p>"];
//			}
//		}
//	}
		
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);// Set the key back to what we had it at
	
	// add JS for navigating through the chapter.
	// NOTE: for readability, the array isn't starting at the usual '0' position, but at '1'
	//			so that versePosition[i] will be for verse 'i'
	NSString *js = [NSString stringWithFormat: @"<script type=\"text/javascript\">\n<!--\n\
					var versepos;\n\
					var det_loc_poll;\n\
					var lastSentVerse;\n\
					function findPosition(foo) {\n\
						var curtop = 0;\n\
						for (var obj = foo; obj != null; obj = obj.offsetParent) {\n\
							curtop += obj.offsetTop;\n\
						}\n\
						return curtop;\n\
					}\n\
					function currentVerse() {\n\
						var now = window.pageYOffset;\n\
						if(now < 5) return 1;\n\
						var g = (%d-1);\n\
						for(var i=1;i<%d;i++) {\n\
							if(versepos[i] > now) {\n\
								g = ((i == 1) ? 1 : (i - 1));\n\
								break;\n\
							}\n\
						}\n\
						if (g == 1) return 1;\n\
						for(var i=g;i>1;i--) {\n\
							if(versepos[i] != versepos[i-1])\n\
								return i;\n\
						}\n\
						return 1;\n\
					}\n\
					function execute(url) {\n\
						var iframe = document.createElement(\"IFRAME\");\n\
						iframe.setAttribute(\"src\", url);\n\
						document.documentElement.appendChild(iframe);\n\
						iframe.parentNode.removeChild(iframe);\n\
						iframe = null;\n\
					}\n\
					function detLoc() {\n\
						var verseToSend = currentVerse();\n\
						if(verseToSend != lastSentVerse) {\n\
							execute(\"pocketsword:currentverse:\" + verseToSend + \":\" + window.pageYOffset + \":\" + versepos[verseToSend]);\n\
							lastSentVerse = verseToSend;\n\
						}\n\
					}\n\
					function startDetLocPoll() {\n\
						stopDetLocPoll();//we don't want this running more than once, so stop previous polls first...\n\
						/*det_loc_poll = setInterval(\"detLoc()\", 1000);*/\n\
					}\n\
					function stopDetLocPoll() {\n\
						clearInterval(det_loc_poll);\n\
					}\n\
					function scrollToVerse(verse) {\n\
						//setTimeout(\"_scrollToVerse(\"+verse+\")\", 250);\n\
					}\n\
					function scrollToYOffset(iTargetY) {\n\
						iTargetY = iTargetY < 0 ? 0 : iTargetY;\n\
						var frameInterval = 20; // 20 milliseconds per frame\n\
						var totalTime = 750;\n\
						var startY = window.pageYOffset;\n\
						var d = iTargetY - startY; // total distance to scroll\n\
						var freq = Math.PI / (2 * totalTime); // frequency\n\
						var startTime = new Date().getTime();\n\
						var tmr = setInterval(\n\
							function () {\n\
								// check the time that has passed from the last frame\n\
								var elapsedTime = new Date().getTime() - startTime;\n\
								if (elapsedTime < totalTime) { // are we there yet?\n\
									var f = Math.abs(Math.sin(elapsedTime * freq));\n\
									window.scrollTo(0, Math.round(f*d) + startY);\n\
								} else {\n\
									clearInterval(tmr);\n\
									window.scrollTo(0, iTargetY);\n\
								}\n\
							}\n\
							, frameInterval);\n\
					}\n\
					function scrollToPosition(position) {\n\
						setTimeout(\"window.scrollTo(0, \"+position+\")\", 250);\n\
						//setTimeout(\"scrollToYOffset(\"+position+\")\", 250);\n\
					}\n\
					function _scrollToVerse(verse) {\n\
						if(verse == '1' || verse == '0') {\n\
							window.scrollTo(0,0);\n\
							//scrollToYOffset(0);\n\
						} else if(versepos[verse] != 0) {\n\
							window.scrollTo(0, versepos[verse]);\n\
							//scrollToYOffset(versepos[verse]);\n\
						} else {\n\
							for(var ii = verse; ii > 0; ii--) {\n\
								if(versepos[ii] != 0) {\n\
									window.scrollTo(0, versepos[ii]);\n\
									//scrollToYOffset(versepos[ii]);\n\
								}\n\
							}\n\
						}\n\
					}\n\
					function resetArrays() {\n\
						versepos = null;\n\
						versepos = new Array(%d);\n\
						var tmpstr = \"arraydump:\";\n\
						for (var i=1; i < %d; i++) {\n\
							var curobj = document.getElementById(\"vv\"+i);\n\
							versepos[i] = findPosition(curobj);\n\
							if((i != 1) && (versepos[i] == 0)) {\n\
								versepos[i] = versepos[i-1];\n\
							}\n\
							tmpstr += versepos[i] + \":\";\n\
						}\n\
						//document.location = tmpstr;\n\
						execute(tmpstr);\n\
						lastSentVerse = -1;\n\
					}\n\
					//document.addEventListener(\"touchmove\", detLoc, false);\n\
					//document.addEventListener(\"scroll\", detLoc, false);\n\
					window.onload = function() {\n\
						document.documentElement.style.webkitTouchCallout = \"none\";\n\
						resetArrays()\n\
						%@\n\
						//detLoc();\n\
					}\n-->\
					</script>\n", i, i, i, i, extraJS];
	
	
	NSString *text = [PSModuleController createHTMLString: verses usingPreferences:YES withJS: js usingModuleForPreferences:self.name fixedWidth:YES];
	if (swModule->getDirection() == sword::DIRECTION_RTL) {	// Fix RTL modules
		text = [text stringByReplacingOccurrencesOfString: @"dir=\"ltr\"" withString: @"dir=\"rtl\""];
	}
	NSString *xmlLangString = [NSString stringWithFormat:@"xml:lang=\"%@\" lang=\"%@\"", [self lang], [self lang]];
	text = [text stringByReplacingOccurrencesOfString: @"xml:lang=\"en\"" withString: xmlLangString];

	curKey->setIntros(NO);
    [moduleLock unlock];
	//DLog(@"%@", text);
	
	return text;
}

- (void)setPositionFromKeyString:(NSString *)aKeyString {
    swModule->setKey([aKeyString UTF8String]);
	//sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	//curKey->setText([aKeyString cStringUsingEncoding: NSUTF8StringEncoding]);
	//swModule->RenderText();
}

//- (void)setPositionFromVerseKey:(SwordVerseKey *)aVerseKey {
//    swModule->setKey([aVerseKey swVerseKey]);
//}

// This takes insanely long on an iPhone!
- (void)createSearchIndex {
	swModule->createSearchFramework();
}

- (void)deleteSearchIndex {
	swModule->deleteSearchFramework();
}



@end
