// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart2js.world.class_set;

import 'dart:collection' show
    IterableBase;
import '../elements/elements.dart' show
    ClassElement;
import '../util/enumset.dart' show
    EnumSet;
import '../util/util.dart' show
    Link;

/// Enum for the different kinds of instantiation of a class.
enum Instantiation {
  UNINSTANTIATED,
  DIRECTLY_INSTANTIATED,
  INDIRECTLY_INSTANTIATED,
}

/// Node for [cls] in a tree forming the subclass relation of [ClassElement]s.
///
/// This is used by the [ClassWorld] to perform queries on subclass and subtype
/// relations.
///
/// For this class hierarchy:
///
///     class A {}
///     class B extends A {}
///     class C extends A {}
///     class D extends B {}
///     class E extends D {}
///
/// the [ClassHierarchyNode]s form this subclass tree:
///
///       Object
///         |
///         A
///        / \
///       B   C
///       |
///       D
///       |
///       E
///
class ClassHierarchyNode {
  /// Enum set for selecting instantiated classes in
  /// [ClassHierarchyNode.subclassesByMask],
  /// [ClassHierarchyNode.subclassesByMask] and [ClassSet.subtypesByMask].
  static final EnumSet<Instantiation> INSTANTIATED =
      new EnumSet<Instantiation>.fromValues(
          const <Instantiation>[
              Instantiation.DIRECTLY_INSTANTIATED,
              Instantiation.INDIRECTLY_INSTANTIATED],
          fixed: true);

  /// Enum set for selecting directly instantiated classes in
  /// [ClassHierarchyNode.subclassesByMask],
  /// [ClassHierarchyNode.subclassesByMask] and [ClassSet.subtypesByMask].
  static final EnumSet<Instantiation> DIRECTLY_INSTANTIATED =
      new EnumSet<Instantiation>.fromValues(
          const <Instantiation>[Instantiation.DIRECTLY_INSTANTIATED],
          fixed: true);

  /// Enum set for selecting all classes in
  /// [ClassHierarchyNode.subclassesByMask],
  /// [ClassHierarchyNode.subclassesByMask] and [ClassSet.subtypesByMask].
  static final EnumSet<Instantiation> ALL =
      new EnumSet<Instantiation>.fromValues(
          Instantiation.values,
          fixed: true);

  /// Creates an enum set for selecting the returned classes in
  /// [ClassHierarchyNode.subclassesByMask],
  /// [ClassHierarchyNode.subclassesByMask] and [ClassSet.subtypesByMask].
  static EnumSet<Instantiation> createMask(
      {bool includeDirectlyInstantiated: true,
       bool includeIndirectlyInstantiated: true,
       bool includeUninstantiated: true}) {
    EnumSet<Instantiation> mask = new EnumSet<Instantiation>();
    if (includeDirectlyInstantiated) {
      mask.add(Instantiation.DIRECTLY_INSTANTIATED);
    }
    if (includeIndirectlyInstantiated) {
      mask.add(Instantiation.INDIRECTLY_INSTANTIATED);
    }
    if (includeUninstantiated) {
      mask.add(Instantiation.UNINSTANTIATED);
    }
    return mask;
  }

  final ClassElement cls;
  final EnumSet<Instantiation> _mask =
      new EnumSet<Instantiation>.fromValues(
          const <Instantiation>[Instantiation.UNINSTANTIATED]);

  ClassElement _leastUpperInstantiatedSubclass;

  /// `true` if [cls] has been directly instantiated.
  ///
  /// For instance `C` but _not_ `B` in:
  ///   class B {}
  ///   class C extends B {}
  ///   main() => new C();
  ///
  bool get isDirectlyInstantiated =>
      _mask.contains(Instantiation.DIRECTLY_INSTANTIATED);

  void set isDirectlyInstantiated(bool value) {
    if (value != isDirectlyInstantiated) {
      if (value) {
        _mask.remove(Instantiation.UNINSTANTIATED);
        _mask.add(Instantiation.DIRECTLY_INSTANTIATED);
      } else {
        _mask.remove(Instantiation.DIRECTLY_INSTANTIATED);
        if (_mask.isEmpty) {
          _mask.add(Instantiation.UNINSTANTIATED);
        }
      }
    }
  }

  /// `true` if [cls] has been instantiated through subclasses.
  ///
  /// For instance `A` and `B` but _not_ `C` in:
  ///   class A {}
  ///   class B extends A {}
  ///   class C extends B {}
  ///   main() => [new B(), new C()];
  ///
  bool get isIndirectlyInstantiated =>
      _mask.contains(Instantiation.INDIRECTLY_INSTANTIATED);

