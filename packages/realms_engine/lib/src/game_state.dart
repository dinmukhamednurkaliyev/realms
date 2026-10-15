import 'package:realms_engine/src/direction.dart';
import 'package:realms_engine/src/game_board.dart';
import 'package:realms_engine/src/movement.dart';

final class GameState {
  const new(this.board);

  final GameBoard board;

  GameState move(Direction direction) {
    final movedRows = moveBoard(board.rows, direction);
    final nextBoard = GameBoard(movedRows);

    if (board.hasSameTilesAs(nextBoard)) {
      return this;
    }

    return GameState(nextBoard);
  }
}
