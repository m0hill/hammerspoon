@import Cocoa;
@import LuaSkin;

#define TAG_PANEL     "hs.ui.panel"
#define TAG_STACK     "hs.ui.stack"
#define TAG_TEXTFIELD "hs.ui.textField"
#define TAG_LIST      "hs.ui.list"
#define TAG_IMAGE     "hs.ui.image"

#define GET_OBJECT(objType, L, idx, tag) (__bridge objType *)*((void **)luaL_checkudata(L, idx, tag))
#define GET_OBJECT_TRANSFER(objType, L, idx, tag) (__bridge_transfer objType *)*((void **)luaL_checkudata(L, idx, tag))

static LSRefTable refTable = LUA_NOREF;

@class HSUIPanel;
@class HSUIList;

static void runOnMainSync(dispatch_block_t block) {
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

static NSRect hsToAppKitRect(NSRect rect) {
    CGFloat h = [[NSScreen screens][0] frame].size.height;
    return NSMakeRect(rect.origin.x, h - rect.origin.y - rect.size.height, rect.size.width, rect.size.height);
}

static NSRect appKitToHSRect(NSRect rect) {
    CGFloat h = [[NSScreen screens][0] frame].size.height;
    return NSMakeRect(rect.origin.x, h - rect.origin.y - rect.size.height, rect.size.width, rect.size.height);
}

static NSString *stringField(lua_State *L, int idx, const char *key, NSString *defaultValue) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSString *result = defaultValue;
    lua_getfield(L, idx, key);
    if (lua_type(L, -1) == LUA_TSTRING) result = [skin toNSObjectAtIndex:-1];
    lua_pop(L, 1);
    return result;
}

static CGFloat numberField(lua_State *L, int idx, const char *key, CGFloat defaultValue) {
    CGFloat result = defaultValue;
    lua_getfield(L, idx, key);
    if (lua_type(L, -1) == LUA_TNUMBER) result = (CGFloat)lua_tonumber(L, -1);
    lua_pop(L, 1);
    return result;
}

static BOOL boolField(lua_State *L, int idx, const char *key, BOOL defaultValue) {
    BOOL result = defaultValue;
    lua_getfield(L, idx, key);
    if (lua_type(L, -1) == LUA_TBOOLEAN) result = (BOOL)lua_toboolean(L, -1);
    lua_pop(L, 1);
    return result;
}

static void pushKeyEvent(lua_State *L, NSEvent *event) {
    lua_newtable(L);
    lua_pushinteger(L, event.keyCode); lua_setfield(L, -2, "keyCode");
    lua_pushstring(L, event.characters.UTF8String ?: ""); lua_setfield(L, -2, "characters");
    lua_pushstring(L, event.charactersIgnoringModifiers.UTF8String ?: ""); lua_setfield(L, -2, "charactersIgnoringModifiers");
    NSEventModifierFlags flags = event.modifierFlags;
    lua_newtable(L);
    lua_pushboolean(L, (flags & NSEventModifierFlagCommand) != 0); lua_setfield(L, -2, "cmd");
    lua_pushboolean(L, (flags & NSEventModifierFlagShift) != 0); lua_setfield(L, -2, "shift");
    lua_pushboolean(L, (flags & NSEventModifierFlagOption) != 0); lua_setfield(L, -2, "alt");
    lua_pushboolean(L, (flags & NSEventModifierFlagControl) != 0); lua_setfield(L, -2, "ctrl");
    lua_pushboolean(L, (flags & NSEventModifierFlagFunction) != 0); lua_setfield(L, -2, "fn");
    lua_setfield(L, -2, "modifiers");
}

typedef int (^PushArgsBlock)(LuaSkin *skin, lua_State *L);

@interface HSUIView : NSObject
@property NSView *view;
@property NSMutableDictionary<NSString *, NSNumber *> *callbacks;
@property LSRefTable refTable;
@property NSInteger selfRefCount;
@property NSInteger containerRefCount;
@property BOOL deleted;
@property BOOL grow;
@property CGFloat preferredWidth;
@property CGFloat preferredHeight;
@property CGFloat minWidth;
@property CGFloat minHeight;
@property __weak HSUIPanel *panel;
- (instancetype)initWithRefTable:(LSRefTable)table;
- (void)readLayoutFromLua:(lua_State *)L index:(int)idx defaultGrow:(BOOL)defaultGrow;
- (void)applyLayout;
- (int)setCallbackFromLua:(lua_State *)L event:(NSString *)event allowed:(NSArray<NSString *> *)allowed;
- (BOOL)fireCallback:(NSString *)event errorName:(NSString *)errorName resultBool:(BOOL *)resultBool pushArgs:(PushArgsBlock)pushArgs;
- (void)assignPanel:(HSUIPanel *)panel;
- (void)containerRetain;
- (void)containerRelease;
- (HSUIList *)firstList;
- (void)cleanup;
@end

@interface HSUIPanelWindow : NSPanel
@property __weak HSUIPanel *uiOwner;
@end

@interface HSUIPanel : NSObject <NSWindowDelegate>
@property HSUIPanelWindow *window;
@property NSView *rootView;
@property HSUIView *content;
@property NSMutableDictionary<NSString *, NSNumber *> *callbacks;
@property LSRefTable refTable;
@property NSInteger selfRefCount;
@property BOOL deleted;
@property BOOL closeOnBlur;
@property BOOL escapeCloses;
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx;
- (int)setCallbackFromLua:(lua_State *)L event:(NSString *)event;
- (BOOL)fireCallback:(NSString *)event errorName:(NSString *)errorName resultBool:(BOOL *)resultBool pushArgs:(PushArgsBlock)pushArgs;
- (BOOL)handleKeyDown:(NSEvent *)event;
- (BOOL)routeDefaultKeyDown:(NSEvent *)event;
- (BOOL)routeDefaultCommandSelector:(SEL)commandSelector;
- (void)hidePanel;
- (void)cleanup;
@end

@interface HSUITextFieldControl : NSTextField
@property __weak id uiOwner;
@end
@interface HSUISearchFieldControl : NSSearchField
@property __weak id uiOwner;
@end

@interface HSUITextField : HSUIView <NSTextFieldDelegate>
@property NSTextField *textField;
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx;
- (BOOL)handleKeyDown:(NSEvent *)event;
@end

@interface HSUITableView : NSTableView
@property __weak id uiOwner;
@end