  void set isIndirectlyInstantiated(bool value) {
    if (value != isIndirectlyInstantiated) {
      if (value) {
        _mask.remove(Instantiation.UNINSTANTIATED);
        _mask.add(Instantiation.INDIRECTLY_INSTANTIATED);
      } else {
        _mask.remove(Instantiation.INDIRECTLY_INSTANTIATED);
        if (_mask.isEmpty) {
          _mask.add(Instantiation.UNINSTANTIATED);
        }
      }
    }
  }

  /// The nodes for the direct subclasses of [cls].
  Link<ClassHierarchyNode> _directSubclasses = const Link<ClassHierarchyNode>();

  ClassHierarchyNode(this.cls);

  /// Adds [subclass] as a direct subclass of [cls].
  void addDirectSubclass(ClassHierarchyNode subclass) {
    assert(subclass.cls.superclass == cls);
    assert(!_directSubclasses.contains(subclass));
    _directSubclasses = _directSubclasses.prepend(subclass);
  }

  /// Returns `true` if [other] is contained in the subtree of this node.
  ///
  /// This means that [other] is a subclass of [cls].
  bool contains(ClassElement other) {
    while (other != null) {
      if (cls == other) return true;
      if (cls.hierarchyDepth >= other.hierarchyDepth) return false;
      other = other.superclass;
    }
    return false;
  }

  /// `true` if [cls] has been directly or indirectly instantiated.
  bool get isInstantiated => isDirectlyInstantiated || isIndirectlyInstantiated;

  /// Returns an [Iterable] of the subclasses of [cls] possibly including [cls].
  ///
  /// The directly instantiated, indirectly instantiated and uninstantiated
  /// subclasses of [cls] are returned if [includeDirectlyInstantiated],
  /// [includeIndirectlyInstantiated], and [includeUninstantiated] are `true`,
  /// respectively. If [strict] is `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subclasses(
      {bool includeDirectlyInstantiated: true,
       bool includeIndirectlyInstantiated: true,
       bool includeUninstantiated: true,
       bool strict: false}) {
    EnumSet<Instantiation> mask = createMask(
        includeDirectlyInstantiated: includeDirectlyInstantiated,
        includeIndirectlyInstantiated:includeIndirectlyInstantiated,
        includeUninstantiated: includeUninstantiated);
    return subclassesByMask(mask, strict: strict);
  }

  /// Returns an [Iterable] of the subclasses of [cls] possibly including [cls].
  ///
  /// Subclasses are included if their instantiation properties intersect with
  /// their corresponding [Instantiation] values in [mask]. If [strict] is
  /// `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subclassesByMask(
      EnumSet<Instantiation> mask,
      {bool strict: false}) {
    return new ClassHierarchyNodeIterable(
        this, mask, includeRoot: !strict);
  }

  /// Returns the most specific subclass of [cls] (including [cls]) that is
  /// directly instantiated or a superclass of all directly instantiated
  /// subclasses. If [cls] is not instantiated, `null` is returned.
  ClassElement getLubOfInstantiatedSubclasses() {
    if (!isInstantiated) return null;
    if (_leastUpperInstantiatedSubclass == null) {
      _leastUpperInstantiatedSubclass =
          _computeLeastUpperInstantiatedSubclass();
    }
    return _leastUpperInstantiatedSubclass;
  }

  ClassElement _computeLeastUpperInstantiatedSubclass() {
    if (isDirectlyInstantiated) {
      return cls;
    }
    ClassHierarchyNode subclass;
    for (Link<ClassHierarchyNode> link = _directSubclasses;
         !link.isEmpty;
         link = link.tail) {
      if (link.head.isInstantiated) {
        if (subclass == null) {
          subclass = link.head;
        } else {
          return cls;
        }
      }
    }
    if (subclass != null) {
      return subclass.getLubOfInstantiatedSubclasses();
    }
    return cls;
  }

  void printOn(StringBuffer sb, String indentation,
               {bool instantiatedOnly: false,
                bool sorted: true,
                ClassElement withRespectTo}) {

    bool isRelatedTo(ClassElement subclass) {
      return subclass == withRespectTo ||
          subclass.implementsInterface(withRespectTo);
    }

    sb.write(indentation);
    if (cls.isAbstract) {
      sb.write('abstract ');
    }
    sb.write('class ${cls.name}:');
    if (isDirectlyInstantiated) {
      sb.write(' directly');
    }
    if (isIndirectlyInstantiated) {
      sb.write(' indirectly');
    }
    sb.write(' [');
    if (_directSubclasses.isEmpty) {
      sb.write(']');
    } else {
      var subclasses = _directSubclasses;
      if (sorted) {
        subclasses = _directSubclasses.toList()..sort((a, b) {
          return a.cls.name.compareTo(b.cls.name);
        });
      }
      bool needsComma = false;
      for (ClassHierarchyNode child in subclasses) {
        if (instantiatedOnly && !child.isInstantiated) {
          continue;
        }
        if (withRespectTo != null && !child.subclasses().any(isRelatedTo)) {
          continue;
        }
        if (needsComma) {
          sb.write(',\n');
        } else {
          sb.write('\n');
        }
        child.printOn(
            sb,
            '$indentation  ',
            instantiatedOnly: instantiatedOnly,
            sorted: sorted,
            withRespectTo: withRespectTo);
        needsComma = true;
      }
      if (needsComma) {
        sb.write('\n');
        sb.write('$indentation]');
      } else {
        sb.write(']');
      }
    }
  }

  String dump({String indentation: '',
               bool instantiatedOnly: false,
               ClassElement withRespectTo}) {
    StringBuffer sb = new StringBuffer();
    printOn(sb, indentation,
        instantiatedOnly: instantiatedOnly,
        withRespectTo: withRespectTo);
    return sb.toString();
  }

  String toString() => cls.toString();
}

