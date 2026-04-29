import 'package:flutter/material.dart';

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0033)),
      useMaterial3: true,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFF0033),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
