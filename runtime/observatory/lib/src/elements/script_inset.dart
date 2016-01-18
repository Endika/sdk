// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library script_inset_element;

import 'dart:async';
import 'dart:html';
import 'dart:math';
import 'observatory_element.dart';
import 'nav_bar.dart';
import 'service_ref.dart';
import 'package:observatory/service.dart';
import 'package:observatory/utils.dart';
import 'package:polymer/polymer.dart';
import 'package:logging/logging.dart';

const nbsp = "\u00A0";

void addInfoBox(Element content, Function infoBoxGenerator) {
  var infoBox;
  var show = false;
  var originalBackground = content.style.backgroundColor;
  buildInfoBox() {
    infoBox = infoBoxGenerator();
    infoBox.style.position = 'absolute';
    infoBox.style.padding = '1em';
    infoBox.style.border = 'solid black 2px';
    infoBox.style.zIndex = '10';
    infoBox.style.backgroundColor = 'white';
    infoBox.style.cursor = 'auto';
    // Don't inherit pre formating from the script lines.
    infoBox.style.whiteSpace = 'normal';
    content.append(infoBox);
  }
  content.onClick.listen((event) {
    show = !show;
    if (infoBox == null) buildInfoBox();  // Created lazily on the first click.
    infoBox.style.display = show ? 'block' : 'none';
    content.style.backgroundColor = show ? 'white' : originalBackground;
  });

  // Causes infoBox to be positioned relative to the bottom-left of content.
  content.style.display = 'inline-block';
  content.style.cursor = 'pointer';
}


void addLink(Element content, String target) {
  // Ick, destructive but still compatible with also adding an info box.
  var a = new AnchorElement(href: target);
  a.text = content.text;
  content.text = '';
  content.append(a);
}


abstract class Annotation implements Comparable<Annotation> {
  int line;
  int columnStart;
  int columnStop;
  int get priority;

  void applyStyleTo(element);

  int compareTo(Annotation other) {
    if (line == other.line) {
      if (columnStart == other.columnStart) {
        return priority.compareTo(other.priority);
      }
      return columnStart.compareTo(other.columnStart);
    }
    return line.compareTo(other.line);
  }

  Element table() {
    var e = new DivElement();
    e.style.display = "table";
    e.style.color = "#333";
    e.style.font = "400 14px 'Montserrat', sans-serif";
    return e;
  }

  Element row([content]) {
    var e = new DivElement();
    e.style.display = "table-row";
    if (content is String) e.text = content;
    if (content is Element) e.children.add(content);
    return e;
  }

  Element cell(content) {
    var e = new DivElement();
    e.style.display = "table-cell";
    e.style.padding = "3px";
    if (content is String) e.text = content;
    if (content is Element) e.children.add(content);
    return e;
  }

  Element serviceRef(object) {
    AnyServiceRefElement e = new Element.tag("any-service-ref");
    e.ref = object;
    return e;
  }
}

class CurrentExecutionAnnotation extends Annotation {
  int priority = 0;  // highest priority.

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.classes.add("currentCol");
    element.title = "Current execution";
  }
}

class BreakpointAnnotation extends Annotation {
  Breakpoint bpt;
  int priority = 1;

  BreakpointAnnotation(this.bpt) {
    var script = bpt.location.script;
    var location = bpt.location;
    if (location.tokenPos != null) {
      var pos = location.tokenPos;
      line = script.tokenToLine(pos);
      columnStart = script.tokenToCol(pos) - 1;  // tokenToCol is 1-origin.
    } else if (location is UnresolvedSourceLocation) {
      line = location.line;
      columnStart = location.column;
      if (columnStart == null) {
        columnStart = 0;
      }
    }
    var length = script.guessTokenLength(line, columnStart);
    if (length == null) {
      length = 1;
    }
    columnStop = columnStart + length;
  }

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    var script = bpt.location.script;
    var pos = bpt.location.tokenPos;
    int line = script.tokenToLine(pos);
    int column = script.tokenToCol(pos);
    if (bpt.resolved) {
      element.classes.add("resolvedBreakAnnotation");
    } else {
      element.classes.add("unresolvedBreakAnnotation");
    }
    element.title = "Breakpoint ${bpt.number} at ${line}:${column}";
  }
}