/// Object holding the subclass and subtype relation for a single
/// [ClassElement].
///
/// The subclass relation for a class `C` is modelled through a reference to
/// the [ClassHierarchyNode] for `C` in the global [ClassHierarchyNode] tree
/// computed in [World].
///
/// The subtype relation for a class `C` is modelled through a collection of
/// disjoint [ClassHierarchyNode] subtrees. The subclasses of `C`, modelled
/// through the aforementioned [ClassHierarchyNode] pointer, are extended with
/// the subtypes that do not extend `C` through a list of additional
/// [ClassHierarchyNode] nodes. This list is normalized to contain only the
/// nodes for the topmost subtypes and is furthermore ordered in increasing
/// hierarchy depth order.
///
/// For this class hierarchy:
///
///     class A {}
///     class B extends A {}
///     class C implements B {}
///     class D implements A {}
///     class E extends D {}
///     class F implements D {}
///
/// the [ClassHierarchyNode] tree is
///
///       Object
///      / |  | \
///     A  C  D  F
///     |     |
///     B     E
///
/// and the [ClassSet] for `A` holds these [ClassHierarchyNode] nodes:
///
///      A  ->  [C, D, F]
///
/// The subtypes `B` and `E` are not directly modeled because they are implied
/// by their subclass relation to `A` and `D`, repectively. This can be seen
/// if we expand the subclass subtrees:
///
///      A  ->  [C, D, F]
///      |          |
///      B          E
///
class ClassSet {
  final ClassHierarchyNode node;
  ClassElement _leastUpperInstantiatedSubtype;

  List<ClassHierarchyNode> _directSubtypes;

  ClassSet(this.node);

  ClassElement get cls => node.cls;

