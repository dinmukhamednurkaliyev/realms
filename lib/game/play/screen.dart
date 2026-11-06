import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:realms/app/appearance/appearance.dart';
import 'package:realms/app/audio/audio.dart';
import 'package:realms/app/localization/localization.dart';
import 'package:realms/game/engine/engine.dart';

import 'board.dart';
import 'controller.dart';

/// Displays a Classic game with touch, keyboard, and sound feedback.
final class PlayScreen extends StatefulWidget {
  /// Creates the Classic game screen.
  const new({this.controller, this.audio, super.key});

  /// An optional externally owned session; otherwise the screen owns one.
  final PlayController? controller;

  /// Shared application playback; null makes this screen silent.
  /// The screen never owns or disposes this dependency.
  final AudioPlayback? audio;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

final class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  static const double _minimumSwipeDistance = 30;

  final FocusNode _focusNode = FocusNode(debugLabel: 'Realms play controls');

  Offset _panDistance = Offset.zero;

  late PlayController _controller;
  late final AnimationController _boardAnimation;
  GameMoveResult? _feedbackMove;
  late GameState _observedState;

  bool _mergeSoundPlayed = false;

  void _playSound(SoundEffect effect, {required double volume}) {
    // Preserve the existing full-volume debug override for feedback.
    final playbackVolume = kDebugMode ? 1.0 : volume;
    widget.audio?.play(effect, volume: playbackVolume);
  }

  void _onAnimationFrame() {
    final move = _feedbackMove;

    // Play the merge effect once, when the sliding phase has finished.
    if (!_mergeSoundPlayed &&
        _boardAnimation.value >= PlayBoard.slideEnd &&
        move != null &&
        move.merges.isNotEmpty) {
      _mergeSoundPlayed = true;

      _playSound(
        SoundEffect.merge,
        volume: move.merges.length > 1 ? 0.42 : 0.34,
      );
    }

    if (mounted) setState(() {});
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? PlayController();
    _observedState = _controller.state;

    // Preload audio without blocking the game screen.
    unawaited(widget.audio?.initialize());

    _boardAnimation =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 240),
            value: 1,
          )
          ..addListener(_onAnimationFrame)
          ..addStatusListener(_onAnimationStatus);

    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final nextState = _controller.state;

    if (!identical(_observedState, nextState)) {
      _observedState = nextState;

      if (_controller.lastMove != null) {
        // A new move starts a new sound and animation sequence.
        _mergeSoundPlayed = false;
        _feedbackMove = _controller.lastMove;

        _playSound(SoundEffect.slide, volume: 0.18);
        _boardAnimation.forward(from: 0);
      } else {
        // Restart cancels the previous animation and its pending merge.
        _mergeSoundPlayed = false;
        _feedbackMove = null;
        _boardAnimation.value = 1;
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.audio != widget.audio) {
      unawaited(widget.audio?.initialize());
    }
    if (oldWidget.controller == widget.controller) return;

    _controller.removeListener(_onChanged);

    if (oldWidget.controller == null) {
      _controller.dispose();
    }

    _controller = widget.controller ?? PlayController();
    _observedState = _controller.state;
    _mergeSoundPlayed = false;
    _feedbackMove = null;

    // The updated controller starts from its current snapshot, without a tween.
    _boardAnimation.removeListener(_onAnimationFrame);
    _boardAnimation.removeStatusListener(_onAnimationStatus);

    _boardAnimation.value = 1;

    _boardAnimation.addListener(_onAnimationFrame);
    _boardAnimation.addStatusListener(_onAnimationStatus);

    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);

    if (widget.controller == null) {
      _controller.dispose();
    }

    _boardAnimation.removeListener(_onAnimationFrame);
    _boardAnimation.removeStatusListener(_onAnimationStatus);
    _boardAnimation.dispose();

    _focusNode.dispose();

    super.dispose();
  }

  KeyEventResult _handleKeyEvent(KeyEvent event, {required bool canMove}) {
    // Ignore key repeats to ensure a held key does not produce extra moves.
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Leave operating-system and application shortcuts untouched.
    final keyboard = HardwareKeyboard.instance;

    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.keyA => MoveDirection.left,

      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.keyD => MoveDirection.right,

      LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => MoveDirection.up,

      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.keyS => MoveDirection.down,

      _ => null,
    };

    if (direction == null) {
      return KeyEventResult.ignored;
    }

    if (canMove) {
      _controller.move(direction);
    }

    return KeyEventResult.handled;
  }

  void _handlePanEnd(bool canMove) {
    final distance = _panDistance;
    _panDistance = Offset.zero;

    if (!canMove) {
      return;
    }

    final horizontal = distance.dx.abs();
    final vertical = distance.dy.abs();

    if (max(horizontal, vertical) < _minimumSwipeDistance) {
      return;
    }

    final direction = horizontal >= vertical
        ? (distance.dx < 0 ? MoveDirection.left : MoveDirection.right)
        : (distance.dy < 0 ? MoveDirection.up : MoveDirection.down);

    _controller.move(direction);
  }

  Future<void> _dismissTutorial() async {
    await _controller.dismissTutorial();

    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context).game;
    final gameState = _controller.state;
    final showTutorial = _controller.showTutorial;

    final canMove = _controller.canMove && !_boardAnimation.isAnimating;

    final board = gameState.board;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event, canMove: canMove),
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.classicMode),
          actions: [
            IconButton(
              onPressed: () => _controller.startNewGame(),
              tooltip: localization.newGame,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Padding(
                    padding: const EdgeInsets.all(spaceRegular),
                    child: Column(
                      children: [
                        Text(localization.scoreLabel),
                        Text(
                          localization.score(points: gameState.score),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: spaceRegular),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              key: const ValueKey('play_board'),
                              behavior: HitTestBehavior.opaque,
                              onPanStart: canMove
                                  ? (details) => _panDistance = Offset.zero
                                  : null,
                              onPanUpdate: canMove
                                  ? (details) => _panDistance += details.delta
                                  : null,
                              onPanCancel: canMove
                                  ? () => _panDistance = Offset.zero
                                  : null,
                              onPanEnd: canMove
                                  ? (details) => _handlePanEnd(canMove)
                                  : null,
                              child: PlayBoard(
                                board: board,
                                previousBoard: _controller.previousBoard,
                                lastMove: _controller.lastMove,
                                progress: _boardAnimation.value,
                              ),
                            ),
                          ),
                        ),
                        if (gameState.status == GameStatus.won)
                          Text(localization.youWon)
                        else if (gameState.status == GameStatus.lost)
                          Text(localization.gameOver),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showTutorial) ...[
              Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: GameAppearance.of(context).tutorialScrim,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(spaceLarge),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(spaceLarge),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.touch_app_outlined, size: 52),
                            const SizedBox(height: spaceMedium),
                            Text(
                              localization.howToPlayTitle,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              localization.howToPlayDescription,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: spaceSmall),
                            Text(
                              localization.howToPlayKeyboard,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: spaceLarge),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _dismissTutorial,
                                child: Text(localization.gotIt),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
