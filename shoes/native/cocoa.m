//
// shoes/native-cocoa.m
// ObjC Cocoa-specific code for Shoes.
//
#include "shoes/app.h"
#include "shoes/ruby.h"
#include "shoes/config.h"
#include "shoes/world.h"
#include "shoes/native.h"
#include "shoes/internal.h"
#include <Carbon/Carbon.h>

#define HEIGHT_PAD 6

#define INIT    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]
#define RELEASE [pool release]

@implementation ShoesEvents
- (id)init
{
  if ((self = [super init]))
    count = 0;
  return self;
}
- (void)idle: (NSTimer *)t
{
  if (count < 100)
  {
    count++;
    if (count == 100 && RARRAY_LEN(shoes_world->apps) == 0)
      rb_eval_string("Shoes.show_selector");
  }
  rb_eval_string("sleep(0.001)");
}
- (BOOL) application: (NSApplication *) anApplication
    openFile: (NSString *) aFileName
{
  shoes_load([aFileName UTF8String]);

  return YES;
}
- (void)openFile: (id)sender
{
  rb_eval_string("Shoes.show_selector");
}
- (void)package: (id)sender
{
  rb_eval_string("Shoes.make_pack");
}
- (void)showLog: (id)sender
{
  rb_eval_string("Shoes.show_log");
}
- (void)help: (id)sender
{
  rb_eval_string("Shoes.show_manual");
}
@end

@implementation ShoesWindow
- (void)prepareWithApp: (VALUE)a
{
  app = a;
  [self center];
  [self makeKeyAndOrderFront: self];
  [self setAcceptsMouseMovedEvents: YES];
  [self setDelegate: self];
}
- (void)sendMotion: (NSEvent *)e ofType: (ID)type withButton: (int)b
{
  shoes_app *a;
  shoes_canvas *canvas;
  NSPoint p = [e locationInWindow];
  Data_Get_Struct(app, shoes_app, a);
  Data_Get_Struct(a->canvas, shoes_canvas, canvas);
  if (type == s_motion)
    shoes_app_motion(a, p.x, (canvas->height - p.y) + canvas->slot.scrolly);
  else if (type == s_click)
    shoes_app_click(a, b, p.x, (canvas->height - p.y) + canvas->slot.scrolly);
  else if (type == s_release)
    shoes_app_release(a, b, p.x, (canvas->height - p.y) + canvas->slot.scrolly);
}
- (void)mouseDown: (NSEvent *)e
{
  [self sendMotion: e ofType: s_click withButton: 1];
}
- (void)rightMouseDown: (NSEvent *)e
{
  [self sendMotion: e ofType: s_click withButton: 2];
}
- (void)otherMouseDown: (NSEvent *)e
{
  [self sendMotion: e ofType: s_click withButton: 3];
}
- (void)mouseUp: (NSEvent *)e
{
  [self sendMotion: e ofType: s_release withButton: 1];
}
- (void)rightMouseUp: (NSEvent *)e
{
  [self sendMotion: e ofType: s_release withButton: 2];
}
- (void)otherMouseUp: (NSEvent *)e
{
  [self sendMotion: e ofType: s_release withButton: 3];
}
- (void)mouseMoved: (NSEvent *)e
{
  [self sendMotion: e ofType: s_motion withButton: 0];
}
- (void)mouseDragged: (NSEvent *)e
{
  [self sendMotion: e ofType: s_motion withButton: 0];
}
- (void)rightMouseDragged: (NSEvent *)e
{
  [self sendMotion: e ofType: s_motion withButton: 0];
}
- (void)otherMouseDragged: (NSEvent *)e
{
  [self sendMotion: e ofType: s_motion withButton: 0];
}
- (void)scrollWheel: (NSEvent *)e
{
  ID wheel;
  float dy = [e deltaY];
  NSPoint p = [e locationInWindow];
  shoes_app *a;

  if (dy == 0)
    return;
  else if (dy > 0)
    wheel = s_up;
  else
  {
    wheel = s_down;
    dy = -dy;
  }

  Data_Get_Struct(app, shoes_app, a);
  for (; dy > 0.; dy--)
    shoes_app_wheel(a, wheel, p.x, p.y);
}
- (void)keyDown: (NSEvent *)e
{
  shoes_app *a;
  VALUE v = Qnil;
  unsigned int modifier = [e modifierFlags];
  unsigned short key = [e keyCode];
  INIT;

  Data_Get_Struct(app, shoes_app, a);
  KEY_SYM(TAB, tab)
  KEY_SYM(BS, backspace)
  KEY_SYM(PRIOR, page_up)
  KEY_SYM(NEXT, page_down)
  KEY_SYM(HOME, home)
  KEY_SYM(END, end)
  KEY_SYM(LEFT, left)
  KEY_SYM(UP, up)
  KEY_SYM(RIGHT, right)
  KEY_SYM(DOWN, down)
  KEY_SYM(F1, f1)
  KEY_SYM(F2, f2)
  KEY_SYM(F3, f3)
  KEY_SYM(F4, f4)
  KEY_SYM(F5, f5)
  KEY_SYM(F6, f6)
  KEY_SYM(F7, f7)
  KEY_SYM(F8, f8)
  KEY_SYM(F9, f9)
  KEY_SYM(F10, f10)
  KEY_SYM(F11, f11)
  KEY_SYM(F12, f12)
  {
    NSString *str = [e charactersIgnoringModifiers];
    if (str)
    {
      char *utf8 = [str UTF8String];
      if (utf8[0] == '\r' && [str length] == 1)
        v = rb_str_new2("\n");
      else
        v = rb_str_new2(utf8);
    }
  }

  if (SYMBOL_P(v))
  {
    if ((modifier & NSCommandKeyMask) || (modifier & NSAlternateKeyMask))
      KEY_STATE(alt);
    if (modifier & NSShiftKeyMask)
      KEY_STATE(shift);
    if (modifier & NSControlKeyMask)
      KEY_STATE(control);
  }
  else
  {
    if ((modifier & NSCommandKeyMask) || (modifier & NSAlternateKeyMask))
      KEY_STATE(alt);
  }

  if (v != Qnil)
    shoes_app_keypress(a, v);
  RELEASE;
}
- (void)windowWillClose: (NSNotification *)n
{
  shoes_app *a;
  Data_Get_Struct(app, shoes_app, a);
  shoes_app_remove(a);
}
@end

