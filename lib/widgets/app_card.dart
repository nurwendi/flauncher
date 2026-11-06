/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:ui';

import 'package:flauncher/database.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/ticker_model.dart';
import 'package:flauncher/widgets/application_info_panel.dart';
import 'package:flauncher/widgets/color_helpers.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _validationKeys = [LogicalKeyboardKey.select, LogicalKeyboardKey.enter, LogicalKeyboardKey.gameButtonA];

class AppCard extends StatefulWidget {
  final Category category;
  final App application;
  final bool autofocus;
  final void Function(AxisDirection) onMove;
  final VoidCallback onMoveEnd;

  AppCard({
    Key? key,
    required this.category,
    required this.application,
    required this.autofocus,
    required this.onMove,
    required this.onMoveEnd,
  }) : super(key: key);

  @override
  _AppCardState createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  bool _moving = false;
  MemoryImage? _imageProvider;
  late final AnimationController _animation = AnimationController(
    vsync: Provider.of<TickerModel>(context, listen: false).tickerProvider ?? this,
    duration: Duration(
      milliseconds: 800,
    ),
  );
  Color _lastBorderColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((animationStatus) {
      switch (animationStatus) {
        case AnimationStatus.completed:
          _animation.reverse();
          break;
        case AnimationStatus.dismissed:
          _animation.forward();
          break;
        case AnimationStatus.forward:
        case AnimationStatus.reverse:
          // nothing to do
          break;
      }
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  ImageProvider _cachedMemoryImage(Uint8List bytes) {
    if (!listEquals(bytes, _imageProvider?.bytes)) {
      _imageProvider = MemoryImage(bytes);
    }
    return _imageProvider!;
  }

  @override
  Widget build(BuildContext context) => FocusKeyboardListener(
        onPressed: (key) => _onPressed(context, key),
        onLongPress: (key) => _onLongPress(context, key),
        builder: (context) => AspectRatio(
          aspectRatio: 16 / 9,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transformAlignment: Alignment.center,
            transform: _scaleTransform(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: Focus.of(context).hasFocus
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Frosted glass background layer
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: Focus.of(context).hasFocus
                                ? [Colors.white.withOpacity(0.28), Colors.white.withOpacity(0.15)]
                                : [Colors.black.withOpacity(0.45), Colors.black.withOpacity(0.25)],
                          ),
                        ),
                      ),
                    ),
                    // App Banner or Icon + Name (crisp foreground, never blurred)
                    InkWell(
                      autofocus: widget.autofocus,
                      focusColor: Colors.transparent,
                      onTap: () => _onPressed(context, null),
                      onLongPress: () => _onLongPress(context, null),
                      child: widget.application.banner != null
                          ? Ink.image(
                              image: _cachedMemoryImage(widget.application.banner!),
                              fit: BoxFit.cover,
                            )
                          : Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Ink.image(
                                      image: _cachedMemoryImage(widget.application.icon!),
                                      height: double.infinity,
                                    ),
                                  ),
                                  Flexible(
                                    flex: 3,
                                    child: Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Text(
                                        widget.application.name,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              shadows: [
                                                Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1))
                                              ],
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    // Border overlay
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Focus.of(context).hasFocus
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            width: Focus.of(context).hasFocus ? 2.5 : 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (_moving) ..._arrows(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Matrix4 _scaleTransform(BuildContext context) {
    final scale = _moving
        ? 1.0
        : Focus.of(context).hasFocus
            ? 1.1
            : 1.0;
    return Matrix4.diagonal3Values(scale, scale, 1.0);
  }

  List<Widget> _arrows() => [
        _arrow(Alignment.centerLeft, Icons.keyboard_arrow_left),
        _arrow(Alignment.topCenter, Icons.keyboard_arrow_up),
        _arrow(Alignment.bottomCenter, Icons.keyboard_arrow_down),
        _arrow(Alignment.centerRight, Icons.keyboard_arrow_right),
      ];

  Widget _arrow(Alignment alignment, IconData icon) => Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(0.8),
            ),
            child: Icon(
              icon,
              size: 16,
            ),
          ),
        ),
      );

  KeyEventResult _onPressed(BuildContext context, LogicalKeyboardKey? key) {
    if (_moving) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Scrollable.ensureVisible(context,
          alignment: 0.1, duration: Duration(milliseconds: 100), curve: Curves.easeInOut));
      if (key == LogicalKeyboardKey.arrowLeft) {
        widget.onMove(AxisDirection.left);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        widget.onMove(AxisDirection.up);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        widget.onMove(AxisDirection.right);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        widget.onMove(AxisDirection.down);
      } else if (_validationKeys.contains(key)) {
        setState(() => _moving = false);
        widget.onMoveEnd();
      }
      return KeyEventResult.handled;
    } else if (_validationKeys.contains(key)) {
      context.read<AppsService>().launchApp(widget.application);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onLongPress(BuildContext context, LogicalKeyboardKey? key) {
    if (!_moving && (key == null || longPressableKeys.contains(key))) {
      _showPanel(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showPanel(BuildContext context) async {
    final result = await showDialog<ApplicationInfoPanelResult>(
      context: context,
      builder: (context) => ApplicationInfoPanel(
        category: widget.category,
        application: widget.application,
      ),
    );
    if (result == ApplicationInfoPanelResult.reorderApp) {
      setState(() => _moving = true);
    }
  }
}
