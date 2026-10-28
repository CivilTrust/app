export 'vault_storage_stub.dart'
    if (dart.library.io) 'vault_storage_native.dart'
    if (dart.library.js_interop) 'vault_storage_web.dart';
