import 'package:flutter/material.dart';

/// Custom page route with smooth slide transitions for bottom navigation
class CustomPageRoute extends PageRouteBuilder {
  final Widget child;
  final int direction; // -1 for left (backward), 1 for right (forward)

  CustomPageRoute({
    required this.child,
    this.direction = 1,
  }) : super(
          transitionDuration: const Duration(milliseconds: 200), // Fast transition
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide transition based on direction
            final Offset begin = Offset(direction * 1.0, 0.0);
            const Offset end = Offset.zero;
            const Curve curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

/// Fade transition route for smoother navigation
class FadePageRoute extends PageRouteBuilder {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          transitionDuration: const Duration(milliseconds: 150), // Very fast
          reverseTransitionDuration: const Duration(milliseconds: 150),
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
}