@implementation ShoesView
- (id)initWithFrame: (NSRect)frame andCanvas: (VALUE)c
{
  if ((self = [super initWithFrame: frame]))
  {
    canvas = c;
  }
  return self;
}
- (BOOL)isFlipped
{
  return YES;
}
- (void)drawRect: (NSRect)rect
{
  shoes_canvas *c;
  NSRect bounds = [self bounds];
  Data_Get_Struct(canvas, shoes_canvas, c);

  c->width = bounds.size.width;
  c->height = bounds.size.height;
  if (c->slot.vscroll)
  {
    [c->slot.vscroll setFrame: NSMakeRect(c->width - [NSScroller scrollerWidth], 0,
      [NSScroller scrollerWidth], c->height)];
    shoes_native_slot_lengthen(&c->slot, c->height, c->endy);
  }
  c->place.iw = c->place.w = c->width;
  c->place.ih = c->place.h = c->height;
  c->slot.context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  shoes_canvas_paint(canvas);
}
- (void)scroll: (NSScroller *)scroller
{
  shoes_canvas *c;
  Data_Get_Struct(canvas, shoes_canvas, c);

  switch ([scroller hitPart])
  {
    case NSScrollerIncrementLine:
      shoes_slot_scroll_to(c, 16, 1);
    break;
    case NSScrollerDecrementLine:
      shoes_slot_scroll_to(c, -16, 1);
    break;
    case NSScrollerIncrementPage:
      shoes_slot_scroll_to(c, c->height - 32, 1);
    break;
    case NSScrollerDecrementPage:
      shoes_slot_scroll_to(c, -(c->height - 32), 1);
    break;
    case NSScrollerKnobSlot:
    case NSScrollerKnob:
    default:
      shoes_slot_scroll_to(c, (c->endy - c->height) * [scroller floatValue], 0);
    break;
  }
}
@end

@implementation ShoesButton
- (id)initWithType: (NSButtonType)t andObject: (VALUE)o
{
  if ((self = [super init]))
  {
    object = o;
    [self setButtonType: t];
    [self setBezelStyle: NSRoundedBezelStyle];
    [self setTarget: self];
    [self setAction: @selector(handleClick:)];
  }
  return self;
}
-(IBAction)handleClick: (id)sender
{
  shoes_button_send_click(object);
}
@end

@implementation ShoesTextField
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o isSecret: (BOOL)secret
{
  if ((self = [super initWithFrame: frame]))
  {
    object = o;
    // [[self cell] setEchosBullets: secret];
    [self setBezelStyle: NSRegularSquareBezelStyle];
    [self setDelegate: self];
  }
  return self;
}
-(void)textDidChange: (NSNotification *)n
{
  shoes_control_send(object, s_change);
}
@end

