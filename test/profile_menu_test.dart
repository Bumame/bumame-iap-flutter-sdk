import 'package:bumame_iap_flutter/bumame_iap_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const principal = IapPrincipal(
    subject: 'user-1',
    issuer: 'https://auth.bumame.com',
    audience: ['urn:bumame:cis'],
    roles: ['app-and-data', 'vpn.access', 'cis.doctor'],
    permissions: [],
    name: 'Irfan Ghifari',
  );

  testWidgets('shows identity and invokes profile action', (tester) async {
    var profileOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IapProfileMenu(
                principal: principal,
                applicationKey: 'cis',
                onProfile: () => profileOpened = true,
                onLogout: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Irfan Ghifari'), findsOneWidget);
    expect(find.text('Doctor'), findsOneWidget);
    final localTheme = tester.widget<Theme>(
      find
          .ancestor(
            of: find.byType(PopupMenuButton<IapProfileAction>),
            matching: find.byType(Theme),
          )
          .first,
    );
    expect(localTheme.data.hoverColor, Colors.transparent);
    expect(localTheme.data.focusColor, Colors.transparent);
    expect(localTheme.data.highlightColor, Colors.transparent);
    expect(localTheme.data.splashColor, Colors.transparent);
    await tester.tap(find.text('Irfan Ghifari'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile settings'));
    expect(profileOpened, isTrue);
  });

  testWidgets('shows the role owned by the active application', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IapProfileMenu(
                principal: principal,
                applicationKey: 'cis',
                onProfile: () {},
                onLogout: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('app-and-data'), findsNothing);
    expect(find.text('VPN Access'), findsNothing);
  });

  testWidgets('formats an explicit namespaced role for people', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IapProfileMenu(
                principal: principal,
                roleLabel: 'cis.ops-admin',
                onProfile: () {},
                onLogout: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ops Admin'), findsOneWidget);
    expect(find.text('cis.ops-admin'), findsNothing);
  });
}