class LibraryAnnotation extends Annotation {
  Library target;
  String url;
  int priority = 2;

  LibraryAnnotation(this.target, this.url);

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.title = "library ${target.uri}";
    addLink(element, url);
  }
}

class PartAnnotation extends Annotation {
  Script part;
  String url;
  int priority = 2;

  PartAnnotation(this.part, this.url);

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.title = "script ${part.uri}";
    addLink(element, url);
  }
}

class LocalVariableAnnotation extends Annotation {
  final value;
  int priority = 2;

  LocalVariableAnnotation(LocalVarLocation location, this.value) {
    line = location.line;
    columnStart = location.column;
    columnStop = location.endColumn;
  }

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.style.fontWeight = "bold";
    element.title = "${value.shortName}";
  }
}

class CallSiteAnnotation extends Annotation {
  CallSite callSite;
  int priority = 2;

  CallSiteAnnotation(this.callSite) {
    line = callSite.line;
    columnStart = callSite.column - 1;  // Call site is 1-origin.
    var tokenLength = callSite.script.guessTokenLength(line, columnStart);
    if (tokenLength == null) {
      tokenLength = callSite.name.length;  // Approximate.
      if (callSite.name.startsWith("get:") ||
          callSite.name.startsWith("set:")) tokenLength -= 4;
    }
    columnStop = columnStart + tokenLength;
  }

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.style.fontWeight = "bold";
    element.title = "Call site: ${callSite.name}";

    addInfoBox(element, () {
      var details = table();
      if (callSite.entries.isEmpty) {
        details.append(row('Call of "${callSite.name}" did not execute'));
      } else {
        var r = row();
        r.append(cell("Container"));
        r.append(cell("Count"));
        r.append(cell("Target"));
        details.append(r);

        for (var entry in callSite.entries) {
          var r = row();
          r.append(cell(serviceRef(entry.receiver)));
          r.append(cell(entry.count.toString()));
          r.append(cell(serviceRef(entry.target)));
          details.append(r);
        }
      }
      return details;
    });
  }
}

abstract class DeclarationAnnotation extends Annotation {
  String url;
  int priority = 2;

  DeclarationAnnotation(decl, this.url) {
    assert(decl.loaded);
    SourceLocation location = decl.location;
    if (location == null) {
      line = 0;
      columnStart = 0;
      columnStop = 0;
      return;
    }

    Script script = location.script;
    line = script.tokenToLine(location.tokenPos);
    columnStart = script.tokenToCol(location.tokenPos);
    if ((line == null) || (columnStart == null)) {
      line = 0;
      columnStart = 0;
      columnStop = 0;
    } else {
      columnStart--; // 1-origin -> 0-origin.

      // The method's token position is at the beginning of the method
      // declaration, which may be a return type annotation, metadata, static
      // modifier, etc. Try to scan forward to position this annotation on the
      // function's name instead.
      var lineSource = script.getLine(line).text;
      var betterStart = lineSource.indexOf(decl.name, columnStart);
      if (betterStart != -1) {
        columnStart = betterStart;
      }
      columnStop = columnStart + decl.name.length;
    }
  }
}

class ClassDeclarationAnnotation extends DeclarationAnnotation {
  Class klass;

  ClassDeclarationAnnotation(Class cls, String url)
    : klass = cls,
      super(cls, url);

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    element.title = "class ${klass.name}";
    addLink(element, url);
  }
}

class FieldDeclarationAnnotation extends DeclarationAnnotation {
  Field field;

  FieldDeclarationAnnotation(Field fld, String url)
    : field = fld,
      super(fld, url);

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    var tooltip = "field ${field.name}";
    element.title = tooltip;
    addLink(element, url);
  }
}

class FunctionDeclarationAnnotation extends DeclarationAnnotation {
  ServiceFunction function;

