import 'package:flutter/material.dart';
import 'dart:io';
import '../models/app_info.dart';
import '../services/app_background_service.dart';

class GameGrid extends StatelessWidget {
  final List<AppInfo> apps;
  final Function(String) onLaunch;
  final int crossAxisCount;
  final Set<String> newlyAddedApps;
  final bool showAppNames;

  const GameGrid({
    super.key,
    required this.apps,
    required this.onLaunch,
    required this.crossAxisCount,
    required this.newlyAddedApps,
    this.showAppNames = true,
    this.iconSize = 36.0,
  });

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final int effectiveCrossAxisCount = orientation == Orientation.portrait
        ? crossAxisCount
        : (crossAxisCount * 1.6).round().clamp(2, 20);

    return GridView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      physics: const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: effectiveCrossAxisCount,
        childAspectRatio: 0.65, // Portrait rectangle aspect ratio
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      addAutomaticKeepAlives: false, // Help performance by disposing off-screen widgets
      addRepaintBoundaries: true,
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        return _AnimatedGameCard(
          key: ValueKey(app.packageName),
          index: index,
          app: app,
          onLaunch: () => onLaunch(app.packageName),
          isNew: newlyAddedApps.contains(app.packageName),
          showName: showAppNames,
          iconSize: iconSize,
        );
      },
    );
  }
}

class _AnimatedGameCard extends StatefulWidget {
  final int index;
  final AppInfo app;
  final VoidCallback onLaunch;
  final bool isNew;
  final bool showName;

  const _AnimatedGameCard({
    super.key,
    required this.index,
    required this.app,
    required this.onLaunch,
    required this.isNew,
    required this.showName,
    required this.iconSize,
  });

  final double iconSize;

  @override
  State<_AnimatedGameCard> createState() => _AnimatedGameCardState();
}

class _AnimatedGameCardState extends State<_AnimatedGameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(
        milliseconds: 300 + (widget.index % 10 * 50).clamp(0, 500),
      ),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    // Delay animation start to after the widget is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasAnimated) {
        _hasAnimated = true;
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasAnimated) {
      // Once animated, don't use AnimatedBuilder to save on rebuilds during scroll
      return RepaintBoundary(
        child: GameCard(
          app: widget.app,
          onLaunch: widget.onLaunch,
          isNew: widget.isNew,
          showName: widget.showName,
          iconSize: widget.iconSize,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        final double animValue = _scaleAnimation.value;
        final double clampedValue = animValue.clamp(0.0, 1.0);

        return RepaintBoundary(
          child: Transform.scale(
            scale: animValue,
            child: Opacity(opacity: clampedValue, child: child),
          ),
        );
      },
      child: GameCard(
        app: widget.app,
        onLaunch: widget.onLaunch,
        isNew: widget.isNew,
        showName: widget.showName,
        iconSize: widget.iconSize,
      ),
    );
  }
}

class GameCard extends StatefulWidget {
  final AppInfo app;
  final VoidCallback onLaunch;
  final bool isNew;
  final bool showName;

  const GameCard({
    super.key,
    required this.app,
    required this.onLaunch,
    this.isNew = false,
    this.showName = true,
    this.iconSize = 36.0,
  });

