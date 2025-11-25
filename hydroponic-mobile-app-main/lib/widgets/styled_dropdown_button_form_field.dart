// lib/widgets/styled_dropdown_button_form_field.dart

import 'package:flutter/material.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class StyledDropdownButtonFormField<T> extends StatelessWidget {
  final String? labelText;
  final String hintText;
  final IconData prefixIcon;
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;

  const StyledDropdownButtonFormField({
    super.key,
    this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.value,
    this.items,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      hint: Text(hintText), 
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        filled: true,
        fillColor: Color.fromARGB(255, 236, 236, 236),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(style: BorderStyle.none),
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(15)),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2.0
          )
        )
      ),
    );
  }
}