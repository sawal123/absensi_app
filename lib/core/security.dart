import 'dart:convert';

import 'package:crypto/crypto.dart';

const _salt = 'absensi_app_salt_v1';

String hashPassword(String password) =>
    sha256.convert(utf8.encode('$_salt:$password')).toString();
