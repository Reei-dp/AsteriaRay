import 'dart:io';

/// `true` when [host] is a hostname and needs bootstrap DNS before dial.
bool xrayHostNeedsDnsBootstrap(String host) =>
    InternetAddress.tryParse(host) == null;
