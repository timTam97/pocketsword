//
//  PSSearchQuery.mm
//  PocketSword
//

#import "PSSearchQuery.h"

static NSString *PSBarewordForPrefix(NSString *s);

@implementation PSSearchQuery

#pragma mark - Folding (must match PSSearchEngine's PSFoldForIndex)

+ (NSString *)foldForIndex:(NSString *)s {
	if(s.length == 0) return @"";
	// NFD, then strip:
	//  * Hebrew points + cantillation (U+0591–U+05C7) — FTS5's
	//    remove_diacritics=2 doesn't touch these.
	//  * Generic Unicode combining marks (U+0300–U+036F, U+1AB0–U+1AFF,
	//    U+1DC0–U+1DFF, U+20D0–U+20FF, U+FE20–U+FE2F) — catches Greek
	//    polytonic accents and anything else that slipped past unicode61.
	NSString *decomposed = [s decomposedStringWithCanonicalMapping];
	NSMutableString *out = [NSMutableString stringWithCapacity:decomposed.length];
	for(NSUInteger i = 0; i < decomposed.length; ) {
		unichar c = [decomposed characterAtIndex:i];
		BOOL drop =
			(c >= 0x0300 && c <= 0x036F) ||
			(c >= 0x0591 && c <= 0x05C7) ||
			(c >= 0x1AB0 && c <= 0x1AFF) ||
			(c >= 0x1DC0 && c <= 0x1DFF) ||
			(c >= 0x20D0 && c <= 0x20FF) ||
			(c >= 0xFE20 && c <= 0xFE2F);
		if(!drop) {
			if(CFStringIsSurrogateHighCharacter(c) && i + 1 < decomposed.length) {
				[out appendFormat:@"%C%C", c, [decomposed characterAtIndex:i + 1]];
				i += 2;
				continue;
			}
			[out appendFormat:@"%C", c];
		}
		i += 1;
	}
	return [[out precomposedStringWithCanonicalMapping] lowercaseString];
}

#pragma mark - Tokenisation

typedef struct {
	NSString *text;   // the phrase/word content, never contains quote chars
	BOOL isPhrase;    // YES if user wrapped it in "…"
} PSToken;

// Tiny scanner: splits whitespace-separated tokens, keeping "quoted phrases"
// as single atoms. Unterminated quotes are treated as running to end of input.
static NSArray<NSValue *> *PSTokenise(NSString *raw) {
	NSMutableArray<NSValue *> *tokens = [NSMutableArray array];
	NSUInteger i = 0, n = raw.length;
	while(i < n) {
		unichar c = [raw characterAtIndex:i];
		if(c == ' ' || c == '\t' || c == '\n') { ++i; continue; }

		if(c == '"') {
			++i;
			NSUInteger start = i;
			while(i < n && [raw characterAtIndex:i] != '"') ++i;
			NSString *phrase = [raw substringWithRange:NSMakeRange(start, i - start)];
			if(i < n) ++i; // skip closing quote
			if(phrase.length > 0) {
				PSToken t = { phrase, YES };
				[tokens addObject:[NSValue valueWithBytes:&t objCType:@encode(PSToken)]];
			}
		} else {
			NSUInteger start = i;
			while(i < n) {
				unichar ch = [raw characterAtIndex:i];
				if(ch == ' ' || ch == '\t' || ch == '\n' || ch == '"') break;
				++i;
			}
			NSString *word = [raw substringWithRange:NSMakeRange(start, i - start)];
			if(word.length > 0) {
				PSToken t = { word, NO };
				[tokens addObject:[NSValue valueWithBytes:&t objCType:@encode(PSToken)]];
			}
		}
	}
	return tokens;
}

#pragma mark - Escaping

// Escape a token for use inside an FTS5 phrase: double any embedded quotes
// and wrap in "…". Phrase syntax accepts any characters literally, which
// side-steps the need to strip operator keywords like AND/OR/NEAR.
static NSString *PSQuote(NSString *s) {
	NSString *escaped = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
	return [NSString stringWithFormat:@"\"%@\"", escaped];
}

static BOOL PSIsStrongsNumber(NSString *s, char *outPrefix) {
	if(s.length < 2) return NO;
	unichar p = [s characterAtIndex:0];
	if(p != 'H' && p != 'G' && p != 'h' && p != 'g') return NO;
	for(NSUInteger i = 1; i < s.length; ++i) {
		unichar c = [s characterAtIndex:i];
		if(c < '0' || c > '9') return NO;
	}
	if(outPrefix) *outPrefix = (p == 'h' || p == 'H') ? 'H' : 'G';
	return YES;
}

// For an H-prefixed Strong's number, return the OTHER form (H0430 ↔ H430).
// Returns nil if the input is G-prefixed or already ambiguous.
static NSString *PSAlternateHebrewForm(NSString *s) {
	if(s.length < 2) return nil;
	unichar p = [s characterAtIndex:0];
	if(p != 'H' && p != 'h') return nil;
	NSString *digits = [s substringFromIndex:1];
	if([digits hasPrefix:@"0"]) {
		return [@"H" stringByAppendingString:[digits substringFromIndex:1]];
	}
	return [@"H0" stringByAppendingString:digits];
}

#pragma mark - Expression builder

