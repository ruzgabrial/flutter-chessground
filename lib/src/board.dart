import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';
import 'background.dart';
import 'piece.dart';
import 'highlight.dart';
import 'models.dart' as cg;
import 'position.dart';
import 'animation.dart';
import 'fen.dart';
import 'utils.dart';
import 'settings.dart';

const lightSquare = Color(0xfff0d9b6);
const darkSquare = Color(0xffb58863);
const lastMoveColor = Color(0x809cc700);

@immutable
class Board extends StatefulWidget {
  final double size;
  final Settings settings;

  final cg.Color orientation;
  final String fen;
  final cg.Move? lastMove;

  const Board({
    Key? key,
    this.settings = const Settings(),
    required this.size,
    required this.orientation,
    required this.fen,
    this.lastMove,
  }) : super(key: key);

  double get squareSize => size / 8;

  @override
  _BoardState createState() => _BoardState();
}

class _BoardState extends State<Board> {
  late cg.Pieces pieces;
  Map<String, Tuple2<cg.Coord, cg.Coord>> translatingPieces = {};
  Map<String, cg.Piece> fadingPieces = {};

  @override
  void initState() {
    super.initState();
    pieces = readFen(widget.fen);
  }

  @override
  void didUpdateWidget(Board oldBoard) {
    super.didUpdateWidget(oldBoard);
    translatingPieces = {};
    fadingPieces = {};
    final newPieces = readFen(widget.fen);
    final List<cg.PositionedPiece> newOnSquare = [];
    final List<cg.PositionedPiece> missingOnSquare = [];
    final Set<String> animatedOrigins = {};
    for (final s in allSquares) {
      final oldP = pieces[s];
      final newP = newPieces[s];
      final squareCoord = squareIdToCoord(s);
      if (newP != null) {
        if (oldP != null) {
          if (newP != oldP) {
            missingOnSquare.add(cg.PositionedPiece(
                piece: oldP, squareId: s, coord: squareCoord));
            newOnSquare.add(cg.PositionedPiece(
                piece: newP, squareId: s, coord: squareCoord));
          }
        } else {
          newOnSquare.add(
              cg.PositionedPiece(piece: newP, squareId: s, coord: squareCoord));
        }
      } else if (oldP != null) {
        missingOnSquare.add(
            cg.PositionedPiece(piece: oldP, squareId: s, coord: squareCoord));
      }
    }
    for (final n in newOnSquare) {
      final fromP = closestPiece(
          n, missingOnSquare.where((m) => m.piece == n.piece).toList());
      if (fromP != null) {
        final t = Tuple2<cg.Coord, cg.Coord>(fromP.coord, n.coord);
        translatingPieces[n.squareId] = t;
        animatedOrigins.add(fromP.squareId);
      }
    }
    for (final m in missingOnSquare) {
      if (!animatedOrigins.contains(m.squareId)) {
        fadingPieces[m.squareId] = m.piece;
      }
    }
    pieces = newPieces;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        children: [
          widget.settings.enableCoordinates
              ? widget.orientation == cg.Color.white
                  ? Background.brownWhiteCoords
                  : Background.brownBlackCoords
              : Background.brown,
          Stack(
            children: [
              if (widget.settings.showLastMove && widget.lastMove != null)
                for (final squareId in widget.lastMove!.squares)
                  BoardPositioned(
                    key: ValueKey('lastMove' + squareId),
                    size: widget.squareSize,
                    orientation: widget.orientation,
                    squareId: squareId,
                    child: Highlight(
                      size: widget.squareSize,
                      color: lastMoveColor,
                    ),
                  ),
              for (final entry in fadingPieces.entries)
                BoardPositioned(
                  key: ValueKey('fading' + entry.key + entry.value.kind),
                  size: widget.squareSize,
                  orientation: widget.orientation,
                  squareId: entry.key,
                  child: PieceFade(
                    curve: Curves.easeInCubic,
                    duration: widget.settings.animationDuration,
                    child: UIPiece(
                      piece: entry.value,
                      size: widget.squareSize,
                    ),
                  ),
                ),
              for (final entry in pieces.entries)
                BoardPositioned(
                  key: ValueKey(entry.key + entry.value.kind),
                  size: widget.squareSize,
                  orientation: widget.orientation,
                  squareId: entry.key,
                  child: translatingPieces.containsKey(entry.key)
                      ? PieceTranslation(
                          child: UIPiece(
                            piece: entry.value,
                            size: widget.squareSize,
                          ),
                          fromCoord: translatingPieces[entry.key]!.item1,
                          toCoord: translatingPieces[entry.key]!.item2,
                          orientation: widget.orientation,
                          duration: widget.settings.animationDuration,
                        )
                      : UIPiece(
                          piece: entry.value,
                          size: widget.squareSize,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
