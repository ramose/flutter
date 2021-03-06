// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'box.dart';
import 'object.dart';

// For SingleChildLayoutDelegate and RenderCustomSingleChildLayoutBox, see shifted_box.dart

/// [ParentData] used by [RenderCustomMultiChildLayoutBox].
class MultiChildLayoutParentData extends ContainerBoxParentData<RenderBox> {
  /// An object representing the identity of this child.
  Object id;

  @override
  String toString() => '${super.toString()}; id=$id';
}

/// A delegate that controls the layout of multiple children.
///
/// Delegates must be idempotent. Specifically, if two delegates are equal, then
/// they must produce the same layout. To change the layout, replace the
/// delegate with a different instance whose [shouldRelayout] returns true when
/// given the previous instance.
///
/// Override [getSize] to control the overall size of the layout. The size of
/// the layout cannot depend on layout properties of the children.
///
/// Override [performLayout] to size and position the children. An
/// implementation of [performLayout] must call [layoutChild] exactly once for
/// each child, but it may call [layoutChild] on children in an arbitrary order.
/// Typically a delegate will use the size returned from [layoutChild] on one
/// child to determine the constraints for [performLayout] on another child or
/// to determine the offset for [positionChild] for that child or another child.
///
/// Override [shouldRelayout] to determine when the layout of the children needs
/// to be recomputed when the delegate changes.
///
/// Used with [CustomMultiChildLayout], the widget for the
/// [RenderCustomMultiChildLayoutBox] render object.
///
/// ## Example
///
/// Below is an example implementation of [performLayout] that causes one widget
/// to be the same size as another:
///
/// ```dart
/// @override
/// void performLayout(Size size) {
///   Size followerSize = Size.zero;
///
///   if (hasChild(_Slots.leader) {
///     followerSize = layoutChild(_Slots.leader, new BoxConstraints.loose(size));
///     positionChild(_Slots.leader, Offset.zero);
///   }
///
///   if (hasChild(_Slots.follower)) {
///     layoutChild(_Slots.follower, new BoxConstraints.tight(followerSize));
///     positionChild(_Slots.follower, new Offset(size.width - followerSize.width,
///                                               size.height - followerSize.height));
///   }
/// }
/// ```
///
/// The delegate gives the leader widget loose constraints, which means the
/// child determines what size to be (subject to fitting within the given size).
/// The delegate then remembers the size of that child and places it in the
/// upper left corner.
///
/// The delegate then gives the follower widget tight constraints, forcing it to
/// match the size of the leader widget. The delegate then places the follower
/// widget in the bottom right corner.
///
/// The leader and follower widget will paint in the order they appear in the
/// child list, regardless of the order in which [layoutChild] is called on
/// them.
abstract class MultiChildLayoutDelegate {
  Map<Object, RenderBox> _idToChild;
  Set<RenderBox> _debugChildrenNeedingLayout;

  /// True if a non-null LayoutChild was provided for the specified id.
  ///
  /// Call this from the [performLayout] or [getSize] methods to
  /// determine which children are available, if the child list might
  /// vary.
  bool hasChild(Object childId) => _idToChild[childId] != null;

