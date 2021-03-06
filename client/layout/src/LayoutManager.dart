//Copyright (C) 2012 Potix Corporation. All Rights Reserved.
//History: Thu, Mar 15, 2012  9:56:30 AM
// Author: tomyeh

/**
 * The layout mananger that manages the layout controllers ([Layout]).
 * There is exactly one layout manager per application.
 */
class LayoutManager extends RunOnceViewManager {
  final Map<String, Layout> _layouts;
  final Set<String> _imgWaits;
  final List<Task> _afters;
  int _inLayout = 0;

  LayoutManager(): super(null), _layouts = {}, _imgWaits = new Set(), _afters = [] {
    addLayout("linear", new LinearLayout());
    FreeLayout freeLayout = new FreeLayout();
    addLayout("none", freeLayout);
    addLayout("", freeLayout);
  }

  /** Adds the layout for the given name.
   */
  Layout addLayout(String name, Layout clayout) {
    final Layout old = _layouts[name];
    _layouts[name] = clayout;
    return old;
  }
  /** Removes the layout of the given name if any.
   */
  Layout removeLayout(String name) {
    return _layouts.remove(name);
  }
  /** Returns the layout of the given name, or null if not found.
   */
  Layout getLayout(String name) {
    return _layouts[name];
  }
  /** Returns the layout of the given view (never null).
   */
  Layout getLayoutOfView(View view) {
    final String name = view.layout.type;
    final Layout clayout = getLayout(name);
    if (clayout == null)
      throw new UIException("Unknown layout, ${name}");
    return clayout;
  }

  /** Handles the layout of the given view.
   */
  void requestLayout(View view, bool immediate, bool descendantOnly) {
    if (!descendantOnly) {
      final View parent = view.parent;
      //Start the layout from parent only if necessary
      //Currently, we start from parent if with anchor, or in some layout,
      //or some dimension not set by app
      if (parent !== null
      && (view.profile.anchorView !== null || !parent.layout.type.isEmpty()
        || MeasureContext._getSetByApp(view, view.width, 'rk.layout.w') === null
        || MeasureContext._getSetByApp(view, view.height, 'rk.layout.h') === null))
        view = parent; //start from parent (slower performance but safer)
    }

    if (immediate) flush(view);
    else queue(view);
  }

  /** Called by [View], when it changed the width or height.
   */
  void sizeUpdated(View view, int value, bool horizontal) {
    //Note: we have to store the width in view since it is required if requestLayout
    //is called again (while _borderWds shall be dropped after layouted)
    final String nm = horizontal ? 'rk.layout.w': 'rk.layout.h'; //see also MeasureContext._getSetByApp
    if (_inLayout > 0)
      view.dataAttributes[nm] = value;
    else
      view.dataAttributes.remove(nm);
  }

  //@Override
  void flush([View view]) {
    //ignore flush if not empty (_onImageLoaded will invoke it later)
    if (_imgWaits.isEmpty())
      super.flush(view);
    else if (view !== null)
      queue(view); //do it later
  }

  //@Override RunOnceViewManager
  void handle_(View view) {
    ++_inLayout;
    try {
      doLayout(new MeasureContext(), view);
    } finally {
      if (--_inLayout <= 0 && isQueueEmpty() && !_afters.isEmpty()) {
        final List<Task> afters = new List.from(_afters);
        _afters.clear();
        for (final Task task in afters)
          task();
      }
    }
  }
  /** Schedules a task to be run after the layout is done.
   * If there is no pending layouts, it will be executed immediately.
   */
  void afterLayout(Task task) {
    if (_inLayout <= 0 && isQueueEmpty())
      task();
    else
      _afters.add(task);
  }

  /** Handles the layout of the given view.
   */
  void doLayout(MeasureContext mctx, View view) {
    if (!view.hidden) {
      if (view.parent === null && view.profile.anchorView === null) { //root without anchor
        //handle profile since it has no parent to handel for it
        mctx.setWidthByProfile(view, () => browser.size.width);
        mctx.setHeightByProfile(view, () => browser.size.height);
        AnchorRelation._positionRoot(view);
      }
      view.onPreLayout_();
      getLayoutOfView(view).doLayout(mctx, view);
      view.onLayout_();
    }
  }

  /** Wait until the given image is loaded.
   * If the width and height of the image is not known in advance, this method
   * shall be called to make the layout manager wait until the image is loaded.
   *
   * Currently, [Image] will invoke this method automatically
   * if the width or height of the image is not specified.
   */
  void waitImageLoaded(String imgURI) {
    if (!_imgWaits.contains(imgURI)) {
      _imgWaits.add(imgURI);
      final ImageElement img = new Element.tag("img");
      var func = (event) { //DOM event
        _onImageLoaded(imgURI);
      };
      img.on.load.add(func);
      img.on.error.add(func);
      img.src = imgURI;
    }
  }
  void _onImageLoaded(String imgURI) {
    _imgWaits.remove(imgURI);
    if (_imgWaits.isEmpty())
      flush(); //flush all
  }
}

/** The layout manager.
 */
LayoutManager layoutManager;
