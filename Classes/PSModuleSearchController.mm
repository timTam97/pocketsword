//
//  PSModuleSearchController.mm
//  PocketSword
//

#import "PSModuleSearchController.h"
#import "PSResizing.h"
#import "SwordModuleTextEntry.h"
#import "PSModuleController.h"
#import "PSHistoryController.h"
#import "SwordVerseKey.h"
#import "PSSearchHistoryItem.h"
#import "PocketSwordAppDelegate.h"
#import "SwordManager.h"
#import "SwordModule.h"
#import "PSSearchEngine.h"
#import "PSSearchQuery.h"
#import "PSSearchIndexBuilder.h"
#import "PSSearchResult.h"

static const NSTimeInterval kDebounceInterval = 0.25;
static NSString * const kResultCellIdentifier = @"resultsCell";

@interface PSModuleSearchController () {
	ShownTab listType;
	BOOL switchingTabs;
	BOOL searchingEnabled;
}

@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UITableView *resultsTable;
@property (nonatomic, strong) UISegmentedControl *scopeControl;
@property (nonatomic, strong) UIBarButtonItem *optionsBarButton;
@property (nonatomic, strong) NSTimer *debounceTimer;
@property (nonatomic, assign) BOOL strongsAvailable;
/// Index-aligned with `self.results`: each entry is the list of English words
/// to highlight in that row for a Strong's search. Empty array for rows with
/// no mapped words; nil for non-Strong's searches.
@property (nonatomic, copy, nullable) NSArray<NSArray<NSString *> *> *strongsHighlightPerResult;

@end

@implementation PSModuleSearchController

#pragma mark - Init

- (instancetype)initWithSearchHistoryItem:(PSSearchHistoryItem *)searchHistoryItem {
	self = [self init];
	if(self) {
		[self setSearchHistoryItem:searchHistoryItem];
	}
	return self;
}

- (instancetype)init {
	self = [super initWithNibName:nil bundle:nil];
	if(self) {
		UITabBarItem *tBI = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:0];
		self.tabBarItem = tBI;
		switchingTabs = YES;
		self.searchTerm = nil;
		self.searchTermToDisplay = nil;
		self.results = nil;
		self.bookName = nil;
		self.strongsSearch = NO;
		self.savedTablePosition = nil;
		self.navigationItem.title = NSLocalizedString(@"SearchTitle", @"");
		[self setSearchTitle];

		self.fuzzySearch = [[NSUserDefaults standardUserDefaults] boolForKey:DefaultsLastSearchFuzzy];
		self.searchType  = (PSSearchType) [[NSUserDefaults standardUserDefaults] integerForKey:DefaultsLastSearchType];
		self.searchRange = (PSSearchRange)[[NSUserDefaults standardUserDefaults] integerForKey:DefaultsLastSearchRange];
	}
	return self;
}

#pragma mark - View lifecycle