  FunctionDeclarationAnnotation(ServiceFunction func, String url)
    : function = func,
      super(func, url);

  void applyStyleTo(element) {
    if (element == null) {
      return;  // TODO(rmacnak): Handling overlapping annotations.
    }
    var tooltip = "method ${function.name}";
    if (function.isOptimizable == false) {
      tooltip += "\nUnoptimizable!";
    }
    if (function.isInlinable == false) {
      tooltip += "\nNot inlinable!";
    }
    if (function.deoptimizations > 0) {
      tooltip += "\nDeoptimized ${function.deoptimizations} times!";
    }
    element.title = tooltip;

    if (function.isOptimizable == false ||
        function.isInlinable == false ||
        function.deoptimizations >0) {
      element.style.backgroundColor = "#EEA7A7";  // Low-saturation red.
    }

    addLink(element, url);
  }
}

/// Box with script source code in it.
@CustomTag('script-inset')
class ScriptInsetElement extends ObservatoryElement {
  @published Script script;
  @published int startPos;
  @published int endPos;

  /// Set the height to make the script inset scroll.  Otherwise it
  /// will show from startPos to endPos.
  @published String height = null;

  @published int currentPos;
  @published bool inDebuggerContext = false;
  @published ObservableList variables;

  @published Element scroller;
  RefreshButtonElement _refreshButton;

  int _currentLine;
  int _currentCol;
  int _startLine;
  int _endLine;

  Map<int, List<ServiceMap>> _rangeMap = {};
  Set _callSites = new Set<CallSite>();
  Set _possibleBreakpointLines = new Set<int>();

  var annotations = [];
  var annotationsCursor;

  StreamSubscription _scriptChangeSubscription;
  Future<StreamSubscription> _debugSubscriptionFuture;
  StreamSubscription _scrollSubscription;

  bool hasLoadedLibraryDeclarations = false;

  String makeLineId(int line) {
    return 'line-$line';
  }

  void _scrollToCurrentPos() {
    var line = shadowRoot.getElementById(makeLineId(_currentLine));
    if (line != null) {
      line.scrollIntoView();
    }
  }

  void attached() {
    super.attached();
    _debugSubscriptionFuture =
        app.vm.listenEventStream(VM.kDebugStream, _onDebugEvent);
    if (scroller != null) {
      _scrollSubscription = scroller.onScroll.listen(_onScroll);
    } else {
      _scrollSubscription = window.onScroll.listen(_onScroll);
    }
  }

  void detached() {
    cancelFutureSubscription(_debugSubscriptionFuture);
    _debugSubscriptionFuture = null;
    if (_scrollSubscription != null) {
      _scrollSubscription.cancel();
      _scrollSubscription = null;
    }
    if (_scriptChangeSubscription != null) {
      // Don't leak. If only Dart and Javascript exposed weak references...
      _scriptChangeSubscription.cancel();
      _scriptChangeSubscription = null;
    }
    super.detached();
  }

  void _onScroll(event) {
    if (_refreshButton == null) {
      return;
    }
    var currentTop = _refreshButton.style.top;
    var newTop = _refreshButtonTop();
    if (currentTop != newTop) {
      _refreshButton.style.top = '${newTop}px';
    }
  }

  void _onDebugEvent(event) {
    if (script == null) {
      return;
    }
    switch (event.kind) {
      case ServiceEvent.kBreakpointAdded:
      case ServiceEvent.kBreakpointResolved:
      case ServiceEvent.kBreakpointRemoved:
        var loc = event.breakpoint.location;
        if (loc.script == script) {
          int line;
          if (loc.tokenPos != null) {
            line = script.tokenToLine(loc.tokenPos);
          } else {
            line = loc.line;
          }
          if ((line >= _startLine) && (line <= _endLine)) {
            _updateTask.queue();
          }
        }
        break;
      default:
        // Ignore.
        break;
    }
  }

  void currentPosChanged(oldValue) {
    _updateTask.queue();
    _scrollToCurrentPos();
  }

  void startPosChanged(oldValue) {
    _updateTask.queue();
  }

