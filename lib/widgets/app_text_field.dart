import 'package:catat_uang_app/core/colors.dart';
import 'package:catat_uang_app/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Field putih gaya iOS. Default tanpa border (radius 16); [outlined] =
/// isian terpisah radius 14 bergaris tepi 1.5px, fokus menampilkan garis
/// biru + cincin 4px (layar Login/Daftar).
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.readOnly = false,
    this.maxLines = 1,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.label,
    this.onChanged,
    this.inputFormatters,
    this.outlined = false,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool readOnly;
  final int maxLines;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  /// Label kecil opsional di atas input (gaya baris iOS "Nama Lengkap" +
  /// nilai). Null = tanpa label.
  final String? label;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool outlined;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  bool _focused = false;

  void _onFocusChange() {
    if (_focused != _node.hasFocus) setState(() => _focused = _node.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.focusNode ?? _ownNode;
    if (previous != _node) {
      previous?.removeListener(_onFocusChange);
      _node.addListener(_onFocusChange);
      _focused = _node.hasFocus;
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _ownNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.outlined) return _buildOutlined();
    final radius = BorderRadius.circular(16);
    final field = TextField(
      controller: widget.controller,
      focusNode: _node,
      autofocus: widget.autofocus,
      textCapitalization: widget.textCapitalization,
      obscureText: widget.obscure,
      keyboardType: widget.keyboardType,
      readOnly: widget.readOnly,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      style: AppTextStyles.body,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20, color: AppColors.textSecondary),
        suffixIcon: widget.suffix,
        filled: true,
        fillColor: widget.readOnly ? AppColors.track : AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
    if (widget.label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(widget.label!, style: AppTextStyles.caption),
        ),
        field,
      ],
    );
  }

  /// Kotak terpisah bergaris tepi. Garis & cincin digambar kotak pembungkus
  /// (bukan InputBorder) supaya label bisa duduk di dalam kotak, bukan di
  /// garis tepi seperti OutlineInputBorder.
  Widget _buildOutlined() {
    final radius = BorderRadius.circular(14);
    final labelStyle = AppTextStyles.subhead.copyWith(fontWeight: FontWeight.w600);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: widget.readOnly ? AppColors.track : AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: _focused ? AppColors.primary : AppColors.track, width: 1.5),
        boxShadow: _focused ? const [BoxShadow(color: AppColors.focusRing, spreadRadius: 4)] : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _node,
        autofocus: widget.autofocus,
        textCapitalization: widget.textCapitalization,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        readOnly: widget.readOnly,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        onTap: widget.onTap,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: labelStyle,
          floatingLabelStyle: labelStyle,
          hintText: widget.hint,
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          prefixIcon: widget.icon == null
              ? null
              : Icon(widget.icon, size: 20, color: _focused ? AppColors.primary : AppColors.textSecondary),
          suffixIcon: widget.suffix,
          contentPadding: EdgeInsets.fromLTRB(16, widget.label == null ? 14 : 10, 16, widget.label == null ? 14 : 10),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
