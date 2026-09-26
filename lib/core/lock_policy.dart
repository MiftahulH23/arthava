/// Aturan kapan layar Kunci Aplikasi ditampilkan saat aplikasi dibuka.
bool shouldShowLock({required bool enabled, required bool isWeb, required bool deviceSupported}) =>
    enabled && !isWeb && deviceSupported;
