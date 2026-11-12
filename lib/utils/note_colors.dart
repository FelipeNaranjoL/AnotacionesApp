import 'package:flutter/material.dart';

/// Índice 0 = sin color. Se guarda el índice en la base de datos,
/// así la paleta puede cambiar sin migrar datos.
const List<Color?> noteSeeds = [
  null,
  Color(0xFFF28B82), // rojo
  Color(0xFFFBBC04), // naranja
  Color(0xFFFFF475), // amarillo
  Color(0xFFCCFF90), // verde
  Color(0xFFA7FFEB), // turquesa
  Color(0xFFAECBFA), // azul
  Color(0xFFD7AEFB), // morado
];

Color? noteSeed(int index) =>
    (index <= 0 || index >= noteSeeds.length) ? null : noteSeeds[index];

/// Color de fondo de una nota, adaptado a modo claro/oscuro.
Color noteSurface(BuildContext context, int index, {Color? base}) {
  final theme = Theme.of(context);
  final b = base ?? theme.colorScheme.surface;
  final seed = noteSeed(index);
  if (seed == null) return b;
  final dark = theme.brightness == Brightness.dark;
  return Color.alphaBlend(seed.withValues(alpha: dark ? 0.22 : 0.45), b);
}