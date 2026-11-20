// Native stub for the web ledger opener. Selected (via a conditional import in
// `main.dart`) whenever `dart.library.html` is absent — i.e. every native
// (mobile / desktop) build. The real implementation lives in `web_ledger.dart`
// and is never compiled here, so `package:drift/wasm.dart` is kept out of the
// native build.
//
// `openWebLedger` is only ever called from inside a `kIsWeb` branch, so this
// throw is unreachable on a native build.
import 'local_ledger.dart';

Future<LocalLedger> openWebLedger() =>
    throw UnsupportedError('openWebLedger is only available on the web');