@implementation ShoesTextView
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame]))
  {
    object = o;
    textView = [[NSTextView alloc] initWithFrame:
      NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    [textView setVerticallyResizable: YES];
    [textView setHorizontallyResizable: YES];
    
    [self setBorderType: NSBezelBorder];
    [self setHasVerticalScroller: YES];
    [self setHasHorizontalScroller: NO];
    [self setDocumentView: textView];
    [textView setDelegate: self];
  }
  return self;
}
-(NSTextStorage *)textStorage
{
  return [textView textStorage];
}
-(void)textDidChange: (NSNotification *)n
{
  shoes_control_send(object, s_change);
}
@end

@implementation ShoesPopUpButton
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame pullsDown: NO]))
  {
    object = o;
    [self setTarget: self];
    [self setAction: @selector(handleChange:)];
  }
  return self;
}
-(IBAction)handleChange: (id)sender
{
  shoes_control_send(object, s_change);
}
@end

@implementation ShoesTimer
- (id)initWithTimeInterval: (NSTimeInterval)i andObject: (VALUE)o repeats: (BOOL)r
{
  if ((self = [super init]))
  {
    object = o;
    timer = [NSTimer scheduledTimerWithTimeInterval: i
      target: self selector: @selector(animate:) userInfo: self
      repeats: r];
  }
  return self;
}
- (void)animate: (NSTimer *)t
{
  shoes_timer_call(object);
}
- (void)invalidate
{
  [timer invalidate];
}
@end

void
add_to_menubar(NSMenu *main, NSMenu *menu)
{
    NSMenuItem *dummyItem = [[NSMenuItem alloc] initWithTitle:@""
        action:nil keyEquivalent:@""];
    [dummyItem setSubmenu:menu];
    [main addItem:dummyItem];
    [dummyItem release];
}

void
create_apple_menu(NSMenu *main)
{
    NSMenuItem *menuitem;
    // Create the application (Apple) menu.
    NSMenu *menuApp = [[NSMenu alloc] initWithTitle: @"Apple Menu"];

    NSMenu *menuServices = [[NSMenu alloc] initWithTitle: @"Services"];
    [NSApp setServicesMenu:menuServices];

    menuitem = [menuApp addItemWithTitle:@"Open..."
        action:@selector(openFile:) keyEquivalent:@"o"];
    [menuitem setTarget: shoes_world->os.events];
    menuitem = [menuApp addItemWithTitle:@"Package..."
        action:@selector(package:) keyEquivalent:@"x"];
    [menuitem setTarget: shoes_world->os.events];
    [menuApp addItemWithTitle:@"Preferences..." action:nil keyEquivalent:@""];
    [menuApp addItem: [NSMenuItem separatorItem]];
    menuitem = [[NSMenuItem alloc] initWithTitle: @"Services"
        action:nil keyEquivalent:@""];
    [menuitem setSubmenu:menuServices];
    [menuApp addItem: menuitem];
    [menuitem release];
    [menuApp addItem: [NSMenuItem separatorItem]];
    menuitem = [[NSMenuItem alloc] initWithTitle:@"Hide"
        action:@selector(hide:) keyEquivalent:@""];
    [menuitem setTarget: NSApp];
    [menuApp addItem: menuitem];
    [menuitem release];
    menuitem = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
        action:@selector(hideOtherApplications:) keyEquivalent:@""];
    [menuitem setTarget: NSApp];
    [menuApp addItem: menuitem];
    [menuitem release];
    menuitem = [[NSMenuItem alloc] initWithTitle:@"Show All"
        action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [menuitem setTarget: NSApp];
    [menuApp addItem: menuitem];
    [menuitem release];
    [menuApp addItem: [NSMenuItem separatorItem]];
    menuitem = [[NSMenuItem alloc] initWithTitle:@"Quit"
        action:@selector(terminate:) keyEquivalent:@"q"];
    [menuitem setTarget: NSApp];
    [menuApp addItem: menuitem];
    [menuitem release];

    [NSApp setAppleMenu:menuApp];
    add_to_menubar(main, menuApp);
    [menuApp release];
}

void
create_window_menu(NSMenu *main)
{   
    NSMenu *menuWindows = [[NSMenu alloc] initWithTitle: @"Window"];

    [menuWindows addItemWithTitle:@"Minimize"
        action:@selector(performMiniaturize:) keyEquivalent:@""];
    [menuWindows addItemWithTitle:@"Close current Window"
        action:@selector(performClose:) keyEquivalent:@"w"];
    [menuWindows addItem: [NSMenuItem separatorItem]];
    [menuWindows addItemWithTitle:@"Bring All to Front"
        action:@selector(arrangeInFront:) keyEquivalent:@""];

    [NSApp setWindowsMenu:menuWindows];
    add_to_menubar(main, menuWindows);
    [menuWindows release];
}

