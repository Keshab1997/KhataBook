import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khatabook/features/entry/category_store.dart';
import 'package:khatabook/features/ledger/data/local_ledger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('custom category keeps its id through rename and archive', () async {
    final ledger = LocalLedger(NativeDatabase.memory());
    addTearDown(ledger.close);
    final store = CategoryStore(ledger);
    final category = await store.add('  Tea  ', iconIndex: 1, colorIndex: 1);
    expect(category.id, startsWith('custom:'));
    expect((await store.load()).single.name, 'Tea');
    await store.rename(category.id, 'Coffee');
    expect((await store.load()).single.id, category.id);
    expect((await store.load()).single.name, 'Coffee');
    await store.archive(category.id);
    expect(await store.load(), isEmpty);
    expect((await store.load(includeArchived: true)).single.archived, isTrue);
    await expectLater(store.add(''), throwsFormatException);
  });
}
