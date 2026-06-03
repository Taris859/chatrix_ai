import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class QuietChessSpace extends StatelessWidget {
  const QuietChessSpace({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a controller locally for this stateless widget
    final ChessBoardController controller = ChessBoardController();
    return Center(
      child: ChessBoard(
        controller: controller,
        boardColor: BoardColor.brown,
        size: MediaQuery.of(context).size.width * 0.9,
        // Simple AI: no custom onMove needed for now
        onMove: () {},
      ),
    );
  }
}