- (void)loadView {
	UIView *root = [[UIView alloc] initWithFrame:[PSResizing mainScreenBounds]];
	root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	root.backgroundColor = [UIColor systemBackgroundColor];

	UITableView *table = [[UITableView alloc] initWithFrame:root.bounds style:UITableViewStylePlain];
	table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	table.delegate = self;
	table.dataSource = self;
	table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
	[root addSubview:table];
	self.resultsTable = table;

	// Scope bar as a persistent table header — iOS 26 hides the UISearchBar's
	// built-in scope chips when the search field activates even with manual
	// scopeBarActivation, so we own the UI ourselves.
	UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[
		NSLocalizedString(@"SearchScopeAll",        @"All"),
		NSLocalizedString(@"SearchRangeOTRowShort", @"OT"),
		NSLocalizedString(@"SearchRangeNTRowShort", @"NT"),
		NSLocalizedString(@"SearchScopeBook",       @"Book"),
	]];
	[seg addTarget:self action:@selector(scopeControlChanged:) forControlEvents:UIControlEventValueChanged];
	UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, 44)];
	header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	seg.translatesAutoresizingMaskIntoConstraints = NO;
	[header addSubview:seg];
	[NSLayoutConstraint activateConstraints:@[
		[seg.leadingAnchor  constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
		[seg.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
		[seg.centerYAnchor  constraintEqualToAnchor:header.centerYAnchor],
	]];
	table.tableHeaderView = header;
	self.scopeControl = seg;

	self.view = root;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.definesPresentationContext = YES;

	self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	self.searchController.searchResultsUpdater = self;
	self.searchController.searchBar.delegate = self;
	self.searchController.searchBar.placeholder = NSLocalizedString(@"SearchTitle", @"");
	self.searchController.obscuresBackgroundDuringPresentation = NO;
	// Keep the nav bar (and its options button) visible while the search
	// bar is active. Without this iOS hides the whole nav bar as soon as
	// the user taps the field, taking the options menu with it.
	self.searchController.hidesNavigationBarDuringPresentation = NO;

	self.scopeControl.selectedSegmentIndex = [self scopeIndexForRange:self.searchRange];

	self.navigationItem.searchController = self.searchController;
	self.navigationItem.hidesSearchBarWhenScrolling = NO;
	// iOS 16+: keep the search bar stacked under the nav bar title so the
	// options button stays reachable. Without this, iOS 26 defaults to a
	// floating/bottom search dock that hides the nav bar chrome when active.
	if (@available(iOS 16.0, *)) {
		self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
	}

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
		initWithTitle:NSLocalizedString(@"CloseButtonTitle", @"Close")
				style:UIBarButtonItemStylePlain
			   target:self
			   action:@selector(closeButtonPressed)];

	self.optionsBarButton = [[UIBarButtonItem alloc]
		initWithImage:[UIImage systemImageNamed:@"slider.horizontal.3"]
				style:UIBarButtonItemStylePlain
			   target:nil
			   action:nil];
	self.navigationItem.rightBarButtonItem = self.optionsBarButton;
	[self rebuildOptionsMenu];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	SwordModule *mod = [self activeModule];
	BOOL hasIndex = mod ? [mod hasSearchIndex] : NO;
	if(mod && !hasIndex) {
		[self offerToBuildIndexForModule:mod];
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(self.searchTermToDisplay) {
		self.searchController.searchBar.text = self.searchTermToDisplay;
	}

	// Decide searchingEnabled before the first draw so the table header
	// doesn't flash "No search index" for a module that already has one.
	SwordModule *mod = [self activeModule];
	searchingEnabled = (mod && [mod hasSearchIndex]);

	[self refreshView];

	if(self.searchTerm) {
		// Coming back from history: the term is already FTS5-ready.
		[self runSearchWithExpression:self.searchTerm];
		self.searchTerm = nil;
	}
	[self setSearchTitle];
}

#pragma mark - Active module helper

- (SwordModule *)activeModule {
	switch(listType) {
		case BibleTab:
			return [[PSModuleController defaultModuleController] primaryBible];
		case CommentaryTab:
			return [[PSModuleController defaultModuleController] primaryCommentary];
		default:
			return nil;
	}
}

- (BOOL)strongsFeatureAvailable {
	SwordModule *mod = [self activeModule];
	if(!mod) return NO;
	return [mod hasFeature:SWMOD_FEATURE_STRONGS] || [mod hasFeature:SWMOD_CONF_FEATURE_STRONGS];
}

#pragma mark - History item

- (void)setSearchHistoryItem:(PSSearchHistoryItem *)searchHistoryItem {
	if(!searchHistoryItem) return;

	// Strip any legacy CLucene-era operators (lemma:, &&, ||) from the
	// display term — old history entries stored those raw.
	NSString *displayTerm = [searchHistoryItem cleanedDisplayTerm];
	self.searchTermToDisplay = displayTerm;
	self.searchType  = searchHistoryItem.searchType;
	self.searchRange = searchHistoryItem.searchRange;
	self.fuzzySearch = searchHistoryItem.fuzzySearch;
	self.results     = searchHistoryItem.results;
	self.bookName    = searchHistoryItem.bookName;
	self.savedTablePosition = searchHistoryItem.savedTablePosition;

	// Only restore Strong's mode if the current Bible still supports it.
	if(searchHistoryItem.strongsSearch && [self strongsFeatureAvailable]) {
		self.strongsSearch = YES;
	} else {
		self.strongsSearch = NO;
	}

	// Build a fresh FTS5 expression from the cleaned display term so the
	// history replay goes through the new engine.
	self.searchTerm = [PSSearchQuery fts5ExpressionFromUserInput:displayTerm
													   matchType:self.searchType
														   fuzzy:self.fuzzySearch
														 strongs:self.strongsSearch];
	self.scopeControl.selectedSegmentIndex = [self scopeIndexForRange:self.searchRange];
	[self setSearchTitle];
}

#pragma mark - Tab type

- (void)setListType:(ShownTab)listT {
	listType = listT;
}

- (ShownTab)listType {
	return listType;
}

#pragma mark - Titles

- (void)setSearchTitle {
	NSString *newTitle = NSLocalizedString(@"SearchTitle", @"");
	if(self.results && self.searchTermToDisplay) {
		newTitle = self.searchTermToDisplay;
	} else if(self.strongsSearch) {
		newTitle = NSLocalizedString(@"SearchStrongsTitle", @"");
	}
	self.navigationItem.title = newTitle;
}

- (void)closeButtonPressed {
	[self notifyDelegateOfNewHistoryItem];
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

#pragma mark - Tab bar delegate

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController {
	if([[tabBarController selectedViewController].title isEqualToString:NSLocalizedString(@"SearchTitle", @"")]) {
		switchingTabs = NO;
	} else {
		switchingTabs = YES;
	}
	return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	if([viewController.title isEqualToString:NSLocalizedString(@"SearchTitle", @"")]) {
		if(!switchingTabs) {
			[self searchButtonPressed:nil];
		}
		[[NSUserDefaults standardUserDefaults] setInteger:SearchTab forKey:DefaultsLastMultiListTab];
	} else {
		[[NSUserDefaults standardUserDefaults] setInteger:HistoryTab forKey:DefaultsLastMultiListTab];
	}
}

#pragma mark - Index-missing prompt

- (void)offerToBuildIndexForModule:(SwordModule *)mod {
	searchingEnabled = NO;
	[self refreshView];

	UIAlertController *alert = [UIAlertController
		alertControllerWithTitle:NSLocalizedString(@"NoSearchIndexTitle", @"No Search Index")
						 message:NSLocalizedString(@"NoSearchIndexMsg", @"No search index is installed for this module, build one?")
				  preferredStyle:UIAlertControllerStyleAlert];

	[alert addAction:[UIAlertAction
		actionWithTitle:NSLocalizedString(@"No", @"No")
				  style:UIAlertActionStyleCancel
				handler:^(UIAlertAction *a) { [self refreshView]; }]];

	[alert addAction:[UIAlertAction
		actionWithTitle:NSLocalizedString(@"Yes", @"Yes")
				  style:UIAlertActionStyleDefault
				handler:^(UIAlertAction *a) {
					PSSearchIndexBuilder *b = [[PSSearchIndexBuilder alloc] initWithModule:mod];
					b.delegate = self;
					[b presentFromViewController:self];
				}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)indexBuilder:(PSSearchIndexBuilder *)builder didFinishWithSuccess:(BOOL)success cancelled:(BOOL)cancelled {
	searchingEnabled = success;
	[self refreshView];
	if(success && self.searchController.searchBar.text.length > 0) {
		[self scheduleDebouncedSearch];
	}
}

#pragma mark - Options menu

- (void)rebuildOptionsMenu {
	self.strongsAvailable = [self strongsFeatureAvailable];

	UIAction *matchAll = [UIAction
		actionWithTitle:NSLocalizedString(@"SearchTypeAllRow", @"All")
				  image:nil
			 identifier:@"match.all"
				handler:^(UIAction *a) { self.searchType = AndSearch;
										 [self persistOptionsAndResearch]; }];
	UIAction *matchAny = [UIAction
		actionWithTitle:NSLocalizedString(@"SearchTypeAnyRow", @"Any")
				  image:nil
			 identifier:@"match.any"
				handler:^(UIAction *a) { self.searchType = OrSearch;
										 [self persistOptionsAndResearch]; }];
	UIAction *matchExact = [UIAction
		actionWithTitle:NSLocalizedString(@"SearchTypeExactRow", @"Exact")
				  image:nil
			 identifier:@"match.exact"
				handler:^(UIAction *a) { self.searchType = ExactSearch;
										 [self persistOptionsAndResearch]; }];
	switch(self.searchType) {
		case AndSearch:   matchAll.state   = UIMenuElementStateOn; break;
		case OrSearch:    matchAny.state   = UIMenuElementStateOn; break;
		case ExactSearch: matchExact.state = UIMenuElementStateOn; break;
	}
	UIMenu *matchMenu = [UIMenu menuWithTitle:NSLocalizedString(@"SearchTypeSectionHeader", @"Match")
										image:nil
								   identifier:@"match"
									  options:(UIMenuOptionsDisplayInline | UIMenuOptionsSingleSelection)
									 children:@[matchAll, matchAny, matchExact]];

	UIAction *fuzzyToggle = [UIAction
		actionWithTitle:NSLocalizedString(@"SearchFuzzyRow", @"Fuzzy")
				  image:nil
			 identifier:@"fuzzy"
				handler:^(UIAction *a) {
					self.fuzzySearch = !self.fuzzySearch;
					[self persistOptionsAndResearch];
				}];
	fuzzyToggle.state = self.fuzzySearch ? UIMenuElementStateOn : UIMenuElementStateOff;
	UIMenu *fuzzyMenu = [UIMenu menuWithTitle:@""
										image:nil
								   identifier:@"fuzzyGroup"
									  options:UIMenuOptionsDisplayInline
									 children:@[fuzzyToggle]];

	NSMutableArray<UIMenuElement *> *topLevel = [NSMutableArray arrayWithObjects:matchMenu, fuzzyMenu, nil];

	if(self.strongsAvailable) {
		UIAction *strongsToggle = [UIAction
			actionWithTitle:NSLocalizedString(@"SearchStrongsRow", @"Strong's")
					  image:nil
				 identifier:@"strongs"
					handler:^(UIAction *a) {
						self.strongsSearch = !self.strongsSearch;
						[self persistOptionsAndResearch];
					}];
		strongsToggle.state = self.strongsSearch ? UIMenuElementStateOn : UIMenuElementStateOff;
		UIMenu *strongsMenu = [UIMenu menuWithTitle:@""
											  image:nil
										 identifier:@"strongsGroup"
											options:UIMenuOptionsDisplayInline
										   children:@[strongsToggle]];
		[topLevel addObject:strongsMenu];
	}

	self.optionsBarButton.menu = [UIMenu menuWithTitle:@"" children:topLevel];
}

- (void)persistOptionsAndResearch {
	[[NSUserDefaults standardUserDefaults] setBool:self.fuzzySearch forKey:DefaultsLastSearchFuzzy];
	[[NSUserDefaults standardUserDefaults] setInteger:self.searchType forKey:DefaultsLastSearchType];
	[[NSUserDefaults standardUserDefaults] setInteger:self.searchRange forKey:DefaultsLastSearchRange];
	[self rebuildOptionsMenu];
	[self scheduleDebouncedSearch];
}

#pragma mark - Scope bar

- (int)scopeIndexForRange:(PSSearchRange)range {
	switch(range) {
		case AllRange:  return 0;
		case OTRange:   return 1;
		case NTRange:   return 2;
		case BookRange: return 3;
	}
}

- (PSSearchRange)rangeForScopeIndex:(NSInteger)idx {
	switch(idx) {
		case 1: return OTRange;
		case 2: return NTRange;
		case 3: return BookRange;
		default: return AllRange;
	}
}

- (void)scopeControlChanged:(UISegmentedControl *)seg {
	self.searchRange = [self rangeForScopeIndex:seg.selectedSegmentIndex];
	if(self.searchRange == BookRange) {
		NSString *currentBook = [PSModuleController getCurrentBibleRef];
		NSRange lastSpace = [currentBook rangeOfString:@" " options:NSBackwardsSearch];
		if(lastSpace.location != NSNotFound) {
			currentBook = [currentBook substringToIndex:lastSpace.location];
		}
		self.bookName = currentBook;
	} else {
		self.bookName = nil;
	}
	[[NSUserDefaults standardUserDefaults] setInteger:self.searchRange forKey:DefaultsLastSearchRange];
	[self scheduleDebouncedSearch];
}

#pragma mark - Debounced search

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
	self.searchTermToDisplay = searchController.searchBar.text;
	[self scheduleDebouncedSearch];
}

- (void)scheduleDebouncedSearch {
	[self.debounceTimer invalidate];
	if(!searchingEnabled) return;

	NSString *text = self.searchController.searchBar.text;
	if(text.length == 0) {
		self.results = nil;
		self.strongsHighlightPerResult = nil;
		self.searchTerm = nil;
		[self.resultsTable reloadData];
		[self setSearchTitle];
		return;
	}

	self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:kDebounceInterval
														  target:self
														selector:@selector(debounceFired:)
														userInfo:nil
														 repeats:NO];
}

- (void)debounceFired:(NSTimer *)t {
	[self runSearchForCurrentText];
}

- (void)runSearchForCurrentText {
	NSString *raw = self.searchController.searchBar.text;
	self.searchTermToDisplay = raw;

	// Strong's mode is sticky — it gets restored from the saved history
	// item after a "Find all occurrences" popup even if the user then
	// types a plain word. Auto-disable when the current text contains no
	// Strong's-shaped tokens; otherwise plain queries hit the lemmas
	// column and return zero results.
	if(self.strongsSearch && ![[self class] inputLooksLikeStrongs:raw]) {
		self.strongsSearch = NO;
		[self rebuildOptionsMenu];
	}

	NSString *expr = [PSSearchQuery fts5ExpressionFromUserInput:raw
													  matchType:self.searchType
														  fuzzy:self.fuzzySearch
														strongs:self.strongsSearch];
	if(expr.length == 0) {
		self.results = nil;
		self.strongsHighlightPerResult = nil;
		[self.resultsTable reloadData];
		return;
	}
	[self runSearchWithExpression:expr];
}

+ (BOOL)inputLooksLikeStrongs:(NSString *)raw {
	NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(trimmed.length == 0) return NO;
	NSArray<NSString *> *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	for(NSString *tok in parts) {
		if(tok.length < 2) continue;
		unichar p = [tok characterAtIndex:0];
		if(p != 'H' && p != 'G' && p != 'h' && p != 'g') continue;
		BOOL allDigits = YES;
		for(NSUInteger i = 1; i < tok.length; ++i) {
			unichar c = [tok characterAtIndex:i];
			if(c < '0' || c > '9') { allDigits = NO; break; }
		}
		if(allDigits) return YES;
	}
	return NO;
}

- (void)runSearchWithExpression:(NSString *)expression {
	SwordModule *mod = [self activeModule];
	if(!mod || ![mod hasSearchIndex]) {
		self.results = nil;
		self.strongsHighlightPerResult = nil;
		[self.resultsTable reloadData];
		return;
	}

	NSArray<NSString *> *strongsTokens = self.strongsSearch
		? [PSSearchQuery strongsTokensFromUserInput:self.searchTermToDisplay]
		: nil;

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		PSSearchEngine *engine = [PSSearchEngine engineForModule:mod];
		NSArray<PSSearchResult *> *raw = [engine runQuery:expression
													scope:self.searchRange
												 bookName:self.bookName
													limit:1000
											strongsTokens:strongsTokens
											   cancelFlag:NULL];
		NSMutableArray *entries = [NSMutableArray arrayWithCapacity:raw.count];
		NSMutableArray<NSArray<NSString *> *> *highlights = strongsTokens.count > 0
			? [NSMutableArray arrayWithCapacity:raw.count]
			: nil;
		for(PSSearchResult *r in raw) {
			SwordModuleTextEntry *e = [[SwordModuleTextEntry alloc] initWithKey:r.reference
																		andText:r.fullText];
			[entries addObject:e];
			if(highlights) [highlights addObject:(r.strongsHighlightWords ?: @[])];
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			self.results = entries;
			self.strongsHighlightPerResult = highlights;
			[self notifyDelegateOfNewHistoryItem];
			[self.resultsTable reloadData];
			[self setSearchTitle];
		});
	});
}

