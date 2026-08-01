/// password_field.dart – Passwortfeld mit Anzeigen-Umschalter (Auge).
///
/// Übernommen aus der Schwester-App MitFahrBar, wo es sich im Feld bewährt
/// hat: Das Auge macht das Getippte sichtbar — der wirksamere
/// Tippfehler-Schutz als blindes Doppelt-Tippen, und beim Anmelden die
/// einzige Kontrolle, die es überhaupt gibt. Überall verwenden, wo ein
/// Passwort eingegeben wird, damit sich das Verhalten nicht aufteilt.
library;

import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.labelText,
    this.helperText,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Passwort anzeigen' : 'Passwort verbergen',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      obscureText: _obscure,
      autofocus: widget.autofocus,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
    );
  }
}
