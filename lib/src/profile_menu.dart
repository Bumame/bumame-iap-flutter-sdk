import 'dart:async';

import 'package:flutter/material.dart';

import 'principal.dart';

enum IapProfileAction { profile, logout }

class IapAvatar extends StatelessWidget {
  const IapAvatar({super.key, required this.principal, this.radius = 18});

  final IapPrincipal principal;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final picture = principal.picture?.trim();
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4777D7), Color(0xFF204EAB)],
        ),
        border: Border.all(color: const Color(0xFFDCE5F5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: picture != null && picture.isNotEmpty
            ? Image.network(
                picture,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(
                  name: principal.name ?? principal.email ?? '?',
                ),
              )
            : _Initials(name: principal.name ?? principal.email ?? '?'),
      ),
    );
  }
}

class IapProfileMenu extends StatelessWidget {
  const IapProfileMenu({
    super.key,
    required this.principal,
    required this.onProfile,
    required this.onLogout,
    this.roleLabel,
    this.showIdentity = true,
    this.tooltip = 'Account menu',
  });

  final IapPrincipal principal;
  final FutureOr<void> Function() onProfile;
  final FutureOr<void> Function() onLogout;
  final String? roleLabel;
  final bool showIdentity;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopupMenuButton<IapProfileAction>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      elevation: 8,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE1E7F0)),
      ),
      menuPadding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 210),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(999),
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed)) {
            return const Color(0x142C4DA5);
          }
          return Colors.transparent;
        }),
      ),
      onSelected: (action) {
        switch (action) {
          case IapProfileAction.profile:
            unawaited(Future.sync(onProfile));
          case IapProfileAction.logout:
            unawaited(Future.sync(onLogout));
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: IapProfileAction.profile,
          height: 44,
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, size: 19),
              SizedBox(width: 12),
              Text('Profile settings'),
            ],
          ),
        ),
        PopupMenuDivider(height: 9),
        PopupMenuItem(
          value: IapProfileAction.logout,
          height: 44,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 19, color: Color(0xFFB63737)),
              SizedBox(width: 12),
              Text('Log out', style: TextStyle(color: Color(0xFFB63737))),
            ],
          ),
        ),
      ],
      child: Semantics(
        button: true,
        label: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIdentity) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      principal.name ?? principal.email ?? 'Bumame user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF17213A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roleLabel ??
                          (principal.roles.isEmpty
                              ? 'User'
                              : principal.roles.first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF66728D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
            IapAvatar(principal: principal),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF7B879F),
            ),
          ],
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
          ),
        ),
      );
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  return parts.map((part) => part[0]).join().toUpperCase();
}
