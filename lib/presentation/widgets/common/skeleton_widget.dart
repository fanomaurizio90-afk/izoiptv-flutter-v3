import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Shimmer skeleton — replaces loading spinners.
/// Base: #1A1A1A, shimmer: subtle gradient sweeping left to right, 1.5s loop.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 6.0,
  });
  final double? width;
  final double? height;
  final double  borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width:  widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin:  Alignment(_anim.value - 1, 0),
            end:    Alignment(_anim.value,     0),
            colors: const [
              AppColors.skeleton,
              AppColors.skeletonShine,
              AppColors.skeleton,
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the channel list
class SkeletonChannelList extends StatelessWidget {
  const SkeletonChannelList({super.key, this.count = 10});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics:     const NeverScrollableScrollPhysics(),
      itemCount:   count,
      itemExtent:  68,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:  MainAxisAlignment.center,
                children: [
                  SkeletonBox(height: 13, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for poster grids (movies / series)
class SkeletonPosterGrid extends StatelessWidget {
  const SkeletonPosterGrid({super.key, this.columns = 5, this.rows = 2});
  final int columns;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics:      const NeverScrollableScrollPhysics(),
      padding:      const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   columns,
        crossAxisSpacing: 8,
        mainAxisSpacing:  8,
        childAspectRatio: 2 / 3,
      ),
      itemCount:   columns * rows,
      itemBuilder: (_, __) => const SkeletonBox(borderRadius: 8),
    );
  }
}

/// Skeleton for the detail screen backdrop
class SkeletonDetailBackdrop extends StatelessWidget {
  const SkeletonDetailBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: double.infinity, height: h * 0.45, borderRadius: 0),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 280, height: 28, borderRadius: 6),
              SizedBox(height: 10),
              SkeletonBox(width: 180, height: 14, borderRadius: 4),
              SizedBox(height: 20),
              SkeletonBox(height: 13, borderRadius: 4),
              SizedBox(height: 6),
              SkeletonBox(height: 13, borderRadius: 4),
              SizedBox(height: 6),
              SkeletonBox(width: 200, height: 13, borderRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
