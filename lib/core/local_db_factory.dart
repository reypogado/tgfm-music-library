import 'local_db_interface.dart';
import 'local_db_stub.dart'
    if (dart.library.html) 'local_db_web.dart'
    if (dart.library.io) 'local_db_mobile.dart';

LocalDb createLocalDb() => createLocalDbImpl();