@interface HSUIList : HSUIView <NSTableViewDataSource, NSTableViewDelegate>
@property NSScrollView *scrollView;
@property HSUITableView *tableView;
@property NSArray<NSDictionary *> *rows;
@property BOOL allowsEmptySelection;
@property CGFloat rowHeight;
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx;
- (void)setRowsFromLua:(lua_State *)L index:(int)idx;
- (NSInteger)selectedLuaIndex;
- (void)selectLuaIndex:(NSInteger)index;
- (void)selectNext;
- (void)selectPrevious;
- (void)confirmSelection;
- (BOOL)handleKeyDown:(NSEvent *)event;
@end

@interface HSUIStack : HSUIView
@property NSStackView *stackView;
@property NSMutableArray<HSUIView *> *children;
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx;
- (void)addView:(HSUIView *)view;
- (void)removeView:(HSUIView *)view;
@end

@interface HSUIImage : HSUIView
@property NSImageView *imageView;
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx;
@end

@implementation HSUIView
- (instancetype)initWithRefTable:(LSRefTable)table {
    self = [super init];
    if (self) {
        _refTable = table;
        _callbacks = [NSMutableDictionary dictionary];
        _selfRefCount = 0;
        _containerRefCount = 0;
        _deleted = NO;
    }
    return self;
}

- (void)readLayoutFromLua:(lua_State *)L index:(int)idx defaultGrow:(BOOL)defaultGrow {
    self.grow = boolField(L, idx, "grow", defaultGrow);
    self.preferredWidth = numberField(L, idx, "width", 0);
    self.preferredHeight = numberField(L, idx, "height", 0);
    self.minWidth = numberField(L, idx, "minWidth", 0);
    self.minHeight = numberField(L, idx, "minHeight", 0);
}

- (void)applyLayout {
    self.view.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.preferredWidth > 0) [self.view.widthAnchor constraintEqualToConstant:self.preferredWidth].active = YES;
    if (self.preferredHeight > 0) [self.view.heightAnchor constraintEqualToConstant:self.preferredHeight].active = YES;
    if (self.minWidth > 0) [self.view.widthAnchor constraintGreaterThanOrEqualToConstant:self.minWidth].active = YES;
    if (self.minHeight > 0) [self.view.heightAnchor constraintGreaterThanOrEqualToConstant:self.minHeight].active = YES;
    if (self.grow) {
        [self.view setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [self.view setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];
    }
}

- (int)setCallbackFromLua:(lua_State *)L event:(NSString *)event allowed:(NSArray<NSString *> *)allowed {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    if (![allowed containsObject:event]) return luaL_error(L, "unsupported hs.ui event: %s", event.UTF8String);
    NSNumber *old = self.callbacks[event];
    if (old) {
        [skin luaUnref:self.refTable ref:old.intValue];
        [self.callbacks removeObjectForKey:event];
    }
    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        self.callbacks[event] = @([skin luaRef:self.refTable]);
    }
    lua_pushvalue(L, 1);
    return 1;
}

- (BOOL)fireCallback:(NSString *)event errorName:(NSString *)errorName resultBool:(BOOL *)resultBool pushArgs:(PushArgsBlock)pushArgs {
    NSNumber *ref = self.callbacks[event];
    if (!ref || self.deleted) return NO;
    __block BOOL boolResult = NO;
    runOnMainSync(^{
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L = skin.L;
        _lua_stackguard_entry(L);
        [skin pushLuaRef:self.refTable ref:ref.intValue];
        int nargs = pushArgs ? pushArgs(skin, L) : 0;
        BOOL ok = [skin protectedCallAndError:errorName nargs:nargs nresults:(resultBool ? 1 : 0)];
        if (ok && resultBool) {
            boolResult = (BOOL)lua_toboolean(L, -1);
            lua_pop(L, 1);
        }
        _lua_stackguard_exit(L);
    });
    if (resultBool) *resultBool = boolResult;
    return YES;
}

- (void)assignPanel:(HSUIPanel *)panel { self.panel = panel; }
- (void)containerRetain { self.containerRefCount++; }
- (void)containerRelease {
    if (self.containerRefCount > 0) self.containerRefCount--;
    if (self.selfRefCount <= 0 && self.containerRefCount <= 0) [self cleanup];
}
- (HSUIList *)firstList { return nil; }

- (void)cleanup {
    if (self.deleted) return;
    self.deleted = YES;
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    for (NSNumber *ref in self.callbacks.allValues) [skin luaUnref:self.refTable ref:ref.intValue];
    [self.callbacks removeAllObjects];
    [self.view removeFromSuperview];
    self.panel = nil;
}
@end

@implementation HSUIPanelWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
- (BOOL)allowsVibrancy { return YES; }
- (void)keyDown:(NSEvent *)event {
    if (![self.uiOwner handleKeyDown:event]) [super keyDown:event];
}
@end

@implementation HSUIPanel
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx {
    self = [super init];
    if (!self) return nil;
    _refTable = table;
    _callbacks = [NSMutableDictionary dictionary];
    _closeOnBlur = boolField(L, idx, "closeOnBlur", NO);
    _escapeCloses = boolField(L, idx, "escapeCloses", YES);

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    NSRect frame = NSMakeRect(0, 0, 720, 620);
    lua_getfield(L, idx, "frame");
    if (lua_type(L, -1) == LUA_TTABLE) frame = [skin tableToRectAtIndex:-1];
    lua_pop(L, 1);

    NSString *style = stringField(L, idx, "style", @"titled");
    NSString *level = stringField(L, idx, "level", @"normal");
    NSString *material = stringField(L, idx, "material", nil);
    CGFloat cornerRadius = numberField(L, idx, "cornerRadius", 0);
    BOOL shadow = boolField(L, idx, "shadow", YES);
    BOOL movable = boolField(L, idx, "movable", YES);

    __block HSUIPanelWindow *window = nil;
    __block NSView *root = nil;
    runOnMainSync(^{
        NSWindowStyleMask styleMask = [style isEqualToString:@"borderless"] ? NSWindowStyleMaskBorderless : (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable);
        window = [[HSUIPanelWindow alloc] initWithContentRect:hsToAppKitRect(frame) styleMask:styleMask backing:NSBackingStoreBuffered defer:NO];
        window.uiOwner = self;
        window.delegate = self;
        window.releasedWhenClosed = NO;
        window.restorable = NO;
        window.hasShadow = shadow;
        window.movableByWindowBackground = movable;
        window.opaque = NO;
        window.backgroundColor = NSColor.clearColor;
        if ([level isEqualToString:@"floating"]) window.level = NSFloatingWindowLevel;
        else if ([level isEqualToString:@"modalPanel"]) window.level = NSModalPanelWindowLevel;
        else if ([level isEqualToString:@"screenSaver"]) window.level = NSScreenSaverWindowLevel;
        else window.level = NSNormalWindowLevel;

        if (material) {
            NSVisualEffectView *effect = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
            if ([material isEqualToString:@"popover"]) effect.material = NSVisualEffectMaterialPopover;
            else if ([material isEqualToString:@"sidebar"]) effect.material = NSVisualEffectMaterialSidebar;
            else if ([material isEqualToString:@"window"]) effect.material = NSVisualEffectMaterialWindowBackground;
            else effect.material = NSVisualEffectMaterialHUDWindow;
            effect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
            effect.state = NSVisualEffectStateActive;
            root = effect;
        } else {
            root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
        }
        root.translatesAutoresizingMaskIntoConstraints = NO;
        root.wantsLayer = YES;
        root.layer.cornerRadius = cornerRadius;
        root.layer.masksToBounds = cornerRadius > 0;
        window.contentView = root;
    });
    _window = window;
    _rootView = root;
    return self;
}