  /// Ask the child to update its layout within the limits specified by
  /// the constraints parameter. The child's size is returned.
  ///
  /// Call this from your [performLayout] function to lay out each
  /// child. Every child must be laid out using this function exactly
  /// once each time the [performLayout] function is called.
  Size layoutChild(Object childId, BoxConstraints constraints) {
    final RenderBox child = _idToChild[childId];
    assert(() {
      if (child == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to lay out a non-existent child.\n'
          'There is no child with the id "$childId".'
        );
      }
      if (!_debugChildrenNeedingLayout.remove(child)) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to lay out the child with id "$childId" more than once.\n'
          'Each child must be laid out exactly once.'
        );
      }
      try {
        assert(constraints.debugAssertIsValid(isAppliedConstraint: true));
      } on AssertionError catch (exception) {
        throw new FlutterError(
          'The $this custom multichild layout delegate provided invalid box constraints for the child with id "$childId".\n'
          '$exception\n'
          'The minimum width and height must be greater than or equal to zero.\n'
          'The maximum width must be greater than or equal to the minimum width.\n'
          'The maximum height must be greater than or equal to the minimum height.'
        );
      }
      return true;
    });
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  /// Specify the child's origin relative to this origin.
  ///
  /// Call this from your [performLayout] function to position each
  /// child. If you do not call this for a child, its position will
  /// remain unchanged. Children initially have their position set to
  /// (0,0), i.e. the top left of the [RenderCustomMultiChildLayoutBox].
  void positionChild(Object childId, Offset offset) {
    final RenderBox child = _idToChild[childId];
    assert(() {
      if (child == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate tried to position out a non-existent child:\n'
          'There is no child with the id "$childId".'
        );
      }
      if (offset == null) {
        throw new FlutterError(
          'The $this custom multichild layout delegate provided a null position for the child with id "$childId".'
        );
      }
      return true;
    });
    final MultiChildLayoutParentData childParentData = child.parentData;
    childParentData.offset = offset;
  }

  String _debugDescribeChild(RenderBox child) {
    final MultiChildLayoutParentData childParentData = child.parentData;
    return '${childParentData.id}: $child';
  }

  void _callPerformLayout(Size size, RenderBox firstChild) {
    // A particular layout delegate could be called reentrantly, e.g. if it used
    // by both a parent and a child. So, we must restore the _idToChild map when
    // we return.
    final Map<Object, RenderBox> previousIdToChild = _idToChild;

    Set<RenderBox> debugPreviousChildrenNeedingLayout;
    assert(() {
      debugPreviousChildrenNeedingLayout = _debugChildrenNeedingLayout;
      _debugChildrenNeedingLayout = new Set<RenderBox>();
      return true;
    });

    try {
      _idToChild = <Object, RenderBox>{};
      RenderBox child = firstChild;
      while (child != null) {
        final MultiChildLayoutParentData childParentData = child.parentData;
        assert(() {
          if (childParentData.id == null) {
            throw new FlutterError(
              'The following child has no ID:\n'
              '  $child\n'
              'Every child of a RenderCustomMultiChildLayoutBox must have an ID in its parent data.'
            );
          }
          return true;
        });
        _idToChild[childParentData.id] = child;
        assert(() {
          _debugChildrenNeedingLayout.add(child);
          return true;
        });
        child = childParentData.nextSibling;
      }
      performLayout(size);
      assert(() {
        if (_debugChildrenNeedingLayout.isNotEmpty) {
          if (_debugChildrenNeedingLayout.length > 1) {
            throw new FlutterError(
              'The $this custom multichild layout delegate forgot to lay out the following children:\n'
              '  ${_debugChildrenNeedingLayout.map(_debugDescribeChild).join("\n  ")}\n'
              'Each child must be laid out exactly once.'
            );
          } else {
            throw new FlutterError(
              'The $this custom multichild layout delegate forgot to lay out the following child:\n'
              '  ${_debugDescribeChild(_debugChildrenNeedingLayout.single)}\n'
              'Each child must be laid out exactly once.'
            );
          }
        }
        return true;
      });
    } finally {
      _idToChild = previousIdToChild;
      assert(() {
        _debugChildrenNeedingLayout = debugPreviousChildrenNeedingLayout;
        return true;
      });
    }
  }

  /// Override this method to return the size of this object given the
  /// incoming constraints.
  ///
  /// The size cannot reflect the sizes of the children. If this layout has a
  /// fixed width or height the returned size can reflect that; the size will be
  /// constrained to the given constraints.
  ///
  /// By default, attempts to size the box to the biggest size
  /// possible given the constraints.
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  /// Override this method to lay out and position all children given this
  /// widget's size.
  ///
  /// This method must call [layoutChild] for each child. It should also specify
  /// the final position of each child with [positionChild].
  void performLayout(Size size);

  /// Override this method to return true when the children need to be
  /// laid out.
  ///
  /// This should compare the fields of the current delegate and the given
  /// `oldDelegate` and return true if the fields are such that the layout would
  /// be different.
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate);

  /// Override this method to include additional information in the
  /// debugging data printed by [debugDumpRenderTree] and friends.
  ///
  /// By default, returns the [runtimeType] of the class.
  @override
  String toString() => '$runtimeType';
}

/// Defers the layout of multiple children to a delegate.
///
/// The delegate can determine the layout constraints for each child and can
/// decide where to position each child. The delegate can also determine the
/// size of the parent, but the size of the parent cannot depend on the sizes of
/// the children.
class RenderCustomMultiChildLayoutBox extends RenderBox
  with ContainerRenderObjectMixin<RenderBox, MultiChildLayoutParentData>,
       RenderBoxContainerDefaultsMixin<RenderBox, MultiChildLayoutParentData> {
  /// Creates a render object that customizes the layout of multiple children.
  ///
  /// The [delegate] argument must not be null.
  RenderCustomMultiChildLayoutBox({
    List<RenderBox> children,
    @required MultiChildLayoutDelegate delegate
  }) : _delegate = delegate {
    assert(delegate != null);
    addAll(children);
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! MultiChildLayoutParentData)
      child.parentData = new MultiChildLayoutParentData();
  }

  /// The delegate that controls the layout of the children.
  MultiChildLayoutDelegate get delegate => _delegate;
  MultiChildLayoutDelegate _delegate;
  set delegate(MultiChildLayoutDelegate value) {
    assert(value != null);
    if (_delegate == value)
      return;
    if (value.runtimeType != _delegate.runtimeType || value.shouldRelayout(_delegate))
      markNeedsLayout();
    _delegate = value;
  }

  Size _getSize(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.constrain(_delegate.getSize(constraints));
  }

  // TODO(ianh): It's a bit dubious to be using the getSize function from the delegate to
  // figure out the intrinsic dimensions. We really should either not support intrinsics,
  // or we should expose intrinsic delegate callbacks and throw if they're not implemented.

  @override
  double computeMinIntrinsicWidth(double height) {
    final double width = _getSize(new BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite)
      return width;
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final double width = _getSize(new BoxConstraints.tightForFinite(height: height)).width;
    if (width.isFinite)
      return width;
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final double height = _getSize(new BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite)
      return height;
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final double height = _getSize(new BoxConstraints.tightForFinite(width: width)).height;
    if (height.isFinite)
      return height;
    return 0.0;
  }

  @override
  void performLayout() {
    size = _getSize(constraints);
    delegate._callPerformLayout(size, firstChild);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(HitTestResult result, { Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }
}