void
create_help_menu(NSMenu *main)
{   
    NSMenuItem *menuitem;
    NSMenu *menuHelp = [[NSMenu alloc] initWithTitle: @"Help"];
    menuitem = [menuHelp addItemWithTitle:@"Console"
        action:@selector(showLog:) keyEquivalent:@"/"];
    [menuitem setTarget: shoes_world->os.events];
    [menuHelp addItem: [NSMenuItem separatorItem]];
    menuitem = [menuHelp addItemWithTitle:@"Manual"
        action:@selector(help:) keyEquivalent:@"m"];
    [menuitem setTarget: shoes_world->os.events];
    add_to_menubar(main, menuHelp);
    [menuHelp release];
}

void shoes_native_init()
{
  INIT;
  NSTimer *idle;
  NSApplication *NSApp = [NSApplication sharedApplication];
  NSMenu *main = [[NSMenu alloc] initWithTitle: @""];
  shoes_world->os.events = [[ShoesEvents alloc] init];
  [NSApp setMainMenu: main];
  create_apple_menu(main);
  create_window_menu(main);
  create_help_menu(main);
  [NSApp setDelegate: shoes_world->os.events];

  idle = [NSTimer scheduledTimerWithTimeInterval: 0.01
    target: shoes_world->os.events selector: @selector(idle:) userInfo: nil
    repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: idle forMode: NSEventTrackingRunLoopMode];
  RELEASE;
}

void shoes_native_cleanup(shoes_world_t *world)
{
  INIT;
  [shoes_world->os.events release];
  RELEASE;
}

void shoes_native_quit()
{
  INIT;
  NSApplication *NSApp = [NSApplication sharedApplication];
  [NSApp stop: nil];
  RELEASE;
}

void shoes_get_time(SHOES_TIME *ts)
{
  gettimeofday(ts, NULL);
}

unsigned long shoes_diff_time(SHOES_TIME *start, SHOES_TIME *end)
{
  unsigned long usec;
  if ((end->tv_usec-start->tv_usec)<0) {
    usec = (end->tv_sec-start->tv_sec - 1) * 1000;
    usec += (1000000 + end->tv_usec - start->tv_usec) / 1000;
  } else {
    usec = (end->tv_sec - start->tv_sec) * 1000;
    usec += (end->tv_usec - start->tv_usec) / 1000;
  }
  return usec;
}

int shoes_throw_message(unsigned int name, VALUE obj, void *data)
{
  return shoes_catch_message(name, obj, data);
}

void shoes_native_slot_mark(SHOES_SLOT_OS *slot)
{
  rb_gc_mark_maybe(slot->controls);
}

void shoes_native_slot_reset(SHOES_SLOT_OS *slot)
{
  slot->controls = rb_ary_new();
  rb_gc_register_address(&slot->controls);
}

void shoes_native_slot_clear(shoes_canvas *canvas)
{
  rb_ary_clear(canvas->slot.controls);
  if (canvas->slot.vscroll)
  {
    shoes_native_slot_lengthen(&canvas->slot, canvas->height, 1);
  }
}

void shoes_native_slot_paint(SHOES_SLOT_OS *slot)
{
  [slot->view setNeedsDisplay: YES];
}

void shoes_native_slot_lengthen(SHOES_SLOT_OS *slot, int height, int endy)
{
  if (slot->vscroll)
  {
    float s = slot->scrolly * 1., e = endy * 1., h = height * 1., d = (endy - height) * 1.;
    [slot->vscroll setFloatValue: (d > 0 ? s / d : 0) knobProportion: (h / e)];
    [slot->vscroll setHidden: endy <= height ? YES : NO];
  }
}

void shoes_native_slot_scroll_top(SHOES_SLOT_OS *slot)
{
}

int shoes_native_slot_gutter(SHOES_SLOT_OS *slot)
{
  return (int)[NSScroller scrollerWidth];
}

void shoes_native_remove_item(SHOES_SLOT_OS *slot, VALUE item, char c)
{
  if (c)
  {
    long i = rb_ary_index_of(slot->controls, item);
    if (i >= 0)
      rb_ary_insert_at(slot->controls, i, 1, Qnil);
  }
}