  final double iconSize;

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _glowController;
  String? _backgroundPath;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    if (widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _glowController.repeat(reverse: true);
        }
      });
    }

    // Load background synchronously since it's already pre-cached locally
    _backgroundPath = AppBackgroundService.getBackgroundSync(
      widget.app.packageName,
    );
  }

  @override
  void didUpdateWidget(GameCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isNew && !oldWidget.isNew) {
      _glowController.repeat(reverse: true);
    } else if (!widget.isNew && oldWidget.isNew) {
      _glowController.stop();
      _glowController.reset();
    }

    // Optimized: Only update background path if app changed
    if (widget.app.packageName != oldWidget.app.packageName) {
      _backgroundPath = AppBackgroundService.getBackgroundSync(
        widget.app.packageName,
      );
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.app.name;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onLaunch,
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
          final isNewGlow = widget.isNew ? _glowController.value : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
            transformAlignment: FractionalOffset.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border.all(
                color: widget.isNew
                    ? Color.lerp(
                        const Color(0xFF00D4FF),
                        const Color(0xFF9D4EDD),
                        isNewGlow,
                      )!
                    : _isPressed
                    ? const Color(0xFF00D4FF)
                    : Colors.transparent,
                width: widget.isNew ? 1.5 : (_isPressed ? 1.5 : 0),
              ),
              boxShadow: widget.isNew || _isPressed
                  ? [
                      BoxShadow(
                        color: widget.isNew
                            ? Color.lerp(
                                const Color(0xFF00D4FF),
                                const Color(0xFF9D4EDD),
                                isNewGlow,
                              )!.withOpacity(0.4)
                            : const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: widget.isNew ? 15 : 10,
                        spreadRadius: widget.isNew ? 1 : 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRect(
              child: Stack(
                children: [
                  // Background image or gradient
                  Positioned.fill(
                    child: _backgroundPath != null
                        ? Image.file(
                            File(_backgroundPath!),
                            fit: BoxFit.cover,
                            cacheWidth:
                                _backgroundPath!.toLowerCase().endsWith('.gif')
                                ? null
                                : 300,
                            cacheHeight:
                                _backgroundPath!.toLowerCase().endsWith('.gif')
                                ? null
                                : 450,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultBackground(widget.app),
                            gaplessPlayback: true,
                          )
                        : _buildDefaultBackground(widget.app),
                  ),
                  // Dark overlay for better icon visibility
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // App name at top (if enabled)
                  if (widget.showName)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Small icon at bottom left
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      width: widget.iconSize,
                      height: widget.iconSize,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF00D4FF).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: _buildIcon(),
                    ),
                  ),
                  // NEW badge
                  if (widget.isNew)
                    Positioned(
                      top: widget.showName ? 32 : 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00D4FF), Color(0xFF9D4EDD)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00D4FF).withOpacity(0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDefaultBackground(AppInfo app) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF1E2A4A)],
        ),
      ),
      child: Opacity(opacity: 0.25, child: _buildBackgroundIcon(app)),
    );
  }

  Widget _buildBackgroundIcon(AppInfo app) {
    if (app.iconPath != null) {
      return Image.file(
        File(app.iconPath!),
        fit: BoxFit.cover,
        cacheWidth: 300,
        cacheHeight: 450,
        gaplessPlayback: true,
      );
    } else if (app.iconBytes != null) {
      return Image.memory(
        app.iconBytes!,
        fit: BoxFit.cover,
        cacheWidth: 300,
        cacheHeight: 450,
        gaplessPlayback: true,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildIcon() {
    const int iconCacheSize = 72;

    if (widget.app.iconPath != null) {
      return Image.file(
        File(widget.app.iconPath!),
        fit: BoxFit.contain,
        cacheWidth: iconCacheSize,
        cacheHeight: iconCacheSize,
        errorBuilder: (context, error, stackTrace) => const PlaceholderIcon(),
        gaplessPlayback: true,
      );
    } else if (widget.app.iconBytes != null) {
      return Image.memory(
        widget.app.iconBytes!,
        fit: BoxFit.contain,
        cacheWidth: iconCacheSize,
        cacheHeight: iconCacheSize,
        errorBuilder: (context, error, stackTrace) =>
            PlaceholderIcon(size: widget.iconSize),
        gaplessPlayback: true,
      );
    } else {
      return PlaceholderIcon(size: widget.iconSize);
    }
  }
}

class PlaceholderIcon extends StatelessWidget {
  final double size;
  const PlaceholderIcon({super.key, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.sports_esports,
        size: size * 0.6,
        color: const Color(0xFF00D4FF),
      ),
    );
  }
}