  /// Returns an [Iterable] of the subclasses of [cls] possibly including [cls].
  ///
  /// The directly instantiated, indirectly instantiated and uninstantiated
  /// subclasses of [cls] are returned if [includeDirectlyInstantiated],
  /// [includeIndirectlyInstantiated], and [includeUninstantiated] are `true`,
  /// respectively. If [strict] is `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subclasses(
      {bool includeDirectlyInstantiated: true,
       bool includeIndirectlyInstantiated: true,
       bool includeUninstantiated: true,
       bool strict: false}) {
    EnumSet<Instantiation> mask = ClassHierarchyNode.createMask(
        includeDirectlyInstantiated: includeDirectlyInstantiated,
        includeIndirectlyInstantiated:includeIndirectlyInstantiated,
        includeUninstantiated: includeUninstantiated);
    return subclassesByMask(mask, strict: strict);
  }

  /// Returns an [Iterable] of the subclasses of [cls] possibly including [cls].
  ///
  /// Subclasses are included if their instantiation properties intersect with
  /// their corresponding [Instantiation] values in [mask]. If [strict] is
  /// `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subclassesByMask(
      EnumSet<Instantiation> mask,
      {bool strict: false}) {
    return node.subclassesByMask(mask, strict: strict);
  }

  /// Returns an [Iterable] of the subtypes of [cls] possibly including [cls].
  ///
  /// The directly instantiated, indirectly instantiated and uninstantiated
  /// subtypes of [cls] are returned if [includeDirectlyInstantiated],
  /// [includeIndirectlyInstantiated], and [includeUninstantiated] are `true`,
  /// respectively. If [strict] is `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subtypes(
      {bool includeDirectlyInstantiated: true,
       bool includeIndirectlyInstantiated: true,
       bool includeUninstantiated: true,
       bool strict: false}) {
    EnumSet<Instantiation> mask = ClassHierarchyNode.createMask(
        includeDirectlyInstantiated: includeDirectlyInstantiated,
        includeIndirectlyInstantiated:includeIndirectlyInstantiated,
        includeUninstantiated: includeUninstantiated);
    return subtypesByMask(mask, strict: strict);
  }


  /// Returns an [Iterable] of the subtypes of [cls] possibly including [cls].
  ///
  /// Subtypes are included if their instantiation properties intersect with
  /// their corresponding [Instantiation] values in [mask]. If [strict] is
  /// `true`, [cls] itself is _not_ returned.
  Iterable<ClassElement> subtypesByMask(
      EnumSet<Instantiation> mask,
      {bool strict: false}) {
    if (_directSubtypes == null) {
      return node.subclassesByMask(
          mask,
          strict: strict);
    }

    return new SubtypesIterable.SubtypesIterator(this,
        mask,
        includeRoot: !strict);
  }

  /// Adds [subtype] as a subtype of [cls].
  void addSubtype(ClassHierarchyNode subtype) {
    if (node.contains(subtype.cls)) {
      return;
    }
    if (_directSubtypes == null) {
      _directSubtypes = <ClassHierarchyNode>[subtype];
    } else {
      int hierarchyDepth = subtype.cls.hierarchyDepth;
      List<ClassHierarchyNode> newSubtypes = <ClassHierarchyNode>[];
      bool added = false;
      for (ClassHierarchyNode otherSubtype in _directSubtypes) {
        int otherHierarchyDepth = otherSubtype.cls.hierarchyDepth;
        if (hierarchyDepth == otherHierarchyDepth) {
          if (subtype == otherSubtype) {
            return;
          } else {
            // [otherSubtype] is unrelated to [subtype].
            newSubtypes.add(otherSubtype);
          }
        } else if (hierarchyDepth > otherSubtype.cls.hierarchyDepth) {
          // [otherSubtype] could be a superclass of [subtype].
          if (otherSubtype.contains(subtype.cls)) {
            // [subtype] is already in this set.
            return;
          } else {
            // [otherSubtype] is unrelated to [subtype].
            newSubtypes.add(otherSubtype);
          }
        } else {
          if (!added) {
            // Insert [subtype] before other subtypes of higher hierarchy depth.
            newSubtypes.add(subtype);
            added = true;
          }
          // [subtype] could be a superclass of [otherSubtype].
          if (subtype.contains(otherSubtype.cls)) {
            // Replace [otherSubtype].
          } else {
            newSubtypes.add(otherSubtype);
          }
        }
      }
      if (!added) {
        newSubtypes.add(subtype);
      }
      _directSubtypes = newSubtypes;
    }
  }

  /// Returns the most specific subtype of [cls] (including [cls]) that is
  /// directly instantiated or a superclass of all directly instantiated
  /// subtypes. If no subtypes of [cls] are instantiated, `null` is returned.
  ClassElement getLubOfInstantiatedSubtypes() {
    if (_leastUpperInstantiatedSubtype == null) {
      _leastUpperInstantiatedSubtype = _computeLeastUpperInstantiatedSubtype();
    }
    return _leastUpperInstantiatedSubtype;
  }

  ClassElement _computeLeastUpperInstantiatedSubtype() {
    if (node.isDirectlyInstantiated) {
      return cls;
    }
    if (_directSubtypes == null) {
      return node.getLubOfInstantiatedSubclasses();
    }
    ClassHierarchyNode subtype;
    if (node.isInstantiated) {
      subtype = node;
    }
    for (ClassHierarchyNode subnode in _directSubtypes) {
      if (subnode.isInstantiated) {
        if (subtype == null) {
          subtype = subnode;
        } else {
          return cls;
        }
      }
    }
    if (subtype != null) {
      return subtype.getLubOfInstantiatedSubclasses();
    }
    return null;
  }

  String toString() {
    StringBuffer sb = new StringBuffer();
    sb.write('[\n');
    node.printOn(sb, '  ');
    sb.write('\n');
    if (_directSubtypes != null) {
      for (ClassHierarchyNode node in _directSubtypes) {
        node.printOn(sb, '  ');
        sb.write('\n');
      }
    }
    sb.write(']');
    return sb.toString();
  }
}

