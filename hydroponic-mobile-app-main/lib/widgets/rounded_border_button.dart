import 'package:flutter/material.dart';

class RoundedBorderButton extends StatelessWidget{
  final String text;
  final Color textColor;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const RoundedBorderButton({
    super.key, 
    required this.text, 
    required this.onPressed,
    this.textColor = Colors.black, 
    this.backgroundColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15)
          ),
          foregroundColor: textColor,
          backgroundColor: backgroundColor
        ), 
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 20),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}