- (int)setCallbackFromLua:(lua_State *)L event:(NSString *)event {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    if (![@[@"close", @"blur", @"keyDown"] containsObject:event]) return luaL_error(L, "unsupported hs.ui.panel event: %s", event.UTF8String);
    NSNumber *old = self.callbacks[event];
    if (old) {
        [skin luaUnref:self.refTable ref:old.intValue];
        [self.callbacks removeObjectForKey:event];
    }
    if (lua_type(L, 3) == LUA_TFUNCTION) {
        lua_pushvalue(L, 3);
        self.callbacks[event] = @([skin luaRef:self.refTable]);
    }
    lua_pushvalue(L, 1);
    return 1;
}

- (BOOL)fireCallback:(NSString *)event errorName:(NSString *)errorName resultBool:(BOOL *)resultBool pushArgs:(PushArgsBlock)pushArgs {
    NSNumber *ref = self.callbacks[event];
    if (!ref || self.deleted) return NO;
    __block BOOL boolResult = NO;
    runOnMainSync(^{
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L = skin.L;
        _lua_stackguard_entry(L);
        [skin pushLuaRef:self.refTable ref:ref.intValue];
        int nargs = pushArgs ? pushArgs(skin, L) : 0;
        BOOL ok = [skin protectedCallAndError:errorName nargs:nargs nresults:(resultBool ? 1 : 0)];
        if (ok && resultBool) {
            boolResult = (BOOL)lua_toboolean(L, -1);
            lua_pop(L, 1);
        }
        _lua_stackguard_exit(L);
    });
    if (resultBool) *resultBool = boolResult;
    return YES;
}

- (BOOL)handleKeyDown:(NSEvent *)event {
    __block BOOL consumed = NO;
    [self fireCallback:@"keyDown" errorName:@"hs.ui.panel keyDown" resultBool:&consumed pushArgs:^int(LuaSkin *skin, lua_State *L) { (void)skin; pushKeyEvent(L, event); return 1; }];
    if (consumed) return YES;
    return [self routeDefaultKeyDown:event];
}

- (BOOL)routeDefaultKeyDown:(NSEvent *)event {
    NSEventModifierFlags flags = event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagShift | NSEventModifierFlagOption | NSEventModifierFlagControl);
    if (flags != 0) return NO;
    HSUIList *list = [self.content firstList];
    if (event.keyCode == 126 && list) { [list selectPrevious]; return YES; }
    if (event.keyCode == 125 && list) { [list selectNext]; return YES; }
    if ((event.keyCode == 36 || event.keyCode == 76) && list) { [list confirmSelection]; return YES; }
    if (event.keyCode == 53 && self.escapeCloses) { [self hidePanel]; return YES; }
    return NO;
}

- (BOOL)routeDefaultCommandSelector:(SEL)commandSelector {
    HSUIList *list = [self.content firstList];
    if (commandSelector == @selector(moveUp:) && list) { [list selectPrevious]; return YES; }
    if (commandSelector == @selector(moveDown:) && list) { [list selectNext]; return YES; }
    if ((commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) && list) { [list confirmSelection]; return YES; }
    if (commandSelector == @selector(cancelOperation:) && self.escapeCloses) { [self hidePanel]; return YES; }
    return NO;
}

- (void)hidePanel { if (!self.deleted) runOnMainSync(^{ [self.window orderOut:nil]; }); }

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    [self fireCallback:@"close" errorName:@"hs.ui.panel close" resultBool:nil pushArgs:nil];
    [self hidePanel];
    return NO;
}

- (void)windowDidResignKey:(NSNotification *)notification {
    (void)notification;
    if (self.deleted || !self.window.isVisible) return;
    [self fireCallback:@"blur" errorName:@"hs.ui.panel blur" resultBool:nil pushArgs:nil];
    if (self.closeOnBlur) [self hidePanel];
}

- (void)cleanup {
    if (self.deleted) return;
    self.deleted = YES;
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    for (NSNumber *ref in self.callbacks.allValues) [skin luaUnref:self.refTable ref:ref.intValue];
    [self.callbacks removeAllObjects];
    [self.content containerRelease];
    [self.content cleanup];
    self.content = nil;
    runOnMainSync(^{
        self.window.delegate = nil;
        self.window.uiOwner = nil;
        [self.window orderOut:nil];
        [self.window close];
    });
}
@end

@implementation HSUITextFieldControl
- (void)keyDown:(NSEvent *)event {
    if ([self.uiOwner respondsToSelector:@selector(handleKeyDown:)] && [self.uiOwner handleKeyDown:event]) return;
    [super keyDown:event];
}
@end
@implementation HSUISearchFieldControl
- (void)keyDown:(NSEvent *)event {
    if ([self.uiOwner respondsToSelector:@selector(handleKeyDown:)] && [self.uiOwner handleKeyDown:event]) return;
    [super keyDown:event];
}
@end

