import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';

/// The frame of the entry screens after Login (Criar conta, Código, Entrar
/// com e-mail, Esqueci a senha), as drawn in Claude Design: the round back
/// button, a big [title], an optional [subtitle], the [fields] and the
/// [actions] pinned to the bottom.
class EntryPage extends StatelessWidget {
  const EntryPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.fields,
    required this.actions,
  });

  final String title;
  final Widget? subtitle;
  final List<Widget> fields;

  /// The main button first; secondary links under it.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: _BackButton(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 28, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: AppColors.ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        DefaultTextStyle.merge(
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.inkMuted,
                          ),
                          child: subtitle!,
                        ),
                      ],
                      for (final field in fields) ...[
                        const SizedBox(height: 18),
                        field,
                      ],
                    ],
                  ),
                ),
              ),
              for (final (index, action) in actions.indexed) ...[
                if (index > 0) const SizedBox(height: 8),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Voltar',
      excludeSemantics: true,
      child: Material(
        color: AppColors.mist,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox.square(
            dimension: 44,
            child: Icon(Icons.chevron_left, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}