  void endPosChanged(oldValue) {
    _updateTask.queue();
  }

  void scriptChanged(oldValue) {
    _updateTask.queue();
  }

  void variablesChanged(oldValue) {
    _updateTask.queue();
  }

  Element a(String text) => new AnchorElement()..text = text;
  Element span(String text) => new SpanElement()..text = text;

  Element hitsCurrent(Element element) {
    element.classes.add('hitsCurrent');
    element.title = "";
    return element;
  }
  Element hitsUnknown(Element element) {
    element.classes.add('hitsNone');
    element.title = "";
    return element;
  }
  Element hitsNotExecuted(Element element) {
    element.classes.add('hitsNotExecuted');
    element.title = "Line did not execute";
    return element;
  }
  Element hitsExecuted(Element element) {
    element.classes.add('hitsExecuted');
    element.title = "Line did execute";
    return element;
  }
  Element hitsCompiled(Element element) {
    element.classes.add('hitsCompiled');
    element.title = "Line in compiled function";
    return element;
  }
  Element hitsNotCompiled(Element element) {
    element.classes.add('hitsNotCompiled');
    element.title = "Line in uncompiled function";
    return element;
  }

  Element container;

  Future _refresh() async {
    await update();
  }

  // Build _rangeMap and _callSites from a source report.
  Future _refreshSourceReport() async {
    var sourceReport = await script.isolate.getSourceReport(
        [Isolate.kCallSitesReport, Isolate.kPossibleBreakpointsReport],
        script, startPos, endPos);
    _possibleBreakpointLines = getPossibleBreakpointLines(sourceReport, script);
    _rangeMap.clear();
    _callSites.clear();
    for (var range in sourceReport['ranges']) {
      int startLine = script.tokenToLine(range['startPos']);
      int endLine = script.tokenToLine(range['endPos']);
      for (var line = startLine; line <= endLine; line++) {
        var rangeList = _rangeMap[line];
        if (rangeList == null) {
          _rangeMap[line] = [range];
        } else {
          rangeList.add(range);
        }
      }
      if (range['compiled']) {
        var rangeCallSites = range['callSites'];
        if (rangeCallSites != null) {
          for (var callSiteMap in rangeCallSites) {
            _callSites.add(new CallSite.fromMap(callSiteMap, script));
          }
        }
      }
    }
  }

  Task _updateTask;
  Future update() async {
    assert(_updateTask != null);
    if (script == null) {
      // We may have previously had a script.
      if (container != null) {
        container.children.clear();
      }
      return;
    }
    if (!script.loaded) {
      await script.load();
    }
    if (_scriptChangeSubscription == null) {
      _scriptChangeSubscription = script.changes.listen((_) => update());
    }
    await _refreshSourceReport();

    computeAnnotations();

    var table = linesTable();
    var firstBuild = false;
    if (container == null) {
      // Indirect to avoid deleting the style element.
      container = new DivElement();
      shadowRoot.append(container);
      firstBuild = true;
    }
    container.children.clear();
    container.children.add(table);
    makeCssClassUncopyable(table, "noCopy");
    if (firstBuild) {
      _scrollToCurrentPos();
    }
  }

  void computeAnnotations() {
    _startLine = (startPos != null
                  ? script.tokenToLine(startPos)
                  : 1 + script.lineOffset);
    _currentLine = (currentPos != null
                    ? script.tokenToLine(currentPos)
                    : null);
    _currentCol = (currentPos != null
                   ? (script.tokenToCol(currentPos))
                   : null);
    if (_currentCol != null) {
      _currentCol--;  // make this 0-based.
    }

    _endLine = (endPos != null
                ? script.tokenToLine(endPos)
                : script.lines.length + script.lineOffset);

    if (_startLine == null || _endLine == null) {
      return;
    }

    annotations.clear();

    addCurrentExecutionAnnotation();
    addBreakpointAnnotations();

    if (!inDebuggerContext && script.library != null) {
      if (hasLoadedLibraryDeclarations) {
        addLibraryAnnotations();
        addDependencyAnnotations();
        addPartAnnotations();
        addClassAnnotations();
        addFieldAnnotations();
        addFunctionAnnotations();
        addCallSiteAnnotations();
      } else {
        loadDeclarationsOfLibrary(script.library).then((_) {
          hasLoadedLibraryDeclarations = true;
          update();
        });
      }
    }

    addLocalVariableAnnotations();

    annotations.sort();
  }