@implementation HSUITextField
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx {
    self = [super initWithRefTable:table];
    if (!self) return nil;
    BOOL search = boolField(L, idx, "search", NO);
    NSString *placeholder = stringField(L, idx, "placeholder", @"");
    CGFloat fontSize = numberField(L, idx, "fontSize", 13);
    BOOL bordered = boolField(L, idx, "bordered", YES);
    BOOL bezeled = boolField(L, idx, "bezeled", bordered);
    BOOL drawsBackground = boolField(L, idx, "drawsBackground", YES);
    BOOL focusRing = boolField(L, idx, "focusRing", YES);
    [self readLayoutFromLua:L index:idx defaultGrow:NO];
    runOnMainSync(^{
        NSTextField *field;
        if (search) {
            HSUISearchFieldControl *searchField = [[HSUISearchFieldControl alloc] initWithFrame:NSZeroRect];
            searchField.uiOwner = self;
            field = searchField;
        } else {
            HSUITextFieldControl *textField = [[HSUITextFieldControl alloc] initWithFrame:NSZeroRect];
            textField.uiOwner = self;
            field = textField;
        }
        field.delegate = self;
        field.placeholderString = placeholder;
        field.font = [NSFont systemFontOfSize:fontSize];
        field.bordered = bordered;
        field.bezeled = bezeled;
        field.drawsBackground = drawsBackground;
        field.focusRingType = focusRing ? NSFocusRingTypeDefault : NSFocusRingTypeNone;
        if (!drawsBackground) field.backgroundColor = NSColor.clearColor;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        self.textField = field;
        self.view = field;
        [self applyLayout];
    });
    return self;
}

- (BOOL)handleKeyDown:(NSEvent *)event {
    __block BOOL consumed = NO;
    [self fireCallback:@"keyDown" errorName:@"hs.ui.textField keyDown" resultBool:&consumed pushArgs:^int(LuaSkin *skin, lua_State *L) { (void)skin; pushKeyEvent(L, event); return 1; }];
    if (consumed) return YES;

    if (event.keyCode == 36 || event.keyCode == 76) {
        __block BOOL submitConsumed = NO;
        [self fireCallback:@"submit" errorName:@"hs.ui.textField submit" resultBool:&submitConsumed pushArgs:^int(LuaSkin *skin, lua_State *L) {
            [skin pushNSObject:self.textField.stringValue ?: @""];
            return 1;
        }];
        if (submitConsumed) return YES;
    } else if (event.keyCode == 53) {
        __block BOOL escapeConsumed = NO;
        [self fireCallback:@"escape" errorName:@"hs.ui.textField escape" resultBool:&escapeConsumed pushArgs:nil];
        if (escapeConsumed) return YES;
    }

    if (self.panel && [self.panel handleKeyDown:event]) return YES;
    return NO;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    (void)control;
    (void)textView;

    if (commandSelector == @selector(insertNewline:) || commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        __block BOOL submitConsumed = NO;
        [self fireCallback:@"submit" errorName:@"hs.ui.textField submit" resultBool:&submitConsumed pushArgs:^int(LuaSkin *skin, lua_State *L) {
            [skin pushNSObject:self.textField.stringValue ?: @""];
            return 1;
        }];
        if (submitConsumed) return YES;
    } else if (commandSelector == @selector(cancelOperation:)) {
        __block BOOL escapeConsumed = NO;
        [self fireCallback:@"escape" errorName:@"hs.ui.textField escape" resultBool:&escapeConsumed pushArgs:nil];
        if (escapeConsumed) return YES;
    }

    if (self.panel && [self.panel routeDefaultCommandSelector:commandSelector]) return YES;
    return NO;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    (void)obj;
    [self fireCallback:@"change" errorName:@"hs.ui.textField change" resultBool:nil pushArgs:^int(LuaSkin *skin, lua_State *L) {
        [skin pushNSObject:self.textField.stringValue ?: @""];
        return 1;
    }];
}
@end

@implementation HSUITableView
- (void)keyDown:(NSEvent *)event {
    if ([self.uiOwner respondsToSelector:@selector(handleKeyDown:)] && [self.uiOwner handleKeyDown:event]) return;
    [super keyDown:event];
}
@end

@implementation HSUIList
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx {
    self = [super initWithRefTable:table];
    if (!self) return nil;
    _rows = @[];
    _rowHeight = numberField(L, idx, "rowHeight", 54);
    _allowsEmptySelection = boolField(L, idx, "allowsEmptySelection", YES);
    [self readLayoutFromLua:L index:idx defaultGrow:YES];
    runOnMainSync(^{
        self.scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        self.scrollView.hasVerticalScroller = YES;
        self.scrollView.hasHorizontalScroller = NO;
        self.scrollView.borderType = NSNoBorder;
        self.scrollView.drawsBackground = NO;
        self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;

        self.tableView = [[HSUITableView alloc] initWithFrame:NSZeroRect];
        self.tableView.uiOwner = self;
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.headerView = nil;
        self.tableView.rowHeight = self.rowHeight;
        self.tableView.intercellSpacing = NSMakeSize(0, 0);
        self.tableView.allowsEmptySelection = self.allowsEmptySelection;
        self.tableView.allowsMultipleSelection = NO;
        self.tableView.backgroundColor = NSColor.clearColor;
        self.tableView.focusRingType = NSFocusRingTypeNone;
        self.tableView.target = self;
        self.tableView.doubleAction = @selector(doubleClick:);
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"main"];
        column.resizingMask = NSTableColumnAutoresizingMask;
        [self.tableView addTableColumn:column];
        self.scrollView.documentView = self.tableView;
        self.view = self.scrollView;
        [self applyLayout];
    });
    return self;
}

