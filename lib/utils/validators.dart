class Validators {
  Validators._();

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    final validFormat = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(text);
    final parts = text.split('@');
    final localPart = parts.isEmpty ? '' : parts.first;
    if (!validFormat || localPart.endsWith('.')) return 'Email không hợp lệ';
    return null;
  }
}
