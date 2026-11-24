import 'package:material_ui/material_ui.dart';

abstract final class Palette {
  static const paper = Color(0xFF060B14);
  static const white = Color(0xFFF4F2EC);
  static const ink = Color(0xFFF4F2EC);
  static const secondary = Color(0xFFA9B8C6);
  static const line = Color(0xFF2E4659);
  static const board = Color(0xFF0C1725);
  static const tile = Color(0xFF122439);
  static const pipe = Color(0xFF74899B);
  static const light = Color(0xFFEBC990);
  static const rust = Color(0xFF9ADDDC);
}

ThemeData gameTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: Palette.paper,
  fontFamily: 'Manrope',
  useMaterial3: true,
  visualDensity: VisualDensity.standard,
  materialTapTargetSize: MaterialTapTargetSize.padded,
  colorScheme: const ColorScheme.dark(
    primary: Palette.light,
    onPrimary: Palette.paper,
    secondary: Palette.rust,
    onSecondary: Palette.paper,
    surface: Palette.board,
    onSurface: Palette.white,
    outline: Palette.secondary,
  ),
  iconTheme: const IconThemeData(size: 22, color: Palette.secondary),
  splashFactory: NoSplash.splashFactory,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 17, height: 1.4),
    bodyMedium: TextStyle(fontSize: 16, height: 1.35),
    bodySmall: TextStyle(fontSize: 13, height: 1.4),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 56),
      foregroundColor: Palette.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      side: const BorderSide(color: Palette.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: Palette.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: Palette.white,
    ),
  ),
  dividerTheme: const DividerThemeData(color: Palette.line, thickness: 1),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Palette.board,
    showDragHandle: true,
    dragHandleColor: Palette.secondary,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
  ),
);

TextStyle bookTitle(double size) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: FontWeight.w600,
  height: 1.15,
  letterSpacing: -size * .025,
  color: Palette.white,
);

class StarMark extends StatelessWidget {
  const StarMark({
    super.key,
    this.size = 22,
    this.filled = true,
    this.color = Palette.light,
  });
  final double size;
  final bool filled;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      filled ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: color,
    ),
  );
}
