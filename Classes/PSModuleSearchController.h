//
//  PSModuleSearchController.h
//  PocketSword
//
//  Redesigned search screen: UISearchController in the nav bar (live,
//  debounced results), a UIMenu options button for Match / Fuzzy / Strong's,
//  standard scope bar (All / OT / NT / Book), and FTS5-highlighted result
//  snippets. Replaces the 2009-era drill-down options table.
//

#import "globals.h"

@class PSSearchHistoryItem;
// PSSearchIndexBuilder went Swift in Wave 3. Per §2A Rule 2 a public Obj-C
// header may not #import "PocketSword-Swift.h"; a forward @protocol declaration
// is sufficient to name PSSearchIndexBuilderDelegate in this class's
// conformance list below. The real Swift protocol is resolved via the generated
// PocketSword-Swift.h imported from PSModuleSearchController.mm.
@protocol PSSearchIndexBuilderDelegate;

@protocol PSModuleSearchControllerDelegate <NSObject>
@required
- (void)searchDidFinish:(PSSearchHistoryItem *)newSearchHistoryItem;
@end

@interface PSModuleSearchController : UIViewController <
	UITabBarControllerDelegate,
	UISearchBarDelegate,
	UISearchResultsUpdating,
	UITableViewDelegate,
	UITableViewDataSource,
	PSSearchIndexBuilderDelegate
>

@property (nonatomic, weak) id <PSModuleSearchControllerDelegate> delegate;
@property (nonatomic, strong) NSString *searchTerm;
@property (nonatomic, strong) NSString *searchTermToDisplay;
@property (nonatomic, assign) BOOL strongsSearch;
@property (nonatomic, assign) BOOL fuzzySearch;
@property (nonatomic, assign) PSSearchType searchType;
@property (nonatomic, assign) PSSearchRange searchRange;
@property (nonatomic, strong) NSString *bookName;
@property (nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSArray *savedTablePosition;

- (instancetype)initWithSearchHistoryItem:(PSSearchHistoryItem *)searchHistoryItem;

- (void)setSearchHistoryItem:(PSSearchHistoryItem *)searchHistoryItem;
- (void)setSearchTitle;

- (void)refreshView;
- (void)setListType:(ShownTab)listType;
- (ShownTab)listType;

- (void)saveTablePositionFromCurrentPosition;
- (void)notifyDelegateOfNewHistoryItem;

- (void)searchButtonPressed:(id)sender;

@end