- (void)setRowsFromLua:(lua_State *)L index:(int)idx {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    id obj = [skin toNSObjectAtIndex:idx];
    NSMutableArray *rows = [NSMutableArray array];
    if ([obj isKindOfClass:NSArray.class]) {
        for (id row in (NSArray *)obj) if ([row isKindOfClass:NSDictionary.class]) [rows addObject:[row copy]];
    }
    self.rows = rows;
    runOnMainSync(^{
        [self.tableView reloadData];
        if (!self.allowsEmptySelection && self.rows.count > 0) [self selectLuaIndex:1];
    });
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { (void)tableView; return (NSInteger)self.rows.count; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)tableColumn;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"HSUIListCell" owner:self];
    if (!cell) { cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, self.rowHeight)]; cell.identifier = @"HSUIListCell"; }
    for (NSView *subview in cell.subviews.copy) [subview removeFromSuperview];

    NSDictionary *data = self.rows[(NSUInteger)row];
    NSString *title = [data[@"title"] isKindOfClass:NSString.class] ? data[@"title"] : @"";
    NSString *subtitle = [data[@"subtitle"] isKindOfClass:NSString.class] ? data[@"subtitle"] : @"";
    BOOL disabled = [data[@"disabled"] respondsToSelector:@selector(boolValue)] && [data[@"disabled"] boolValue];

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    NSString *path = [data[@"path"] isKindOfClass:NSString.class] ? data[@"path"] : nil;
    NSString *symbol = [data[@"systemImage"] isKindOfClass:NSString.class] ? data[@"systemImage"] : nil;
    if (path && [data[@"iconForFile"] respondsToSelector:@selector(boolValue)] && [data[@"iconForFile"] boolValue]) icon.image = [[NSWorkspace sharedWorkspace] iconForFile:path];
    else if (symbol) icon.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];

    NSTextField *titleField = [NSTextField labelWithString:title];
    titleField.translatesAutoresizingMaskIntoConstraints = NO;
    titleField.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    titleField.textColor = disabled ? NSColor.tertiaryLabelColor : NSColor.labelColor;
    NSTextField *subtitleField = [NSTextField labelWithString:subtitle];
    subtitleField.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleField.font = [NSFont systemFontOfSize:12];
    subtitleField.textColor = disabled ? NSColor.tertiaryLabelColor : NSColor.secondaryLabelColor;
    NSStackView *texts = [[NSStackView alloc] initWithFrame:NSZeroRect];
    [texts addArrangedSubview:titleField];
    [texts addArrangedSubview:subtitleField];
    texts.orientation = NSUserInterfaceLayoutOrientationVertical;
    texts.spacing = 2;
    texts.alignment = NSLayoutAttributeLeading;
    texts.translatesAutoresizingMaskIntoConstraints = NO;

    [cell addSubview:icon];
    [cell addSubview:texts];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:10],
        [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:32],
        [icon.heightAnchor constraintEqualToConstant:32],
        [texts.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:10],
        [texts.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-10],
        [texts.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
    ]];
    return cell;
}

- (BOOL)rowEnabled:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)self.rows.count) return NO;
    id disabled = self.rows[(NSUInteger)row][@"disabled"];
    return !([disabled respondsToSelector:@selector(boolValue)] && [disabled boolValue]);
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    NSInteger selected = self.tableView.selectedRow;
    if (selected < 0 || selected >= (NSInteger)self.rows.count) return;
    NSDictionary *row = self.rows[(NSUInteger)selected];
    [self fireCallback:@"select" errorName:@"hs.ui.list select" resultBool:nil pushArgs:^int(LuaSkin *skin, lua_State *L) {
        [skin pushNSObject:row];
        lua_pushinteger(L, selected + 1);
        return 2;
    }];
}

- (void)doubleClick:(id)sender { (void)sender; [self confirmSelection]; }
- (NSInteger)selectedLuaIndex { __block NSInteger row = -1; runOnMainSync(^{ row = self.tableView.selectedRow; }); return row >= 0 ? row + 1 : 0; }
- (void)selectLuaIndex:(NSInteger)index { NSInteger row = index - 1; if (row < 0 || row >= (NSInteger)self.rows.count) return; runOnMainSync(^{ [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row] byExtendingSelection:NO]; [self.tableView scrollRowToVisible:row]; }); }
- (void)selectNext { NSInteger row = self.tableView.selectedRow < 0 ? 0 : self.tableView.selectedRow + 1; while (row < (NSInteger)self.rows.count && ![self rowEnabled:row]) row++; if (row < (NSInteger)self.rows.count) [self selectLuaIndex:row + 1]; }
- (void)selectPrevious { NSInteger row = self.tableView.selectedRow < 0 ? (NSInteger)self.rows.count - 1 : self.tableView.selectedRow - 1; while (row >= 0 && ![self rowEnabled:row]) row--; if (row >= 0) [self selectLuaIndex:row + 1]; }
- (void)confirmSelection { NSInteger selected = self.tableView.selectedRow; if (selected < 0 || selected >= (NSInteger)self.rows.count || ![self rowEnabled:selected]) return; NSDictionary *row = self.rows[(NSUInteger)selected]; [self fireCallback:@"confirm" errorName:@"hs.ui.list confirm" resultBool:nil pushArgs:^int(LuaSkin *skin, lua_State *L) { [skin pushNSObject:row]; lua_pushinteger(L, selected + 1); return 2; }]; }
- (BOOL)handleKeyDown:(NSEvent *)event { __block BOOL consumed = NO; [self fireCallback:@"keyDown" errorName:@"hs.ui.list keyDown" resultBool:&consumed pushArgs:^int(LuaSkin *skin, lua_State *L) { (void)skin; pushKeyEvent(L, event); return 1; }]; if (consumed) return YES; return self.panel ? [self.panel handleKeyDown:event] : NO; }
- (HSUIList *)firstList { return self; }
@end