+ (NSString *)fts5ExpressionFromUserInput:(NSString *)raw
								matchType:(PSSearchType)matchType
									fuzzy:(BOOL)fuzzy
								  strongs:(BOOL)strongs {
	if(raw.length == 0) return nil;
	NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(trimmed.length == 0) return nil;

	// Strong's mode: short-circuit — every whitespace-separated token is
	// treated as a Strong's number and mapped to the lemmas: column with
	// H0/H equivalence. Non-conforming tokens pass through as plain terms.
	if(strongs) {
		NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		NSMutableArray<NSString *> *ors = [NSMutableArray array];
		for(NSString *tok in parts) {
			if(tok.length == 0) continue;
			char prefix = 0;
			if(PSIsStrongsNumber(tok, &prefix)) {
				NSString *upper = [NSString stringWithFormat:@"%c%@", prefix, [tok substringFromIndex:1]];
				NSString *alt = PSAlternateHebrewForm(upper);
				if(alt) {
					[ors addObject:[NSString stringWithFormat:@"(%@ OR %@)", PSQuote(upper), PSQuote(alt)]];
				} else {
					[ors addObject:PSQuote(upper)];
				}
			} else {
				[ors addObject:PSQuote(tok)];
			}
		}
		if(ors.count == 0) return nil;
		// Join with OR so a multi-number Strong's query (rare but possible)
		// matches any of them. Constrain to the lemmas column.
		NSString *joined = [ors componentsJoinedByString:@" OR "];
		return [NSString stringWithFormat:@"lemmas:(%@)", joined];
	}

	// Exact mode: treat the whole raw input as a single phrase (strip any
	// surrounding quotes the user typed so we don't double-wrap).
	if(matchType == ExactSearch) {
		NSString *body = trimmed;
		if([body hasPrefix:@"\""] && [body hasSuffix:@"\""] && body.length >= 2) {
			body = [body substringWithRange:NSMakeRange(1, body.length - 2)];
		}
		if(body.length == 0) return nil;
		NSString *folded = [self foldForIndex:body];
		return [NSString stringWithFormat:@"text_norm:%@", PSQuote(folded)];
	}

	// All / Any modes: tokenise, fold each non-phrase, apply fuzzy if set.
	NSArray<NSValue *> *tokens = PSTokenise(trimmed);
	if(tokens.count == 0) return nil;

	NSMutableArray<NSString *> *atoms = [NSMutableArray array];
	for(NSValue *v in tokens) {
		PSToken tk; [v getValue:&tk];
		NSString *folded = [self foldForIndex:tk.text];
		if(folded.length == 0) continue;
		if(tk.isPhrase) {
			// Quoted phrases always match as a phrase, regardless of fuzzy.
			[atoms addObject:[NSString stringWithFormat:@"text_norm:%@", PSQuote(folded)]];
		} else if(fuzzy) {
			// Prefix match: "word"*. Note FTS5 prefix syntax requires the
			// quote to be outside: "word" matches word only; "word" * matches
			// word followed by any token. What we want is a *prefix* match,
			// written as word*. Single tokens can be bare when they contain
			// only identifier chars, but to be safe we fold to a form FTS5
			// accepts as a bareword by stripping non-alphanumerics.
			NSString *bare = PSBarewordForPrefix(folded);
			if(bare.length > 0) {
				[atoms addObject:[NSString stringWithFormat:@"text_norm:%@*", bare]];
			} else {
				[atoms addObject:[NSString stringWithFormat:@"text_norm:%@", PSQuote(folded)]];
			}
		} else {
			[atoms addObject:[NSString stringWithFormat:@"text_norm:%@", PSQuote(folded)]];
		}
	}
	if(atoms.count == 0) return nil;

	NSString *joiner = (matchType == OrSearch) ? @" OR " : @" AND ";
	return [atoms componentsJoinedByString:joiner];
}

+ (NSArray<NSString *> *)strongsTokensFromUserInput:(NSString *)raw {
	if(raw.length == 0) return @[];
	NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(trimmed.length == 0) return @[];
	NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	NSMutableArray<NSString *> *out = [NSMutableArray array];
	NSMutableSet<NSString *> *seen = [NSMutableSet set];
	for(NSString *tok in parts) {
		if(tok.length == 0) continue;
		char prefix = 0;
		if(!PSIsStrongsNumber(tok, &prefix)) continue;
		NSString *upper = [NSString stringWithFormat:@"%c%@", prefix, [tok substringFromIndex:1]];
		if(![seen containsObject:upper]) { [seen addObject:upper]; [out addObject:upper]; }
		NSString *alt = PSAlternateHebrewForm(upper);
		if(alt && ![seen containsObject:alt]) { [seen addObject:alt]; [out addObject:alt]; }
	}
	return out;
}

// Produce a bareword suitable for FTS5 prefix syntax (`word*`). Strips
// any character that isn't a unicode letter or digit; if the result is
// empty we fall back to a quoted phrase.
static NSString *PSBarewordForPrefix(NSString *s) {
	NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
	NSCharacterSet *ok = [NSCharacterSet alphanumericCharacterSet];
	for(NSUInteger i = 0; i < s.length; ++i) {
		unichar c = [s characterAtIndex:i];
		if([ok characterIsMember:c]) {
			[out appendFormat:@"%C", c];
		}
	}
	return out;
}

@end
