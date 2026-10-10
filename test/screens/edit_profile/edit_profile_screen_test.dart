import 'package:arthava/providers/edit_profile_provider.dart';
import 'package:arthava/screens/edit_profile/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../helpers/pump_app.dart';

class _FakeEditProfileNotifier extends EditProfileNotifier {
  String? savedName;
  Object? failWith;

  @override
  EditProfileState build() => const EditProfileState();

  @override
  Future<void> updateProfile(String name) async {
    if (failWith != null) throw failWith!;
    savedName = name;
  }
}

Future<_FakeEditProfileNotifier> _open(WidgetTester tester, {String name = 'Akun Tes'}) async {
  late _FakeEditProfileNotifier fake;
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditProfileScreen(
                initialName: name,
                initialEmail: 'akun.tes@email.com',
              ),
            ),
          ),
          child: const Text('buka'),
        ),
      ),
    ),
    overrides: [
      editProfileProvider.overrideWith(() => fake = _FakeEditProfileNotifier()),
    ],
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  // initialsOf() sudah dites di Plan B3 (test/core/formatters_test.dart);
  // di sini cukup test widget avatar (nama kosong → ikon user, bukan '?').

  testWidgets('Edit Profil menampilkan avatar inisial, email terkunci, dan field nama', (tester) async {
    await _open(tester);

    expect(find.text('AT'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget); // label kembali
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('akun.tes@email.com'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.lockSimple), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Simpan Perubahan'), findsOneWidget);
  });

  testWidgets('Avatar mengikuti nama yang diketik; nama kosong menampilkan ikon', (tester) async {
    await _open(tester);

    await tester.enterText(find.byType(EditableText).last, 'Budi Santoso');
    await tester.pump();
    expect(find.text('BS'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).last, '');
    await tester.pump();
    expect(find.byIcon(PhosphorIconsFill.user), findsOneWidget);
  });

  testWidgets('Nama berisi spasi saja ditolak tanpa memanggil provider', (tester) async {
    final fake = await _open(tester);

    await tester.enterText(find.byType(EditableText).last, '   ');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();

    expect(find.text('Nama tidak boleh kosong'), findsOneWidget);
    expect(fake.savedName, isNull);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Simpan sukses meneruskan nama ter-trim lalu kembali', (tester) async {
    final fake = await _open(tester);

    await tester.enterText(find.byType(EditableText).last, '  Budi  ');
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(fake.savedName, 'Budi');
    expect(find.text('buka'), findsOneWidget);
    expect(find.text('Profil berhasil diperbarui!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Simpan gagal menampilkan error dan tetap di layar', (tester) async {
    final fake = await _open(tester);
    fake.failWith = Exception('jaringan');

    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();

    expect(find.textContaining('Gagal update'), findsOneWidget);
    expect(find.text('Edit Profil'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