@implementation HSUIStack
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx {
    self = [super initWithRefTable:table];
    if (!self) return nil;
    _children = [NSMutableArray array];
    NSString *orientation = stringField(L, idx, "orientation", @"vertical");
    CGFloat spacing = numberField(L, idx, "spacing", 0);
    CGFloat top = 0, left = 0, bottom = 0, right = 0;
    lua_getfield(L, idx, "padding");
    if (lua_type(L, -1) == LUA_TTABLE) {
        int pidx = lua_gettop(L);
        top = numberField(L, pidx, "top", 0); left = numberField(L, pidx, "left", 0); bottom = numberField(L, pidx, "bottom", 0); right = numberField(L, pidx, "right", 0);
    }
    lua_pop(L, 1);
    [self readLayoutFromLua:L index:idx defaultGrow:YES];
    runOnMainSync(^{
        self.stackView = [[NSStackView alloc] initWithFrame:NSZeroRect];
        self.stackView.orientation = [orientation isEqualToString:@"horizontal"] ? NSUserInterfaceLayoutOrientationHorizontal : NSUserInterfaceLayoutOrientationVertical;
        self.stackView.spacing = spacing;
        self.stackView.edgeInsets = NSEdgeInsetsMake(top, left, bottom, right);
        self.stackView.distribution = NSStackViewDistributionFill;
        self.stackView.alignment = [orientation isEqualToString:@"horizontal"] ? NSLayoutAttributeCenterY : NSLayoutAttributeLeading;
        self.stackView.translatesAutoresizingMaskIntoConstraints = NO;
        self.view = self.stackView;
        [self applyLayout];
    });
    lua_getfield(L, idx, "views");
    if (lua_type(L, -1) == LUA_TTABLE) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        for (lua_Integer i = 1; i <= (lua_Integer)lua_rawlen(L, -1); i++) {
            lua_rawgeti(L, -1, i);
            HSUIView *child = nil;
            if (luaL_testudata(L, -1, TAG_TEXTFIELD)) child = [skin luaObjectAtIndex:-1 toClass:"HSUITextField"];
            else if (luaL_testudata(L, -1, TAG_LIST)) child = [skin luaObjectAtIndex:-1 toClass:"HSUIList"];
            else if (luaL_testudata(L, -1, TAG_STACK)) child = [skin luaObjectAtIndex:-1 toClass:"HSUIStack"];
            else if (luaL_testudata(L, -1, TAG_IMAGE)) child = [skin luaObjectAtIndex:-1 toClass:"HSUIImage"];
            if (child) [self addView:child];
            lua_pop(L, 1);
        }
    }
    lua_pop(L, 1);
    return self;
}
- (void)addView:(HSUIView *)view { if (!view || [self.children containsObject:view]) return; [self.children addObject:view]; [view containerRetain]; [view assignPanel:self.panel]; runOnMainSync(^{ [self.stackView addArrangedSubview:view.view]; }); }
- (void)removeView:(HSUIView *)view { if (!view) return; [self.children removeObject:view]; runOnMainSync(^{ [self.stackView removeArrangedSubview:view.view]; [view.view removeFromSuperview]; }); [view containerRelease]; }
- (void)assignPanel:(HSUIPanel *)panel { [super assignPanel:panel]; for (HSUIView *child in self.children) [child assignPanel:panel]; }
- (HSUIList *)firstList { for (HSUIView *child in self.children) { HSUIList *list = [child firstList]; if (list) return list; } return nil; }
- (void)cleanup { for (HSUIView *child in self.children) { [child containerRelease]; [child cleanup]; } [self.children removeAllObjects]; [super cleanup]; }
@end

@implementation HSUIImage
- (instancetype)initWithLuaState:(lua_State *)L refTable:(LSRefTable)table optionsIndex:(int)idx {
    self = [super initWithRefTable:table];
    if (!self) return nil;
    NSString *path = stringField(L, idx, "path", nil);
    NSString *symbol = stringField(L, idx, "systemSymbol", nil);
    BOOL iconForFile = boolField(L, idx, "iconForFile", NO);
    CGFloat size = numberField(L, idx, "size", 0);
    [self readLayoutFromLua:L index:idx defaultGrow:NO];
    if (size > 0) { self.preferredWidth = size; self.preferredHeight = size; }
    runOnMainSync(^{
        NSImage *image = nil;
        if (path && iconForFile) image = [[NSWorkspace sharedWorkspace] iconForFile:path];
        else if (path) image = [[NSImage alloc] initWithContentsOfFile:path];
        else if (symbol) image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:symbol];
        self.imageView = [[NSImageView alloc] initWithFrame:NSZeroRect];
        self.imageView.image = image;
        self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        self.view = self.imageView;
        [self applyLayout];
    });
    return self;
}
@end

static HSUIView *viewAtIndex(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    if (luaL_testudata(L, idx, TAG_TEXTFIELD)) return [skin luaObjectAtIndex:idx toClass:"HSUITextField"];
    if (luaL_testudata(L, idx, TAG_LIST)) return [skin luaObjectAtIndex:idx toClass:"HSUIList"];
    if (luaL_testudata(L, idx, TAG_STACK)) return [skin luaObjectAtIndex:idx toClass:"HSUIStack"];
    if (luaL_testudata(L, idx, TAG_IMAGE)) return [skin luaObjectAtIndex:idx toClass:"HSUIImage"];
    luaL_error(L, "expected hs.ui view object");
    return nil;
}

static int pushObject(lua_State *L, id obj, const char *tag) {
    if ([obj respondsToSelector:@selector(setSelfRefCount:)]) [obj setSelfRefCount:([obj selfRefCount] + 1)];
    void **ptr = lua_newuserdata(L, sizeof(void *));
    *ptr = (__bridge_retained void *)obj;
    luaL_getmetatable(L, tag);
    lua_setmetatable(L, -2);
    return 1;
}
static int pushPanel(lua_State *L, id obj) { return pushObject(L, obj, TAG_PANEL); }
static int pushStack(lua_State *L, id obj) { return pushObject(L, obj, TAG_STACK); }
static int pushTextField(lua_State *L, id obj) { return pushObject(L, obj, TAG_TEXTFIELD); }
static int pushList(lua_State *L, id obj) { return pushObject(L, obj, TAG_LIST); }
static int pushImage(lua_State *L, id obj) { return pushObject(L, obj, TAG_IMAGE); }

static id toPanel(lua_State *L, int idx) { return luaL_testudata(L, idx, TAG_PANEL) ? GET_OBJECT(HSUIPanel, L, idx, TAG_PANEL) : nil; }
static id toStack(lua_State *L, int idx) { return luaL_testudata(L, idx, TAG_STACK) ? GET_OBJECT(HSUIStack, L, idx, TAG_STACK) : nil; }
static id toTextField(lua_State *L, int idx) { return luaL_testudata(L, idx, TAG_TEXTFIELD) ? GET_OBJECT(HSUITextField, L, idx, TAG_TEXTFIELD) : nil; }
static id toList(lua_State *L, int idx) { return luaL_testudata(L, idx, TAG_LIST) ? GET_OBJECT(HSUIList, L, idx, TAG_LIST) : nil; }
static id toImage(lua_State *L, int idx) { return luaL_testudata(L, idx, TAG_IMAGE) ? GET_OBJECT(HSUIImage, L, idx, TAG_IMAGE) : nil; }