shoes_code
shoes_app_cursor(shoes_app *app, ID cursor)
{
  if (app->os.window == NULL || app->cursor == cursor)
    goto done;

  if (cursor == s_hand || cursor == s_link)
    [[NSCursor pointingHandCursor] set];
  else if (cursor == s_arrow)
    [[NSCursor arrowCursor] set];
  else
    goto done;

  app->cursor = cursor;

done:
  return SHOES_OK;
}

void
shoes_native_app_resized(shoes_app *app)
{
  NSRect rect = [app->os.window frame];
  rect.size.width = app->width;
  rect.size.height = app->height;
  [app->os.window setFrame: rect display: YES];
}

void
shoes_native_app_title(shoes_app *app, char *msg)
{
  [app->os.window setTitle: [NSString stringWithUTF8String: msg]];
}

shoes_code
shoes_native_app_open(shoes_app *app, char *path, int dialog)
{
  INIT;
  unsigned int mask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
  shoes_code code = SHOES_OK;

  if (app->resizable)
    mask |= NSResizableWindowMask;
  app->os.window = [[ShoesWindow alloc] initWithContentRect: NSMakeRect(0, 0, app->width, app->height)
    styleMask: mask backing: NSBackingStoreBuffered defer: NO];
  [app->os.window prepareWithApp: app->self];
  app->slot.view = [app->os.window contentView];
  RELEASE;

quit:
  return code;
}

void
shoes_native_app_show(shoes_app *app)
{
  [app->os.window orderFront: nil];
}

void
shoes_native_loop()
{
  NSApplication *NSApp = [NSApplication sharedApplication];
  [NSApp run];
}

void
shoes_native_app_close(shoes_app *app)
{
  INIT;
  [app->os.window close];
  RELEASE;
}

void
shoes_browser_open(char *url)
{
  VALUE browser = rb_str_new2("open ");
  rb_str_cat2(browser, url);
  shoes_sys(RSTRING_PTR(browser), 1);
}