  void addCurrentExecutionAnnotation() {
    if (_currentLine != null) {
      var a = new CurrentExecutionAnnotation();
      a.line = _currentLine;
      a.columnStart = _currentCol;
      var length = script.guessTokenLength(_currentLine, _currentCol);
      if (length == null) {
        length = 1;
      }
      a.columnStop = _currentCol + length;
      annotations.add(a);
    }
  }

  void addBreakpointAnnotations() {
    for (var line = _startLine; line <= _endLine; line++) {
      var bpts = script.getLine(line).breakpoints;
      if (bpts != null) {
        for (var bpt in bpts) {
          if (bpt.location != null) {
            annotations.add(new BreakpointAnnotation(bpt));
          }
        }
      }
    }
  }

  Future loadDeclarationsOfLibrary(Library lib) {
    return lib.load().then((lib) {
      var loads = [];
      for (var func in lib.functions) {
        loads.add(func.load());
      }
      for (var field in lib.variables) {
        loads.add(field.load());
      }
      for (var cls in lib.classes) {
        loads.add(loadDeclarationsOfClass(cls));
      }
      return Future.wait(loads);
    });
  }

  Future loadDeclarationsOfClass(Class cls) {
    return cls.load().then((cls) {
      var loads = [];
      for (var func in cls.functions) {
        loads.add(func.load());
      }
      for (var field in cls.fields) {
        loads.add(field.load());
      }
      return Future.wait(loads);
    });
  }

  String inspectLink(ServiceObject ref) {
    return gotoLink('/inspect', ref);
  }

  void addLibraryAnnotations() {
    for (ScriptLine line in script.lines) {
      // TODO(rmacnak): Use a real scanner.
      var pattern = new RegExp("library ${script.library.name}");
      var match = pattern.firstMatch(line.text);
      if (match != null) {
        var anno = new LibraryAnnotation(script.library,
                                         inspectLink(script.library));
        anno.line = line.line;
        anno.columnStart = match.start + 8;
        anno.columnStop = match.end;
        annotations.add(anno);
      }
      // TODO(rmacnak): Use a real scanner.
      pattern = new RegExp("part of ${script.library.name}");
      match = pattern.firstMatch(line.text);
      if (match != null) {
        var anno = new LibraryAnnotation(script.library,
                                         inspectLink(script.library));
        anno.line = line.line;
        anno.columnStart = match.start + 8;
        anno.columnStop = match.end;
        annotations.add(anno);
      }
    }
  }

  Library resolveDependency(String relativeUri) {
    // This isn't really correct: we need to ask the embedder to do the
    // uri canonicalization for us, but Observatory isn't in a position
    // to invoke the library tag handler. Handle the most common cases.
    var targetUri = Uri.parse(script.library.uri).resolve(relativeUri);
    for (Library l in script.isolate.libraries) {
      if (targetUri.toString() == l.uri) {
        return l;
      }
    }
    if (targetUri.scheme == 'package') {
      targetUri = "packages/${targetUri.path}";
      for (Library l in script.isolate.libraries) {
        if (targetUri.toString() == l.uri) {
          return l;
        }
      }
    }

    Logger.root.info("Could not resolve library dependency: $relativeUri");
    return null;
  }

  void addDependencyAnnotations() {
    // TODO(rmacnak): Use a real scanner.
    var patterns = [
      new RegExp("import '(.*)'"),
      new RegExp('import "(.*)"'),
      new RegExp("export '(.*)'"),
      new RegExp('export "(.*)"'),
    ];
    for (ScriptLine line in script.lines) {
      for (var pattern in patterns) {
        var match = pattern.firstMatch(line.text);
        if (match != null) {
          Library target = resolveDependency(match[1]);
          if (target != null) {
            var anno = new LibraryAnnotation(target, inspectLink(target));
            anno.line = line.line;
            anno.columnStart = match.start + 8;
            anno.columnStop = match.end - 1;
            annotations.add(anno);
          }
        }
      }
    }
  }