#pragma mark - Search bar delegate (immediate "return" key)

- (void)searchBarSearchButtonClicked:(UISearchBar *)sBar {
	[self.debounceTimer invalidate];
	[sBar resignFirstResponder];
	[self runSearchForCurrentText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)sBar {
	self.results = nil;
	self.strongsHighlightPerResult = nil;
	self.searchTermToDisplay = nil;
	[self.resultsTable reloadData];
	[self setSearchTitle];
}

#pragma mark - Full-verse rendering with UI-side highlighting

// Returns the list of bareword tokens from the user's current query that
// should be visually highlighted in each result verse. Skips short (<2 char)
// tokens to avoid highlighting "a", "of" etc. For Strong's searches returns
// an empty array — the mapped surface words are instead supplied per-result
// via strongsHighlightPerResult, since they vary by verse.
- (NSArray<NSString *> *)highlightTokens {
	if(self.strongsSearch) return @[];
	NSString *raw = self.searchTermToDisplay;
	if(raw.length == 0) return @[];

	// For exact phrase search, highlight only the full phrase as one unit.
	if(self.searchType == ExactSearch) {
		return raw.length >= 2 ? @[raw] : @[];
	}

	// Tokenise: respect "quoted phrases" (highlight whole phrase), otherwise
	// whitespace split.
	NSMutableArray<NSString *> *out = [NSMutableArray array];
	NSUInteger i = 0, n = raw.length;
	while(i < n) {
		unichar c = [raw characterAtIndex:i];
		if(c == ' ' || c == '\t' || c == '\n') { ++i; continue; }
		if(c == '"') {
			++i;
			NSUInteger start = i;
			while(i < n && [raw characterAtIndex:i] != '"') ++i;
			NSString *phrase = [raw substringWithRange:NSMakeRange(start, i - start)];
			if(i < n) ++i;
			if(phrase.length >= 2) [out addObject:phrase];
		} else {
			NSUInteger start = i;
			while(i < n) {
				unichar ch = [raw characterAtIndex:i];
				if(ch == ' ' || ch == '\t' || ch == '\n' || ch == '"') break;
				++i;
			}
			NSString *word = [raw substringWithRange:NSMakeRange(start, i - start)];
			if(word.length >= 2) [out addObject:word];
		}
	}
	return out;
}

// Produce an NSAttributedString of `verseText` with every occurrence of any
// `tokens` entry highlighted. Matching is diacritic-insensitive and case-
// insensitive (NSDiacriticInsensitiveSearch | NSCaseInsensitiveSearch). For
// Fuzzy mode the tokens are treated as prefixes and we highlight the full
// matching word (the token plus any trailing letter/digit characters).
- (NSAttributedString *)attributedVerseText:(NSString *)verseText
									 tokens:(NSArray<NSString *> *)tokens
									  fuzzy:(BOOL)fuzzy {
	if(verseText.length == 0) return [[NSAttributedString alloc] init];
	NSMutableAttributedString *out = [[NSMutableAttributedString alloc]
		initWithString:verseText
			attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:UIFont.systemFontSize] }];
	if(tokens.count == 0) return out;

	NSDictionary *hlAttrs = @{
		NSBackgroundColorAttributeName: [UIColor systemYellowColor],
		NSForegroundColorAttributeName: [UIColor blackColor],
		NSFontAttributeName: [UIFont boldSystemFontOfSize:UIFont.systemFontSize],
	};
	NSStringCompareOptions opts = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
	NSCharacterSet *wordChars = [NSCharacterSet alphanumericCharacterSet];

	for(NSString *token in tokens) {
		NSRange search = NSMakeRange(0, verseText.length);
		while(search.location < verseText.length) {
			NSRange hit = [verseText rangeOfString:token options:opts range:search];
			if(hit.location == NSNotFound) break;

			NSRange highlight = hit;
			if(fuzzy) {
				// Extend the highlight forward to the end of the current word
				// so "lov" shows "loved"/"loving" fully highlighted.
				NSUInteger end = NSMaxRange(hit);
				while(end < verseText.length &&
					  [wordChars characterIsMember:[verseText characterAtIndex:end]]) {
					++end;
				}
				highlight.length = end - highlight.location;
			}
			[out addAttributes:hlAttrs range:highlight];
			search.location = NSMaxRange(highlight);
			search.length = verseText.length - search.location;
		}
	}
	return out;
}

