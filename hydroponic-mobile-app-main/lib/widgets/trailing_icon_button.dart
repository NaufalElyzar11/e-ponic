import 'package:flutter/material.dart';

class TrailingIconButton extends StatelessWidget{
  final String text;
  final IconData trailingIcon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const TrailingIconButton({
    super.key, 
    required this.text, 
    required this.trailingIcon,
    required this.onPressed,
    this.foregroundColor = Colors.black, 
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
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor
        ), 
        child: Padding(
          padding: EdgeInsetsGeometry.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold
                ),
              ),
              Icon(trailingIcon, size: 25,),
            ],
          ),
        ),
      ),
    );
  }
}