  Script resolvePart(String relativeUri) {
    var rootUri = Uri.parse(script.library.uri);
    if (rootUri.scheme == 'dart') {
      // The relative paths from dart:* libraries to their parts are not valid.
      rootUri = new Uri.directory(script.library.uri);
    }
    var targetUri = rootUri.resolve(relativeUri);
    for (Script s in script.library.scripts) {
      if (targetUri.toString() == s.uri) {
        return s;
      }
    }
    Logger.root.info("Could not resolve part: $relativeUri");
    return null;
  }

  void addPartAnnotations() {
    // TODO(rmacnak): Use a real scanner.
    var patterns = [
      new RegExp("part '(.*)'"),
      new RegExp('part "(.*)"'),
    ];
    for (ScriptLine line in script.lines) {
      for (var pattern in patterns) {
        var match = pattern.firstMatch(line.text);
        if (match != null) {
          Script part = resolvePart(match[1]);
          if (part != null) {
            var anno = new PartAnnotation(part, inspectLink(part));
            anno.line = line.line;
            anno.columnStart = match.start + 6;
            anno.columnStop = match.end - 1;
            annotations.add(anno);
          }
        }
      }
    }
  }

  void addClassAnnotations() {
    for (var cls in script.library.classes) {
      if ((cls.location != null) && (cls.location.script == script)) {
        var a = new ClassDeclarationAnnotation(cls, inspectLink(cls));
        annotations.add(a);
      }
    }
  }

  void addFieldAnnotations() {
    for (var field in script.library.variables) {
      if ((field.location != null) && (field.location.script == script)) {
        var a = new FieldDeclarationAnnotation(field, inspectLink(field));
        annotations.add(a);
      }
    }
    for (var cls in script.library.classes) {
      for (var field in cls.fields) {
        if ((field.location != null) && (field.location.script == script)) {
          var a = new FieldDeclarationAnnotation(field, inspectLink(field));
          annotations.add(a);
        }
      }
    }
  }

  void addFunctionAnnotations() {
    for (var func in script.library.functions) {
      if ((func.location != null) &&
          (func.location.script == script) &&
          (func.kind != FunctionKind.kImplicitGetterFunction) &&
          (func.kind != FunctionKind.kImplicitSetterFunction)) {
        // We annotate a field declaration with the field instead of the
        // implicit getter or setter.
        var a = new FunctionDeclarationAnnotation(func, inspectLink(func));
        annotations.add(a);
      }
    }
    for (var cls in script.library.classes) {
      for (var func in cls.functions) {
        if ((func.location != null) &&
            (func.location.script == script) &&
            (func.kind != FunctionKind.kImplicitGetterFunction) &&
            (func.kind != FunctionKind.kImplicitSetterFunction)) {
          // We annotate a field declaration with the field instead of the
          // implicit getter or setter.
          var a = new FunctionDeclarationAnnotation(func, inspectLink(func));
          annotations.add(a);
        }
      }
    }
  }

  void addCallSiteAnnotations() {
    for (var callSite in _callSites) {
      annotations.add(new CallSiteAnnotation(callSite));
    }
  }

  void addLocalVariableAnnotations() {
    // We have local variable information.
    if (variables != null) {
      // For each variable.
      for (var variable in variables) {
        // Find variable usage locations.
        var locations = script.scanForLocalVariableLocations(
              variable['name'],
              variable['_tokenPos'],
              variable['_endTokenPos']);

        // Annotate locations.
        for (var location in locations) {
          annotations.add(new LocalVariableAnnotation(location,
                                                      variable['value']));
        }
      }
    }
  }