#pragma mark - Table view

- (void)refreshView {
	[self rebuildOptionsMenu];
	self.searchController.searchBar.userInteractionEnabled = searchingEnabled;
	[self.resultsTable reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(!searchingEnabled) return 0;
	return self.results.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(!searchingEnabled) {
		return NSLocalizedString(@"NoSearchIndexInstalled", @"No Search Index Installed");
	}
	if(self.results) {
		return [NSString stringWithFormat:@"%lu %@", (unsigned long)self.results.count,
												   NSLocalizedString(@"SearchResults", @"results")];
	}
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 72.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kResultCellIdentifier];
	if(!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:kResultCellIdentifier];
		cell.detailTextLabel.numberOfLines = 0;
		cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.textLabel.font = [UIFont boldSystemFontOfSize:15.0];
	}

	if(indexPath.row >= self.results.count) return cell;
	SwordModuleTextEntry *entry = self.results[indexPath.row];
	cell.textLabel.text = entry.key;

	// If the entry is missing its full text (e.g. old cached history
	// entries), pull it from the module on demand.
	if(!entry.text) {
		SwordModule *mod = [self activeModule];
		NSString *ref = [PSModuleController createRefString:entry.key];
		SwordModuleTextEntry *pulled = [mod textEntryForKey:ref textType:TextTypeStripped];
		if(pulled.text) {
			entry.text = PSSearchCleanDisplayText(pulled.text);
		}
	}
	NSString *txt = entry.text ?: @"";
	txt = [txt stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

	NSArray<NSString *> *tokens;
	BOOL fuzzy;
	if(self.strongsSearch) {
		tokens = (indexPath.row < self.strongsHighlightPerResult.count)
			? self.strongsHighlightPerResult[indexPath.row]
			: @[];
		fuzzy = NO;
	} else {
		tokens = [self highlightTokens];
		fuzzy = self.fuzzySearch;
	}
	cell.detailTextLabel.attributedText = [self attributedVerseText:txt tokens:tokens fuzzy:fuzzy];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if(!self.results || indexPath.row >= self.results.count) return;

	[self notifyDelegateOfNewHistoryItem];
	NSString *ref = [(SwordModuleTextEntry *)self.results[indexPath.row] key];
	NSArray *parts = [ref componentsSeparatedByString:@":"];
	NSString *verse = parts.count > 1 ? parts[1] : @"1";
	NSString *bookChapter = parts.firstObject ?: ref;

	[[NSUserDefaults standardUserDefaults] setObject:verse forKey:DefaultsCommentaryVersePosition];
	[[NSUserDefaults standardUserDefaults] setObject:verse forKey:DefaultsBibleVersePosition];
	[[NSUserDefaults standardUserDefaults] setObject:[PSModuleController createRefString:bookChapter]
											  forKey:DefaultsLastRef];
	[[NSUserDefaults standardUserDefaults] synchronize];

	switch(listType) {
		case BibleTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryBible object:nil];
			[PSHistoryController addHistoryItem:BibleTab];
			break;
		case CommentaryTab:
			[[NSNotificationCenter defaultCenter] postNotificationName:NotificationRedisplayPrimaryCommentary object:nil];
			[PSHistoryController addHistoryItem:CommentaryTab];
			break;
		default:
			break;
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationToggleMultiList object:nil];
}

#pragma mark - History hand-off

- (void)notifyDelegateOfNewHistoryItem {
	if(!self.searchTermToDisplay || [self.searchTermToDisplay isEqualToString:@""]) {
		[self.delegate searchDidFinish:nil];
		return;
	}
	NSString *bName = (self.searchRange == BookRange) ? self.bookName : nil;
	PSSearchHistoryItem *item = [[PSSearchHistoryItem alloc] initWithSearchTermToDisplay:self.searchTermToDisplay
																				strongs:self.strongsSearch
																				  fuzzy:self.fuzzySearch
																				   type:self.searchType
																				  range:self.searchRange
																				   book:bName];
	item.results = self.results;
	[self saveTablePositionFromCurrentPosition];
	item.savedTablePosition = self.savedTablePosition;
	[self.delegate searchDidFinish:item];
}

- (void)saveTablePositionFromCurrentPosition {
	if(self.results.count > 0) {
		self.savedTablePosition = [self.resultsTable indexPathsForVisibleRows];
	}
}

#pragma mark - Legacy plumbing

- (void)searchButtonPressed:(id)sender {
	[self.searchController.searchBar becomeFirstResponder];
}

@end