static int userdata_tostring(lua_State *L) { lua_pushfstring(L, "hs.ui object: %p", lua_topointer(L, 1)); return 1; }
static int panel_gc(lua_State *L) { HSUIPanel *obj = GET_OBJECT_TRANSFER(HSUIPanel, L, 1, TAG_PANEL); if (obj) { obj.selfRefCount--; if (obj.selfRefCount <= 0) [obj cleanup]; } lua_pushnil(L); lua_setmetatable(L, 1); return 0; }
static int view_gc(lua_State *L, const char *tag) { HSUIView *obj = (__bridge_transfer HSUIView *)*((void **)luaL_checkudata(L, 1, tag)); if (obj) { obj.selfRefCount--; if (obj.selfRefCount <= 0 && obj.containerRefCount <= 0) [obj cleanup]; } lua_pushnil(L); lua_setmetatable(L, 1); return 0; }
static int stack_gc(lua_State *L) { return view_gc(L, TAG_STACK); }
static int textField_gc(lua_State *L) { return view_gc(L, TAG_TEXTFIELD); }
static int list_gc(lua_State *L) { return view_gc(L, TAG_LIST); }
static int image_gc(lua_State *L) { return view_gc(L, TAG_IMAGE); }

static int panel_new(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TTABLE, LS_TBREAK]; [skin pushNSObject:[[HSUIPanel alloc] initWithLuaState:L refTable:refTable optionsIndex:1]]; return 1; }
static int stack_new(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TTABLE, LS_TBREAK]; [skin pushNSObject:[[HSUIStack alloc] initWithLuaState:L refTable:refTable optionsIndex:1]]; return 1; }
static int textField_new(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TTABLE, LS_TBREAK]; [skin pushNSObject:[[HSUITextField alloc] initWithLuaState:L refTable:refTable optionsIndex:1]]; return 1; }
static int list_new(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TTABLE, LS_TBREAK]; [skin pushNSObject:[[HSUIList alloc] initWithLuaState:L refTable:refTable optionsIndex:1]]; return 1; }
static int image_new(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TTABLE, LS_TBREAK]; [skin pushNSObject:[[HSUIImage alloc] initWithLuaState:L refTable:refTable optionsIndex:1]]; return 1; }

static int panel_setContent(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TANY, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; HSUIView *view = viewAtIndex(L, 2); if (panel.content && panel.content != view) [panel.content containerRelease]; panel.content = view; [view containerRetain]; [view assignPanel:panel]; runOnMainSync(^{ for (NSView *subview in panel.rootView.subviews.copy) [subview removeFromSuperview]; [panel.rootView addSubview:view.view]; [NSLayoutConstraint activateConstraints:@[[view.view.leadingAnchor constraintEqualToAnchor:panel.rootView.leadingAnchor], [view.view.trailingAnchor constraintEqualToAnchor:panel.rootView.trailingAnchor], [view.view.topAnchor constraintEqualToAnchor:panel.rootView.topAnchor], [view.view.bottomAnchor constraintEqualToAnchor:panel.rootView.bottomAnchor]]]; }); lua_pushvalue(L, 1); return 1; }
static int panel_show(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; runOnMainSync(^{ [NSApp activateIgnoringOtherApps:YES]; [panel.window makeKeyAndOrderFront:nil]; }); lua_pushvalue(L, 1); return 1; }
static int panel_hide(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIPanel"] hidePanel]; lua_pushvalue(L, 1); return 1; }
static int panel_delete(lua_State *L) { return panel_gc(L); }
static int panel_frame(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; if (lua_gettop(L) == 2) { NSRect rect = [skin tableToRectAtIndex:2]; runOnMainSync(^{ [panel.window setFrame:hsToAppKitRect(rect) display:YES]; }); lua_pushvalue(L, 1); return 1; } __block NSRect rect; runOnMainSync(^{ rect = appKitToHSRect(panel.window.frame); }); [skin pushNSRect:rect]; return 1; }
static int panel_centerOnScreen(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; runOnMainSync(^{ [panel.window center]; }); lua_pushvalue(L, 1); return 1; }
static int panel_centerNearMouse(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; runOnMainSync(^{ NSPoint mouse = NSEvent.mouseLocation; NSRect frame = panel.window.frame; frame.origin.x = mouse.x - frame.size.width / 2.0; frame.origin.y = mouse.y - frame.size.height / 2.0; [panel.window setFrame:frame display:YES]; }); lua_pushvalue(L, 1); return 1; }
static int panel_focus(lua_State *L) { return panel_show(L); }
static int panel_on(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_PANEL, LS_TSTRING, LS_TFUNCTION | LS_TNIL, LS_TBREAK]; HSUIPanel *panel = [skin luaObjectAtIndex:1 toClass:"HSUIPanel"]; return [panel setCallbackFromLua:L event:[skin toNSObjectAtIndex:2]]; }

static int text_value(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_TEXTFIELD, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK]; HSUITextField *field = [skin luaObjectAtIndex:1 toClass:"HSUITextField"]; if (lua_gettop(L) == 2) { NSString *value = [skin toNSObjectAtIndex:2]; runOnMainSync(^{ field.textField.stringValue = value ?: @""; }); lua_pushvalue(L, 1); return 1; } __block NSString *value; runOnMainSync(^{ value = field.textField.stringValue ?: @""; }); [skin pushNSObject:value]; return 1; }
static int text_placeholder(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_TEXTFIELD, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK]; HSUITextField *field = [skin luaObjectAtIndex:1 toClass:"HSUITextField"]; if (lua_gettop(L) == 2) { NSString *value = [skin toNSObjectAtIndex:2]; runOnMainSync(^{ field.textField.placeholderString = value ?: @""; }); lua_pushvalue(L, 1); return 1; } __block NSString *value; runOnMainSync(^{ value = field.textField.placeholderString ?: @""; }); [skin pushNSObject:value]; return 1; }
static int text_focus(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_TEXTFIELD, LS_TBREAK]; HSUITextField *field = [skin luaObjectAtIndex:1 toClass:"HSUITextField"]; runOnMainSync(^{ [field.textField.window makeFirstResponder:field.textField]; }); lua_pushvalue(L, 1); return 1; }
static int text_on(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_TEXTFIELD, LS_TSTRING, LS_TFUNCTION | LS_TNIL, LS_TBREAK]; HSUITextField *field = [skin luaObjectAtIndex:1 toClass:"HSUITextField"]; return [field setCallbackFromLua:L event:[skin toNSObjectAtIndex:2] allowed:@[@"change", @"submit", @"escape", @"keyDown"]]; }