  int _refreshButtonTop() {
    if (_refreshButton == null) {
      return 5;
    }
    const padding = 5;
    const navbarHeight = NavBarElement.height;
    var rect = getBoundingClientRect();
    var buttonHeight = _refreshButton.clientHeight;
    return min(max(0, navbarHeight - rect.top) + padding,
               rect.height - (buttonHeight + padding));
  }

  RefreshButtonElement _newRefreshButton() {
    var button = new Element.tag('refresh-button');
    button.style.position = 'absolute';
    button.style.display = 'inline-block';
    button.style.top = '${_refreshButtonTop()}px';
    button.style.right = '5px';
    button.callback = _refresh;
    return button;
  }

  Element linesTable() {
    var table = new DivElement();
    table.classes.add("sourceTable");

    _refreshButton = _newRefreshButton();
    table.append(_refreshButton);

    if (_startLine == null || _endLine == null) {
      return table;
    }

    var endLine = (endPos != null
                   ? script.tokenToLine(endPos)
                   : script.lines.length + script.lineOffset);
    var lineNumPad = endLine.toString().length;

    annotationsCursor = 0;

    int blankLineCount = 0;
    for (int i = _startLine; i <= _endLine; i++) {
      var line = script.getLine(i);
      if (line.isBlank) {
        // Try to introduce elipses if there are 4 or more contiguous
        // blank lines.
        blankLineCount++;
      } else {
        if (blankLineCount > 0) {
          int firstBlank = i - blankLineCount;
          int lastBlank = i - 1;
          if (blankLineCount < 4) {
            // Too few blank lines for an elipsis.
            for (int j = firstBlank; j  <= lastBlank; j++) {
              table.append(lineElement(script.getLine(j), lineNumPad));
            }
          } else {
            // Add an elipsis for the skipped region.
            table.append(lineElement(script.getLine(firstBlank), lineNumPad));
            table.append(lineElement(null, lineNumPad));
            table.append(lineElement(script.getLine(lastBlank), lineNumPad));
          }
          blankLineCount = 0;
        }
        table.append(lineElement(line, lineNumPad));
      }
    }

    return table;
  }

  // Assumes annotations are sorted.
  Annotation nextAnnotationOnLine(int line) {
    if (annotationsCursor >= annotations.length) return null;
    var annotation = annotations[annotationsCursor];

    // Fast-forward past any annotations before the first line that
    // we are displaying.
    while (annotation.line < line) {
      annotationsCursor++;
      if (annotationsCursor >= annotations.length) return null;
      annotation = annotations[annotationsCursor];
    }

    // Next annotation is for a later line, don't advance past it.
    if (annotation.line != line) return null;
    annotationsCursor++;
    return annotation;
  }

  Element lineElement(ScriptLine line, int lineNumPad) {
    var e = new DivElement();
    e.classes.add("sourceRow");
    e.append(lineBreakpointElement(line));
    e.append(lineNumberElement(line, lineNumPad));
    e.append(lineSourceElement(line));
    return e;
  }

  Element lineBreakpointElement(ScriptLine line) {
    var e = new DivElement();
    if (line == null || !_possibleBreakpointLines.contains(line.line)) {
      e.classes.add('noCopy');
      e.classes.add("emptyBreakpoint");
      e.text = nbsp;
      return e;
    }

    e.text = 'B';
    var busy = false;
    void update() {
      e.classes.clear();
      e.classes.add('noCopy');
      if (busy) {
        e.classes.add("busyBreakpoint");
      } else if (line.breakpoints != null) {
        bool resolved = false;
        for (var bpt in line.breakpoints) {
          if (bpt.resolved) {
            resolved = true;
            break;
          }
        }
        if (resolved) {
          e.classes.add("resolvedBreakpoint");
        } else {
          e.classes.add("unresolvedBreakpoint");
        }
      } else {
        e.classes.add("possibleBreakpoint");
      }
    }

    line.changes.listen((_) => update());
    e.onClick.listen((event) {
      if (busy) {
        return;
      }
      busy = true;
      if (line.breakpoints == null) {
        // No breakpoint.  Add it.
        line.script.isolate.addBreakpoint(line.script, line.line)
          .catchError((e, st) {
            if (e is! ServerRpcException ||
                (e as ServerRpcException).code !=
                ServerRpcException.kCannotAddBreakpoint) {
              app.handleException(e, st);
            }})
          .whenComplete(() {
            busy = false;
            update();
          });
      } else {
        // Existing breakpoint.  Remove it.
        List pending = [];
        for (var bpt in line.breakpoints) {
          pending.add(line.script.isolate.removeBreakpoint(bpt));
        }
        Future.wait(pending).then((_) {
          busy = false;
          update();
        });
      }
      update();
    });
    update();
    return e;
  }

