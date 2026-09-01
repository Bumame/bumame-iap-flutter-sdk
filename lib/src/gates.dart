import 'package:flutter/widgets.dart';
import 'principal.dart';

class IapPermissionGate extends StatelessWidget {
  const IapPermissionGate(
      {super.key,
      required this.principal,
      required this.anyOf,
      required this.child,
      this.fallback = const SizedBox.shrink()});
  final IapPrincipal? principal;
  final List<String> anyOf;
  final Widget child;
  final Widget fallback;
  @override
  Widget build(BuildContext context) =>
      principal?.hasAnyPermission(anyOf) == true ? child : fallback;
}

class IapRoleGate extends StatelessWidget {
  const IapRoleGate(
      {super.key,
      required this.principal,
      required this.anyOf,
      required this.child,
      this.fallback = const SizedBox.shrink()});
  final IapPrincipal? principal;
  final List<String> anyOf;
  final Widget child;
  final Widget fallback;
  @override
  Widget build(BuildContext context) =>
      principal?.hasAnyRole(anyOf) == true ? child : fallback;
}