static int list_rows(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TTABLE, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIList"] setRowsFromLua:L index:2]; lua_pushvalue(L, 1); return 1; }
static int list_selectedRow(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK]; HSUIList *list = [skin luaObjectAtIndex:1 toClass:"HSUIList"]; if (lua_gettop(L) == 2) { [list selectLuaIndex:(NSInteger)lua_tointeger(L, 2)]; lua_pushvalue(L, 1); return 1; } NSInteger idx = [list selectedLuaIndex]; if (idx > 0) lua_pushinteger(L, idx); else lua_pushnil(L); return 1; }
static int list_selectedId(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TBREAK]; HSUIList *list = [skin luaObjectAtIndex:1 toClass:"HSUIList"]; NSInteger idx = [list selectedLuaIndex]; if (idx > 0 && idx <= (NSInteger)list.rows.count && list.rows[(NSUInteger)(idx - 1)][@"id"]) [skin pushNSObject:list.rows[(NSUInteger)(idx - 1)][@"id"]]; else lua_pushnil(L); return 1; }
static int list_selectNext(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIList"] selectNext]; lua_pushvalue(L, 1); return 1; }
static int list_selectPrevious(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIList"] selectPrevious]; lua_pushvalue(L, 1); return 1; }
static int list_on(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_LIST, LS_TSTRING, LS_TFUNCTION | LS_TNIL, LS_TBREAK]; HSUIList *list = [skin luaObjectAtIndex:1 toClass:"HSUIList"]; return [list setCallbackFromLua:L event:[skin toNSObjectAtIndex:2] allowed:@[@"select", @"confirm", @"keyDown"]]; }

static int stack_addView(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_STACK, LS_TANY, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIStack"] addView:viewAtIndex(L, 2)]; lua_pushvalue(L, 1); return 1; }
static int stack_removeView(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_STACK, LS_TANY, LS_TBREAK]; [[skin luaObjectAtIndex:1 toClass:"HSUIStack"] removeView:viewAtIndex(L, 2)]; lua_pushvalue(L, 1); return 1; }
static int stack_spacing(lua_State *L) { LuaSkin *skin = [LuaSkin sharedWithState:L]; [skin checkArgs:LS_TUSERDATA, TAG_STACK, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK]; HSUIStack *stack = [skin luaObjectAtIndex:1 toClass:"HSUIStack"]; if (lua_gettop(L) == 2) { CGFloat spacing = (CGFloat)lua_tonumber(L, 2); runOnMainSync(^{ stack.stackView.spacing = spacing; }); lua_pushvalue(L, 1); return 1; } __block CGFloat spacing; runOnMainSync(^{ spacing = stack.stackView.spacing; }); lua_pushnumber(L, spacing); return 1; }

static const luaL_Reg panelLib[] = {{"setContent", panel_setContent}, {"show", panel_show}, {"hide", panel_hide}, {"delete", panel_delete}, {"frame", panel_frame}, {"centerOnScreen", panel_centerOnScreen}, {"centerNearMouse", panel_centerNearMouse}, {"focus", panel_focus}, {"on", panel_on}, {"__tostring", userdata_tostring}, {"__gc", panel_gc}, {NULL, NULL}};
static const luaL_Reg stackLib[] = {{"addView", stack_addView}, {"removeView", stack_removeView}, {"spacing", stack_spacing}, {"__tostring", userdata_tostring}, {"__gc", stack_gc}, {NULL, NULL}};
static const luaL_Reg textLib[] = {{"value", text_value}, {"placeholder", text_placeholder}, {"focus", text_focus}, {"on", text_on}, {"__tostring", userdata_tostring}, {"__gc", textField_gc}, {NULL, NULL}};
static const luaL_Reg listLib[] = {{"rows", list_rows}, {"selectedRow", list_selectedRow}, {"selectedId", list_selectedId}, {"selectNext", list_selectNext}, {"selectPrevious", list_selectPrevious}, {"on", list_on}, {"__tostring", userdata_tostring}, {"__gc", list_gc}, {NULL, NULL}};
static const luaL_Reg imageLib[] = {{"__tostring", userdata_tostring}, {"__gc", image_gc}, {NULL, NULL}};
static const luaL_Reg moduleLib[] = {{NULL, NULL}};

static void constructorTable(lua_State *L, lua_CFunction fn) { lua_newtable(L); lua_pushcfunction(L, fn); lua_setfield(L, -2, "new"); }

int luaopen_hs_libui(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs.ui" functions:moduleLib metaFunctions:nil];
    [skin registerObject:TAG_PANEL objectFunctions:panelLib];
    [skin registerObject:TAG_STACK objectFunctions:stackLib];
    [skin registerObject:TAG_TEXTFIELD objectFunctions:textLib];
    [skin registerObject:TAG_LIST objectFunctions:listLib];
    [skin registerObject:TAG_IMAGE objectFunctions:imageLib];
    [skin registerPushNSHelper:pushPanel forClass:"HSUIPanel"]; [skin registerLuaObjectHelper:toPanel forClass:"HSUIPanel" withUserdataMapping:TAG_PANEL];
    [skin registerPushNSHelper:pushStack forClass:"HSUIStack"]; [skin registerLuaObjectHelper:toStack forClass:"HSUIStack" withUserdataMapping:TAG_STACK];
    [skin registerPushNSHelper:pushTextField forClass:"HSUITextField"]; [skin registerLuaObjectHelper:toTextField forClass:"HSUITextField" withUserdataMapping:TAG_TEXTFIELD];
    [skin registerPushNSHelper:pushList forClass:"HSUIList"]; [skin registerLuaObjectHelper:toList forClass:"HSUIList" withUserdataMapping:TAG_LIST];
    [skin registerPushNSHelper:pushImage forClass:"HSUIImage"]; [skin registerLuaObjectHelper:toImage forClass:"HSUIImage" withUserdataMapping:TAG_IMAGE];
    constructorTable(L, panel_new); lua_setfield(L, -2, "panel");
    constructorTable(L, stack_new); lua_setfield(L, -2, "stack");
    constructorTable(L, textField_new); lua_setfield(L, -2, "textField");
    constructorTable(L, list_new); lua_setfield(L, -2, "list");
    constructorTable(L, image_new); lua_setfield(L, -2, "image");
    return 1;
}
