import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class NoLeadingTextFormField extends StatelessWidget{
  final String hintText;
  final TextInputType inputType;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;

  const NoLeadingTextFormField({
    super.key, 
    required this.hintText, 
    required this.inputType, 
    this.validator,
    this.controller,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      cursorColor: AppColors.primary,
      keyboardType: inputType,
      validator: validator,
      inputFormatters: inputFormatters,
      obscureText: false,
      decoration: InputDecoration(
        hintText: hintText,
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