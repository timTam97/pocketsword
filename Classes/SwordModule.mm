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
//#import "MBPreferenceController.h"
#import "PSModuleController.h"
#import "PSLanguageCode.h"

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
    indexLock = [[NSLock alloc] init];
    // nil values
    self.configEntries = [NSMutableDictionary dictionary];
    // set name
    self.name = [NSString stringWithCString:swModule->Name() encoding:NSUTF8StringEncoding];
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
	
    // module about
	[ret appendString:[NSString stringWithFormat:@"<p><b>%@</b><br />%@</p>", NSLocalizedString(@"AboutModuleAboutText", @""), [self aboutText]]];
	
	[ret appendString: @"<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"];

    return ret;
}

- (NSInteger)error {
    return swModule->Error();
}

- (NSString *)descr {
	NSString *res = [NSString stringWithCString:swModule->Description() encoding:NSUTF8StringEncoding];
	if(!res) {
		res = [NSString stringWithCString:swModule->Description() encoding:NSISOLatin1StringEncoding];
	}
	return res;
}

- (NSString *)lang {
    NSString *str = [NSString stringWithCString:swModule->Lang() encoding:NSUTF8StringEncoding];
    if(!str) {
        str = [NSString stringWithCString:swModule->Lang() encoding:NSISOLatin1StringEncoding];
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
    NSString *str = [NSString stringWithCString:swModule->Type() encoding:NSUTF8StringEncoding];
    if(!str) {
        str = [NSString stringWithCString:swModule->Type() encoding:NSISOLatin1StringEncoding];
    }
    return str;
}

- (NSString *)cipherKey {
    NSString *cipherKey = [configEntries objectForKey:SWMOD_CONFENTRY_CIPHERKEY];
    if(cipherKey == nil) {
        cipherKey = [self configEntryForKey:SWMOD_CONFENTRY_CIPHERKEY];
        if(cipherKey != nil) {
            [configEntries setObject:cipherKey forKey:SWMOD_CONFENTRY_CIPHERKEY];
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
							[retStr appendFormat:@"%C", unicodeChar];
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

    id ret = nil;
    
    // first set module to key
    [moduleLock lock];
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
        swModule->RenderText(); // force processing of key
        
        sword::SWBuf footnoteText = swModule->getEntryAttributes()["Footnote"][[[data objectForKey:ATTRTYPE_VALUE] UTF8String]]["body"].c_str();
        // convert from base markup to display markup
        char *fText = (char *)swModule->StripText(footnoteText);
        ret = [NSString stringWithUTF8String:fText];
    } else if([attrType isEqualToString:@"x"]) {
        if([self isUnicode]) {
            swModule->setKey([passage UTF8String]);
        } else {
            swModule->setKey([passage cStringUsingEncoding:NSISOLatin1StringEncoding]);
        }
        swModule->RenderText(); // force processing of key
        
        sword::SWBuf refList = swModule->getEntryAttributes()["Footnote"][[[data objectForKey:ATTRTYPE_VALUE] UTF8String]]["refList"];
        sword::VerseKey parser([passage UTF8String]);
        parser.setVersificationSystem([[self versification] UTF8String]);
        sword::ListKey refs = parser.ParseVerseList(refList, parser, true);
        
        ret = [NSMutableArray array];
        // collect references
        for(refs = sword::TOP; !refs.Error(); refs++) {
            swModule->setKey(refs);
            if(![self error]) {
                NSString *key = [NSString stringWithUTF8String:swModule->getKeyText()];
                NSString *text = [NSString stringWithUTF8String:swModule->StripText()];
                
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
                [dict setObject:text forKey:SW_OUTPUT_TEXT_KEY];
                [dict setObject:key forKey:SW_OUTPUT_REF_KEY];
                [ret addObject:dict];
            }
        }
    } else if([attrType isEqualToString:@"scriptRef"] || [attrType isEqualToString:@"scripRef"]) {
		NSString *key = [[[data objectForKey:ATTRTYPE_VALUE] stringByReplacingOccurrencesOfString:@"+" 
                                                                                       withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
		sword::VerseKey parser(curKey->getShortText());
		parser.setVersificationSystem([[self versification] UTF8String]);
		sword::ListKey refs = parser.ParseVerseList([key UTF8String], parser, true);
        
		ret = [NSMutableArray array];
		// collect references
		for(refs = sword::TOP; !refs.Error(); refs++) {
			swModule->setKey(refs);
			if(![self error]) {
				NSString *key = [NSString stringWithUTF8String:swModule->getKeyText()];
				NSString *text = [NSString stringWithUTF8String:swModule->StripText()];
				
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
            NSString *text = [NSString stringWithUTF8String:swModule->StripText()];
            
            [dict setObject:text forKey:SW_OUTPUT_TEXT_KEY];
            [dict setObject:key forKey:SW_OUTPUT_REF_KEY];            
        }        
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
				txt = [NSString stringWithUTF8String:swModule->RenderText()];
				if(!txt) {
					txt = [NSString stringWithCString:swModule->RenderText() encoding:NSISOLatin1StringEncoding];
				}
            } else {
				txt = [NSString stringWithUTF8String:swModule->StripText()];
				if(!txt) {
					txt = [NSString stringWithCString:swModule->StripText() encoding:NSISOLatin1StringEncoding];
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
    ret = [NSString stringWithUTF8String:swModule->RenderText()];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->RenderText() encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)renderedTextFromString:(NSString *)aString {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->RenderText([aString UTF8String])];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->RenderText([aString UTF8String]) encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)strippedText {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->StripText()];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->StripText() encoding:NSISOLatin1StringEncoding];
    }
    return ret;
}

- (NSString *)strippedTextFromString:(NSString *)aString {
    NSString *ret = @"";
    ret = [NSString stringWithUTF8String:swModule->RenderText([aString UTF8String])];
    if(!ret) {
        ret = [NSString stringWithCString:swModule->RenderText([aString UTF8String]) encoding:NSISOLatin1StringEncoding];
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

- (NSMutableArray *)search:(NSString *)istr {
	sword::ListKey results = swModule->search([istr UTF8String], -4);
	results.sort();
	NSMutableArray *retArray = [NSMutableArray arrayWithObjects: nil];
	if(results.Count() > 0) {
		while(!results.Error()) {
			SwordModuleTextEntry *entry = [[SwordModuleTextEntry alloc] initWithKey: [NSString stringWithUTF8String: results.getText()] andText: nil];
			[retArray addObject: entry];
			[entry release];
			results++;
		}
	}
	return retArray;
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

- (void)setChapter:(NSString *)chapter {
//	swModule->setKey([chapter cStringUsingEncoding: NSISOLatin1StringEncoding]);
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);
//	swModule->setKey([chapter cStringUsingEncoding: NSUTF8StringEncoding]);
	swModule->RenderText();
}

- (NSString *)setToNextChapter {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	int c = curKey->getChapter();
	curKey->setChapter(c+1);
	swModule->RenderText();
	
	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	return ref;
}

- (NSString *)setToPreviousChapter {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	int c = curKey->getChapter();
	curKey->setChapter(c-1);
	swModule->RenderText();

	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	return ref;
}

- (NSInteger)getVerseMax {
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	//int v = curKey->getVerseMax();
	return curKey->getVerseMax();
}


// Grabs the text for a given chapter (e.g. "Gen 1")
- (NSString *)getChapter:(NSString *)chapter withExtraJS:(NSString *)extraJS 
{
	BOOL printf = NO;//[[self typeString] isEqualToString:SWMOD_CATEGORY_BIBLES];

	if(printf) NSLog(@"SwordModule::getChapter:%@", chapter);
	sword::VerseKey *curKey = (sword::VerseKey*)swModule->getKey();
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);
	sword::SWKey lastKey;
	
	swModule->RenderText();
	NSMutableString *verses = [@"" mutableCopy];
	NSString *ch = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
	//if(printf) NSLog(@"getKeyText() = %@", [NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding]);
	//if(printf) NSLog(@"ch = %@", ch);
	NSString *ref = [NSString stringWithString: ch];
	NSString *thisEntry = @"";
	NSString *lastEntry = @"";
	NSString *preverseHeading;
	NSString *interverseHeading;
	NSString *modType = [NSString stringWithUTF8String: swModule->Type()];
	NSInteger i = 1;
	BOOL vpl = [[NSUserDefaults standardUserDefaults] boolForKey:@"vplPreference"];
	BOOL headings = [[NSUserDefaults standardUserDefaults] boolForKey:@"headingsPreference"];
	
	// Grab till the end of the chapter
	do {
		lastKey = swModule->Key();
		thisEntry = [NSString stringWithUTF8String: swModule->RenderText()];
		if(headings) {
			preverseHeading = [NSString stringWithUTF8String:swModule->getEntryAttributes()["Heading"]["Preverse"]["0"].c_str()];
			if(preverseHeading && ![preverseHeading isEqualToString:@""]) {
				//NSLog(@"preverseHeading = '%@'", preverseHeading);
				[verses appendFormat:@"<p><b>%@</b></p>", preverseHeading];
			}
			interverseHeading = [NSString stringWithUTF8String:swModule->getEntryAttributes()["Heading"]["Interverse"]["0"].c_str()];
			if(interverseHeading && ![interverseHeading isEqualToString:@""]) {
				//NSLog(@"interverseHeading = '%@'", interverseHeading);
				if(preverseHeading && ![preverseHeading isEqualToString:interverseHeading]) {
					[verses appendFormat:@"<p><b>%@</b></p>", interverseHeading];
				} else if(!preverseHeading) {
					[verses appendFormat:@"<p><b>%@</b></p>", interverseHeading];
				}
			}
		}
		//replace *X and *N with simply X and N for xrefs and footnotes
		thisEntry = [thisEntry stringByReplacingOccurrencesOfString:@"*x" withString:@"x"];
		thisEntry = [thisEntry stringByReplacingOccurrencesOfString:@"*n" withString:@"n"];

		//if(printf) NSLog(@"thisEntry (%d) = %@", i, thisEntry);
		if (![thisEntry isEqualToString: lastEntry]) {
			
			if ([modType isEqualToString: @"Commentaries"]) {
				[verses appendFormat: @"<p><a href=\"#verse%d\" id=\"vv%d\"></a>%@</p>\n", i, i, thisEntry];
			} else {
				if(vpl)
					[verses appendFormat: @"<a href=\"#verse%d\" id=\"vv%d\" class=\"verse\">%d</a>%@<br />\n", i, i, i, thisEntry];
				else
					[verses appendFormat: @"&nbsp; <a href=\"#verse%d\" id=\"vv%d\" class=\"verse\">%d</a>%@\n", i, i, i, thisEntry];
			}
		}
		lastEntry = thisEntry;
		swModule->Key()++;
		lastKey++;
		swModule->RenderText();
		ref = [[[NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding] componentsSeparatedByString: @":"] objectAtIndex: 0];
		//if(printf) NSLog(@"getKeyText() = %@", [NSString stringWithCString: swModule->getKeyText() encoding: NSUTF8StringEncoding]);
		//if(printf) NSLog(@"ref = %@", ref);
		++i;
	} while ([ref isEqualToString: ch] && (swModule->Key().Error() != KEYERR_OUTOFBOUNDS));

	if([verses isEqualToString:@""]) {
		[verses appendFormat: @"<p style=\"color:grey;text-align:center;font-style:italic;\">%@</p>", NSLocalizedString(@"EmptyChapterWarning", @"This chapter is empty for this module.")];
	}

	[verses appendString:@"<p>&nbsp;</p><p>&nbsp;</p><p>&nbsp;</p>"];
	
	if(printf) NSLog(@"verses:\n%@", verses);
	
	curKey->setText([chapter cStringUsingEncoding: NSUTF8StringEncoding]);// Set the key back to what we had it at
	
	// add JS for navigating through the chapter.
	// NOTE: for readability, the array isn't starting at the usual '0' position, but at '1'
	//			so that versePosition[i] will be for verse 'i'
	NSString *js = [NSString stringWithFormat: @"<script type=\"text/javascript\">\n<!--\n\
					var versepos;\n\
					var det_loc_poll;\n\
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
					function detLoc() {\n\
						document.location = \"pocketsword:currentverse:\" + currentVerse() + \":\" + window.pageYOffset + \":\" + versepos[currentVerse()];\n\
					}\n\
					//window.onscroll = detLoc;//this doesn't seem to work properly on the iPhone\n\
					function startDetLocPoll() {\n\
						stopDetLocPoll();//we don't want this running more than once, so stop previous polls first...\n\
						det_loc_poll = setInterval(\"detLoc()\", 1000);\n\
					}\n\
					function stopDetLocPoll() {\n\
						clearInterval(det_loc_poll);\n\
					}\n\
					function scrollToVerse(verse) {\n\
						setTimeout(\"_scrollToVerse(\"+verse+\")\", 250);\n\
					}\n\
					function scrollToPosition(position) {\n\
						setTimeout(\"window.scrollTo(0, \"+position+\")\", 250);\n\
					}\n\
					function _scrollToVerse(verse) {\n\
						if(verse == '1' || verse == '0')\n\
							window.scrollTo(0,0);\n\
						else if(versepos[verse] != 0) {\n\
							window.scrollTo(0, versepos[verse]);\n\
						} else {\n\
							for(var ii = verse; ii > 0; ii--) {\n\
								if(versepos[ii] != 0) {\n\
									window.scrollTo(0, versepos[ii]);\n\
								}\n\
							}\n\
						}\n\
					}\n\
					window.onload = function() {\n\
						document.documentElement.style.webkitTouchCallout = \"none\";\n\
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
						document.location = tmpstr;\n\
						%@\n\
					}\n-->\
					</script>\n", i, i, i, i, extraJS];
	
	
	NSString *text = [PSModuleController createHTMLString: verses withJS: js];
	[verses release];
	if (swModule->Direction() == sword::DIRECTION_RTL) {	// Fix RTL modules
		text = [text stringByReplacingOccurrencesOfString: @"dir=\"ltr\"" withString: @"dir=\"rtl\""];
	}
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
