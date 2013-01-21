//
//  SwordVerseKey.mm
//  MacSword2
//
//  Created by Manfred Bergmann on 17.03.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SwordVerseKey.h"


@implementation SwordVerseKey

+ (id)verseKey {
    return [[[SwordVerseKey alloc] init] autorelease];
}

+ (id)verseKeyWithVersification:(NSString *)scheme {
    return [[[SwordVerseKey alloc] initWithVersification:scheme] autorelease];
}

+ (id)verseKeyWithRef:(NSString *)aRef {
    return [[[SwordVerseKey alloc] initWithRef:aRef] autorelease];
}

+ (id)verseKeyWithRef:(NSString *)aRef v11n:(NSString *)scheme {
    return [[[SwordVerseKey alloc] initWithRef:aRef v11n:scheme] autorelease];
}

+ (id)verseKeyWithSWVerseKey:(sword::VerseKey *)aVk {
    return [[[SwordVerseKey alloc] initWithSWVerseKey:aVk] autorelease];
}

+ (id)verseKeyWithSWVerseKey:(sword::VerseKey *)aVk makeCopy:(BOOL)copy {
    return [[[SwordVerseKey alloc] initWithSWVerseKey:aVk makeCopy:copy] autorelease];    
}

+ (id)verseKeyForOTForVersification:(NSString *)scheme {
	SwordVerseKey *retKey = [[[SwordVerseKey alloc] initWithVersification:scheme] autorelease];
	sword::VerseKey *vk = [retKey swVerseKey];
	vk->setPosition(sword::TOP);
	vk->setLowerBound(*vk);
	// doesn't work because MAXBOOK hasn't been implemented in versekey.cpp:1159
	// vk->setPosition(MAXBOOK); vk->setPosition(MAXCHAPTER); vk->setPosition(MAXVERSE);
	vk->setTestament(2);
	(*vk)--;
	//	---- end of workaround
	vk->setUpperBound(*vk);
	//DLog(@"\n%@", [NSString stringWithCString:vk->getRangeText() encoding:NSUTF8StringEncoding]);
	return retKey;
}

+ (id)verseKeyForNTForVersification:(NSString *)scheme {
	SwordVerseKey *retKey = [[[SwordVerseKey alloc] initWithVersification:scheme] autorelease];
	sword::VerseKey *vk = [retKey swVerseKey];
	vk->setPosition(sword::TOP);	// stupid workaround to set book, chap, and verse to 1 because setTestament doesn't follow suit and do this like setChapter and setBook do.
	vk->setTestament(2);
	vk->setLowerBound(*vk);
	vk->setPosition(sword::BOTTOM);
	vk->setUpperBound(*vk);
	
	//DLog(@"\n%@", [NSString stringWithCString:vk->getRangeText() encoding:NSUTF8StringEncoding]);
	return retKey;
}

+ (id)verseKeyForWholeBibleForVersification:(NSString *)scheme {
	SwordVerseKey *retKey = [[[SwordVerseKey alloc] initWithVersification:scheme] autorelease];
	sword::VerseKey *vk = [retKey swVerseKey];
	vk->setLowerBound(*vk);
	vk->setPosition(sword::BOTTOM);
	vk->setUpperBound(*vk);
	
	//DLog(@"\n%@", [NSString stringWithCString:vk->getRangeText() encoding:NSUTF8StringEncoding]);
	return retKey;
}

+ (id)verseKeyForWholeBook:(NSString *)aRef v11n:(NSString *)scheme {
	SwordVerseKey *retKey = [[[SwordVerseKey alloc] initWithRef:aRef v11n:scheme] autorelease];
	sword::VerseKey *vk = [retKey swVerseKey];
	vk->setChapter(1); vk->setVerse(1);
	vk->setLowerBound(*vk);
	vk->setChapter(vk->getChapterMax()); vk->setVerse(vk->getVerseMax());
	vk->setUpperBound(*vk);
	
	//DLog(@"\n%@", [NSString stringWithCString:vk->getRangeText() encoding:NSUTF8StringEncoding]);
	return retKey;
}

- (id)init {
    return [self initWithRef:nil];
}

- (id)initWithVersification:(NSString *)scheme {
    return [self initWithRef:nil v11n:scheme];
}

- (id)initWithSWVerseKey:(sword::VerseKey *)aVk {
    return [self initWithSWVerseKey:aVk makeCopy:NO];
}

- (id)initWithSWVerseKey:(sword::VerseKey *)aVk makeCopy:(BOOL)copy {
    self = [super initWithSWKey:aVk makeCopy:copy];
    if(self) {
        [self swVerseKey]->setVersificationSystem(aVk->getVersificationSystem());
    }
    return self;    
}

- (id)initWithRef:(NSString *)aRef {
    return [self initWithRef:aRef v11n:nil];
}

- (id)initWithRef:(NSString *)aRef v11n:(NSString *)scheme {
    sword::VerseKey *vk = new sword::VerseKey();            
    self = [super initWithSWKey:vk];
    if(self) {
        created = YES;
        if(scheme) {
            [self setVersification:scheme];
        }
        
        if(aRef) {
            [self setKeyText:aRef];
        }        
    }    
    
    return self;
}

- (void)finalize {
    [super finalize];
}

- (void)dealloc {
    [super dealloc];    
}

- (id)clone {
    return [SwordVerseKey verseKeyWithSWVerseKey:(sword::VerseKey *)sk];
}

- (int)index {
    return sk->getIndex();
}

- (BOOL)introductions {
    return (BOOL)((sword::VerseKey *)sk)->isIntros();
}

- (void)setIntroductions:(BOOL)flag {
    ((sword::VerseKey *)sk)->setIntros(flag);
}

- (BOOL)autoNormalize {
    return (BOOL)((sword::VerseKey *)sk)->isAutoNormalize();
}

- (void)setAutoNormalize:(BOOL)flag {
    ((sword::VerseKey *)sk)->setAutoNormalize((int)flag);
}

- (int)testament {
    return ((sword::VerseKey *)sk)->getTestament();
}

- (int)book {
    return ((sword::VerseKey *)sk)->getBook();
}

- (int)chapter {
    return ((sword::VerseKey *)sk)->getChapter();
}

- (int)verse {
    return ((sword::VerseKey *)sk)->getVerse();
}

- (void)setVKPosition:(sword::SW_POSITION)position {
    ((sword::VerseKey *)sk)->setPosition(position);
}

- (void)setTestament:(int)val {
    ((sword::VerseKey *)sk)->setTestament(val);
}

- (void)setBook:(int)val {
    ((sword::VerseKey *)sk)->setBook(val);
}

- (void)setChapter:(int)val {
    ((sword::VerseKey *)sk)->setChapter(val);
}

- (void)setVerse:(int)val {
    ((sword::VerseKey *)sk)->setVerse(val);
}

- (NSString *)bookName {
    return [NSString stringWithUTF8String:((sword::VerseKey *)sk)->getBookName()];
}

- (NSString *)osisBookName {
    return [NSString stringWithUTF8String:((sword::VerseKey *)sk)->getOSISBookName()];
}

- (NSString *)osisRef {
    return [NSString stringWithUTF8String:((sword::VerseKey *)sk)->getOSISRef()];    
}

- (void)setVersification:(NSString *)versification {
    ((sword::VerseKey *)sk)->setVersificationSystem([versification UTF8String]);
}

- (NSString *)versification {
    return [NSString stringWithUTF8String:((sword::VerseKey *)sk)->getVersificationSystem()];
}

- (sword::VerseKey *)swVerseKey {
    return (sword::VerseKey *)sk;
}

@end
