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
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
  Widget build(BuildContext context) => PopupMenuButton<IapProfileAction>(
        tooltip: tooltip,
        position: PopupMenuPosition.under,
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
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.manage_accounts_outlined),
              title: Text('Profile settings'),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: IapProfileAction.logout,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded),
              title: Text('Log out'),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      principal.name ?? principal.email ?? 'Bumame user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      roleLabel ??
                          (principal.roles.isEmpty
                              ? 'User'
                              : principal.roles.first),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              IapAvatar(principal: principal),
            ],
          ),
        ),
      );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
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