/// Iterable for subclasses of a [ClassHierarchyNode].
class ClassHierarchyNodeIterable extends IterableBase<ClassElement> {
  final ClassHierarchyNode root;
  final EnumSet<Instantiation> mask;
  final bool includeRoot;

  ClassHierarchyNodeIterable(
      this.root,
      this.mask,
      {this.includeRoot: true}) {
    if (root == null) throw new StateError("No root for iterable.");
  }

  @override
  Iterator<ClassElement> get iterator {
    return new ClassHierarchyNodeIterator(this);
  }
}

/// Iterator for subclasses of a [ClassHierarchyNode].
///
/// Classes are returned in pre-order DFS fashion.
class ClassHierarchyNodeIterator implements Iterator<ClassElement> {
  final ClassHierarchyNodeIterable iterable;

  /// The class node holding the [current] class.
  ///
  /// This is `null` before the first call to [moveNext] and at the end of
  /// iteration, i.e. after [moveNext] has returned `false`.
  ClassHierarchyNode currentNode;

  /// Stack of pending class nodes.
  ///
  /// This is `null` before the first call to [moveNext].
  Link<ClassHierarchyNode> stack;

  ClassHierarchyNodeIterator(this.iterable);

  ClassHierarchyNode get root => iterable.root;

  bool get includeRoot => iterable.includeRoot;

  EnumSet<Instantiation> get mask => iterable.mask;

  bool get includeUninstantiated {
    return mask.contains(Instantiation.UNINSTANTIATED);
  }

  @override
  ClassElement get current {
    return currentNode != null ? currentNode.cls : null;
  }

  @override
  bool moveNext() {
    if (stack == null) {
      // First call to moveNext
      stack = const Link<ClassHierarchyNode>().prepend(root);
      return _findNext();
    } else {
      // Initialized state.
      if (currentNode == null) return false;
      return _findNext();
    }
  }

  /// Find the next class using the [stack].
  bool _findNext() {
    while (true) {
      if (stack.isEmpty) {
        // No more classes. Set [currentNode] to `null` to signal the end of
        // iteration.
        currentNode = null;
        return false;
      }
      currentNode = stack.head;
      stack = stack.tail;
      if (!includeUninstantiated && !currentNode.isInstantiated) {
        // We're only iterating instantiated classes so there is no use in
        // visiting the current node and its subtree.
        continue;
      }
      for (Link<ClassHierarchyNode> link = currentNode._directSubclasses;
           !link.isEmpty;
           link = link.tail) {
        stack = stack.prepend(link.head);
      }
      if (_isValid(currentNode)) {
        return true;
      }
    }
  }

  /// Returns `true` if the class of [node] is a valid result for this iterator.
  bool _isValid(ClassHierarchyNode node) {
    if (!includeRoot && node == root) return false;
    return mask.intersects(node._mask);
  }
}

/// Iterable for the subtypes in a [ClassSet].
class SubtypesIterable extends IterableBase<ClassElement> {
  final ClassSet subtypeSet;
  final EnumSet<Instantiation> mask;
  final bool includeRoot;

  SubtypesIterable.SubtypesIterator(
      this.subtypeSet,
      this.mask,
      {this.includeRoot: true});

  @override
  Iterator<ClassElement> get iterator => new SubtypesIterator(this);
}

/// Iterator for the subtypes in a [ClassSet].
class SubtypesIterator extends Iterator<ClassElement> {
  final SubtypesIterable iterable;
  Iterator<ClassElement> elements;
  Iterator<ClassHierarchyNode> hierarchyNodes;

  SubtypesIterator(this.iterable);

  bool get includeRoot => iterable.includeRoot;

  EnumSet<Instantiation> get mask => iterable.mask;

  @override
  ClassElement get current {
    if (elements != null) {
      return elements.current;
    }
    return null;
  }

  @override
  bool moveNext() {
    if (elements == null && hierarchyNodes == null) {
      // Initial state. Iterate through subclasses.
      elements = iterable.subtypeSet.node.subclassesByMask(
          mask,
          strict: !includeRoot).iterator;
    }
    if (elements != null && elements.moveNext()) {
      return true;
    }
    if (hierarchyNodes == null) {
      // Start iterating through subtypes.
      hierarchyNodes = iterable.subtypeSet._directSubtypes.iterator;
    }
    while (hierarchyNodes.moveNext()) {
      elements = hierarchyNodes.current.subclassesByMask(mask).iterator;
      if (elements.moveNext()) {
        return true;
      }
    }
    return false;
  }
}