void
shoes_slot_init(VALUE c, SHOES_SLOT_OS *parent, int x, int y, int width, int height, int scrolls, int toplevel)
{
  INIT;
  shoes_canvas *canvas;
  SHOES_SLOT_OS *slot;
  Data_Get_Struct(c, shoes_canvas, canvas);
  slot = &canvas->slot;

  slot->controls = parent->controls;
  slot->view = [[ShoesView alloc] initWithFrame: NSMakeRect(x, y, width, height) andCanvas: c];
  [slot->view setAutoresizesSubviews: NO];
  if (toplevel)
    [slot->view setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  slot->vscroll = NULL;
  if (scrolls)
  {
    slot->vscroll = [[NSScroller alloc] initWithFrame: 
      NSMakeRect(width - [NSScroller scrollerWidth], 0, [NSScroller scrollerWidth], height)];
    [slot->vscroll setEnabled: YES];
    [slot->vscroll setTarget: slot->view];
    [slot->vscroll setAction: @selector(scroll:)];
    [slot->view addSubview: slot->vscroll];
  }
  if (parent->vscroll)
    [parent->view addSubview: slot->view positioned: NSWindowBelow relativeTo: parent->vscroll];
  else
    [parent->view addSubview: slot->view];
  RELEASE;
}

void
shoes_slot_destroy(shoes_canvas *canvas, shoes_canvas *pc)
{
  INIT;
  if (canvas->slot.vscroll != NULL)
    [canvas->slot.vscroll removeFromSuperview];
  [canvas->slot.view removeFromSuperview];
  RELEASE;
}

cairo_t *
shoes_cairo_create(shoes_canvas *canvas)
{
  cairo_t *cr;
  canvas->slot.surface = cairo_quartz_surface_create_for_cg_context(canvas->slot.context,
    canvas->width, canvas->height);
  cr = cairo_create(canvas->slot.surface);
  cairo_translate(cr, 0, 0 - canvas->slot.scrolly);
  return cr;
}

void shoes_cairo_destroy(shoes_canvas *canvas)
{
  cairo_surface_destroy(canvas->slot.surface);
}

void
shoes_group_clear(SHOES_GROUP_OS *group)
{
}

void
shoes_native_canvas_place(shoes_canvas *self_t, shoes_canvas *pc)
{
  NSRect rect, rect2;
  int newy = (self_t->place.iy + self_t->place.dy) - pc->slot.scrolly;
  rect.origin.x = (self_t->place.ix + self_t->place.dx) * 1.;
  rect.origin.y = ((newy) * 1.);
  rect.size.width = (self_t->place.iw * 1.);
  rect.size.height = (self_t->place.ih * 1.);
  rect2 = [self_t->slot.view frame];
  if (rect.origin.x != rect2.origin.x || rect.origin.y != rect2.origin.y ||
      rect.size.width != rect2.size.width || rect.size.height != rect2.size.height)
  {
    [self_t->slot.view setFrame: rect];
  }
}

void
shoes_native_canvas_resize(shoes_canvas *canvas)
{
  NSSize size = {canvas->width, canvas->height};
  [canvas->slot.view setFrameSize: size];
}

void
shoes_native_control_hide(SHOES_CONTROL_REF ref)
{
  [ref setHidden: YES];
}

void
shoes_native_control_show(SHOES_CONTROL_REF ref)
{
  [ref setHidden: NO];
}

static void
shoes_native_control_frame(SHOES_CONTROL_REF ref, shoes_place *p)
{
  NSRect rect;
  rect.origin.x = p->ix + p->dx; rect.origin.y = p->iy + p->dy;
  rect.size.width = p->iw; rect.size.height = p->ih;
  [ref setFrame: rect];
}

void
shoes_native_control_position(SHOES_CONTROL_REF ref, shoes_place *p1, VALUE self,
  shoes_canvas *canvas, shoes_place *p2)
{
  PLACE_COORDS();
  if (canvas->slot.vscroll)
    [canvas->slot.view addSubview: ref positioned: NSWindowBelow relativeTo: canvas->slot.vscroll];
  else
    [canvas->slot.view addSubview: ref];
  shoes_native_control_frame(ref, p2);
  rb_ary_push(canvas->slot.controls, self);
}

void
shoes_native_control_repaint(SHOES_CONTROL_REF ref, shoes_place *p1,
  shoes_canvas *canvas, shoes_place *p2)
{
  p2->iy -= canvas->slot.scrolly;
  if (CHANGED_COORDS()) {
    PLACE_COORDS();
    shoes_native_control_frame(ref, p2);
  }
  p2->iy += canvas->slot.scrolly;
}

void
shoes_native_control_focus(SHOES_CONTROL_REF ref)
{
}

void
shoes_native_control_remove(SHOES_CONTROL_REF ref, shoes_canvas *canvas)
{
  INIT;
  [ref removeFromSuperview];
  RELEASE;
}

void
shoes_native_control_free(SHOES_CONTROL_REF ref)
{
}

SHOES_SURFACE_REF
shoes_native_surface_new(shoes_canvas *canvas, VALUE self, shoes_place *place)
{
  return GetWindowPort([canvas->app->os.window windowRef]);
}

void
shoes_native_surface_position(SHOES_SURFACE_REF ref, shoes_place *p1, 
  VALUE self, shoes_canvas *canvas, shoes_place *p2)
{
  PLACE_COORDS();
}

void
shoes_native_surface_hide(SHOES_SURFACE_REF ref)
{
  HIViewSetVisible(ref, false);
}

void
shoes_native_surface_show(SHOES_SURFACE_REF ref)
{
  HIViewSetVisible(ref, true);
}

void
shoes_native_surface_remove(shoes_canvas *canvas, SHOES_SURFACE_REF ref)
{
}

SHOES_CONTROL_REF
shoes_native_button(VALUE self, shoes_canvas *canvas, shoes_place *place, char *msg)
{
  INIT;
  ShoesButton *button = [[ShoesButton alloc] initWithType: NSMomentaryPushInButton
    andObject: self];
  [button setTitle: [NSString stringWithUTF8String: msg]];
  RELEASE;
  return (NSControl *)button;
}

SHOES_CONTROL_REF
shoes_native_edit_line(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesTextField *field = [[ShoesTextField alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self isSecret:(RTEST(ATTR(attr, secret)) ? YES : NO)];
  [field setStringValue: [NSString stringWithUTF8String: msg]];
  [field setEditable: YES];
  RELEASE;
  return (NSControl *)field;
}

VALUE
shoes_native_edit_line_get_text(SHOES_CONTROL_REF ref)
{
  VALUE text = Qnil;
  INIT;
  text = rb_str_new2([[ref stringValue] UTF8String]);
  RELEASE;
  return text;
}

void
shoes_native_edit_line_set_text(SHOES_CONTROL_REF ref, char *msg)
{
  INIT;
  [ref setStringValue: [NSString stringWithUTF8String: msg]];
  RELEASE;
}

SHOES_CONTROL_REF
shoes_native_edit_box(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesTextView *tv = [[ShoesTextView alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  shoes_native_edit_box_set_text((NSControl *)tv, msg);
  RELEASE;
  return (NSControl *)tv;
}

VALUE
shoes_native_edit_box_get_text(SHOES_CONTROL_REF ref)
{
  VALUE text = Qnil;
  INIT;
  text = rb_str_new2([[[(ShoesTextView *)ref textStorage] string] UTF8String]);
  RELEASE;
  return text;
}

void
shoes_native_edit_box_set_text(SHOES_CONTROL_REF ref, char *msg)
{
  INIT;
  [[[(ShoesTextView *)ref textStorage] mutableString] setString: [NSString stringWithUTF8String: msg]];
  RELEASE;
}

SHOES_CONTROL_REF
shoes_native_list_box(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesPopUpButton *pop = [[ShoesPopUpButton alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  RELEASE;
  return (NSControl *)pop;
}

void
shoes_native_list_box_update(SHOES_CONTROL_REF ref, VALUE ary)
{
  INIT;
  long i;
  ShoesPopUpButton *pop = (ShoesPopUpButton *)ref;
  [pop removeAllItems];
  for (i = 0; i < RARRAY_LEN(ary); i++)
  {
    VALUE msg_s = shoes_native_to_s(rb_ary_entry(ary, i));
    char *msg = RSTRING_PTR(msg_s);
    [[pop menu] insertItemWithTitle: [NSString stringWithUTF8String: msg] action: nil
      keyEquivalent: @"" atIndex: i];
  }
  RELEASE;
}

VALUE
shoes_native_list_box_get_active(SHOES_CONTROL_REF ref, VALUE items)
{
  int sel = [(ShoesPopUpButton *)ref indexOfSelectedItem];
  if (sel >= 0)
    return rb_ary_entry(items, sel);
  return Qnil;
}

void
shoes_native_list_box_set_active(SHOES_CONTROL_REF ref, VALUE ary, VALUE item)
{
  int idx = rb_ary_index_of(ary, item);
  if (idx < 0) return;
  [(ShoesPopUpButton *)ref selectItemAtIndex: idx];
}

SHOES_CONTROL_REF
shoes_native_progress(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  NSProgressIndicator *pop = [[NSProgressIndicator alloc] init];
  [pop setIndeterminate: FALSE];
  [pop setDoubleValue: 0.];
  [pop setBezeled: YES];
  RELEASE;
  return (NSControl *)pop;
}

double
shoes_native_progress_get_fraction(SHOES_CONTROL_REF ref)
{
  return [(NSProgressIndicator *)ref doubleValue] * 0.01;
}

void
shoes_native_progress_set_fraction(SHOES_CONTROL_REF ref, double perc)
{
  [(NSProgressIndicator *)ref setDoubleValue: perc * 100.];
}

SHOES_CONTROL_REF
shoes_native_check(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesButton *button = [[ShoesButton alloc] initWithType: NSSwitchButton andObject: self];
  RELEASE;
  return (NSControl *)button;
}

VALUE
shoes_native_check_get(SHOES_CONTROL_REF ref)
{
  return [(ShoesButton *)ref state] == NSOnState ? Qtrue : Qfalse;
}

void
shoes_native_check_set(SHOES_CONTROL_REF ref, int on)
{
  [(ShoesButton *)ref setState: on ? NSOnState : NSOffState];
}

SHOES_CONTROL_REF
shoes_native_radio(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, VALUE group)
{
  INIT;
  ShoesButton *button = [[ShoesButton alloc] initWithType: NSRadioButton
    andObject: self];
  RELEASE;
  return (NSControl *)button;
}

void
shoes_native_timer_remove(shoes_canvas *canvas, SHOES_TIMER_REF ref)
{
  INIT;
  [ref invalidate];
  RELEASE;
}

SHOES_TIMER_REF
shoes_native_timer_start(VALUE self, shoes_canvas *canvas, unsigned int interval)
{
  INIT;
  ShoesTimer *timer = [[ShoesTimer alloc] initWithTimeInterval: interval * 0.001
    andObject: self repeats:(rb_obj_is_kind_of(self, cTimer) ? NO : YES)];
  RELEASE;
  return timer;
}

VALUE
shoes_native_clipboard_get(shoes_app *app)
{
  VALUE txt = Qnil;
  INIT;
  NSString *paste = [[NSPasteboard generalPasteboard] stringForType: NSStringPboardType];
  if (paste) txt = rb_str_new2([paste UTF8String]);
  RELEASE;
  return txt;
}

void
shoes_native_clipboard_set(shoes_app *app, VALUE string)
{
  INIT;
  [[NSPasteboard generalPasteboard] declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: nil];
  [[NSPasteboard generalPasteboard] setString: [NSString stringWithUTF8String: RSTRING_PTR(string)]
    forType: NSStringPboardType];
  RELEASE;
}

VALUE
shoes_native_to_s(VALUE text)
{
  text = rb_funcall(text, s_to_s, 0);
  return text;
}

VALUE
shoes_native_window_color(shoes_app *app)
{
  // float r, g, b, a;
  // INIT;
  // [[[app->os.window backgroundColor] colorUsingColorSpace: [NSColorSpace genericRGBColorSpace]] 
  //   getRed: &r green: &g blue: &b alpha: &a];
  // RELEASE;
  // return shoes_color_new((int)(r * 255), (int)(g * 255), (int)(b * 255), (int)(a * 255));
  return shoes_color_new(255, 255, 255, 255);
}

VALUE
shoes_native_dialog_color(shoes_app *app)
{
  return shoes_native_window_color(app);
}

VALUE
shoes_dialog_alert(VALUE self, VALUE msg)
{
  INIT;
  VALUE answer = Qnil;
  msg = shoes_native_to_s(msg);
  NSAlert *alert = [NSAlert alertWithMessageText: @"Shoes says:"
    defaultButton: @"OK" alternateButton: nil otherButton: nil 
    informativeTextWithFormat: [NSString stringWithUTF8String: RSTRING_PTR(msg)]];
  [alert runModal];
  RELEASE;
  return Qnil;
}

VALUE
shoes_dialog_ask(VALUE self, VALUE quiz)
{
  INIT;
  VALUE answer = Qnil;
  quiz = shoes_native_to_s(quiz);
  NSAlert *alert = [NSAlert alertWithMessageText: @"Shoes asks:"
    defaultButton:@"OK" alternateButton:@"Cancel" otherButton:nil
    informativeTextWithFormat: [NSString stringWithUTF8String: RSTRING_PTR(quiz)]];
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
  [input setStringValue:@""];
  [alert setAccessoryView:input];
  if ([alert runModal] == NSOKButton)
  {
    answer = rb_str_new2([[input stringValue] UTF8String]);
  }
  RELEASE;
  return answer;
}

VALUE
shoes_dialog_confirm(VALUE self, VALUE quiz)
{
  INIT;
  char *msg;
  VALUE answer = Qnil;
  quiz = shoes_native_to_s(quiz);
  msg = RSTRING_PTR(quiz);
  NSAlert *alert = [NSAlert alertWithMessageText: @"Shoes asks:"
    defaultButton: @"OK" alternateButton: @"Cancel" otherButton:nil 
    informativeTextWithFormat: [NSString stringWithUTF8String: msg]];
  answer = ([alert runModal] == NSOKButton ? Qtrue : Qfalse);
  RELEASE;
  return answer;
}

VALUE
shoes_dialog_color(VALUE self, VALUE title)
{
  Point where;
  RGBColor colwh = { 0xFFFF, 0xFFFF, 0xFFFF };
  RGBColor _color;
  VALUE color = Qnil;
  GLOBAL_APP(app);

  where.h = where.v = 0;
  title = shoes_native_to_s(title);
  if (GetColor(where, RSTRING_PTR(title), &colwh, &_color))
  {
    color = shoes_color_new(_color.red/256, _color.green/256, _color.blue/256, SHOES_COLOR_OPAQUE);
  }
  return color;
}

static VALUE
shoes_dialog_chooser(VALUE self, NSString *title, BOOL directories)
{
  NSOpenPanel* openDlg = [NSOpenPanel openPanel];
  [openDlg setCanChooseFiles: !directories];
  [openDlg setCanChooseDirectories: directories];
  [openDlg setAllowsMultipleSelection: NO];
  if ( [openDlg runModalForDirectory: nil file: nil] == NSOKButton )
  {
    NSArray* files = [openDlg filenames];
    char *filename = [[files objectAtIndex: 0] UTF8String];
    return rb_str_new2(filename);
  }
  return Qnil;
}

VALUE
shoes_dialog_open(VALUE self)
{
  return shoes_dialog_chooser(self, @"Open file...", NO);
}

VALUE
shoes_dialog_save(VALUE self)
{
  NSSavePanel* saveDlg = [NSSavePanel savePanel];
  if ( [saveDlg runModalForDirectory:nil file:nil] == NSOKButton )
  {
    char *filename = [[saveDlg filename] UTF8String];
    return rb_str_new2(filename);
  }
  return Qnil;
}

VALUE
shoes_dialog_open_folder(VALUE self)
{
  return shoes_dialog_chooser(self, @"Open folder...", YES);
}

VALUE
shoes_dialog_save_folder(VALUE self)
{
  return shoes_dialog_chooser(self, @"Save folder...", YES);
}