  Element lineNumberElement(ScriptLine line, int lineNumPad) {
    var lineNumber = line == null ? "..." : line.line;
    var e = span("$nbsp${lineNumber.toString().padLeft(lineNumPad,nbsp)}$nbsp");
    e.classes.add('noCopy');
    if (lineNumber == _currentLine) {
      hitsCurrent(e);
      return e;
    }
    var ranges = _rangeMap[lineNumber];
    if ((ranges == null) || ranges.isEmpty) {
      // This line is not code.
      hitsUnknown(e);
      return e;
    }
    bool compiled = true;
    bool hasCallInfo = false;
    bool executed = false;
    for (var range in ranges) {
      if (range['compiled']) {
        for (var callSite in range['callSites']) {
          var callLine = line.script.tokenToLine(callSite['tokenPos']);
          if (lineNumber == callLine) {
            // The call site is on the current line.
            hasCallInfo = true;
            for (var cacheEntry in callSite['cacheEntries']) {
              if (cacheEntry['count'] > 0) {
                // If any call site on the line has been executed, we
                // mark the line as executed.
                executed = true;
                break;
              }
            }
          }
        }
      } else {
        // If any range isn't compiled, show the line as not compiled.
        // This is necessary so that nested functions appear to be uncompiled.
        compiled = false;
      }
    }
    if (executed) {
      hitsExecuted(e);
    } else if (hasCallInfo) {
      hitsNotExecuted(e);
    } else if (compiled) {
      hitsCompiled(e);
    } else {
      hitsNotCompiled(e);
    }
    return e;
  }

  Element lineSourceElement(ScriptLine line) {
    var e = new DivElement();
    e.classes.add("sourceItem");

    if (line != null) {
      if (line.line == _currentLine) {
        e.classes.add("currentLine");
      }

      e.id = makeLineId(line.line);

      var position = 0;
      consumeUntil(var stop) {
        if (stop <= position) {
          return null;  // Empty gap between annotations/boundries.
        }
        if (stop > line.text.length) {
          // Approximated token length can run past the end of the line.
          stop = line.text.length;
        }

        var chunk = line.text.substring(position, stop);
        var chunkNode = span(chunk);
        e.append(chunkNode);
        position = stop;
        return chunkNode;
      }

      // TODO(rmacnak): Tolerate overlapping annotations.
      var annotation;
      while ((annotation = nextAnnotationOnLine(line.line)) != null) {
        consumeUntil(annotation.columnStart);
        annotation.applyStyleTo(consumeUntil(annotation.columnStop));
      }
      consumeUntil(line.text.length);
    }

    // So blank lines are included when copying script to the clipboard.
    e.append(span('\n'));

    return e;
  }

  ScriptInsetElement.created()
      : super.created() {
    _updateTask = new Task(update);
  }
}

@CustomTag('refresh-button')
class RefreshButtonElement extends PolymerElement {
  RefreshButtonElement.created() : super.created();

  @published var callback = null;
  bool busy = false;

  Future buttonClick(var event, var b, var c) async {
    if (busy) {
      return;
    }
    busy = true;
    if (callback != null) {
      await callback();
    }
    busy = false;
  }
}


@CustomTag('source-inset')
class SourceInsetElement extends PolymerElement {
  SourceInsetElement.created() : super.created();

  @published SourceLocation location;
  @published String height = null;
  @published int currentPos;
  @published bool inDebuggerContext = false;
  @published ObservableList variables;
  @published Element scroller;
}
