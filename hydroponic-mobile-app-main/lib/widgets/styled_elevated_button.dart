import 'package:flutter/material.dart';

class StyledElevatedButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final double borderWidth;
  final Color borderColor;

  const StyledElevatedButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.borderWidth = 0,
    this.borderColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(
              color: borderColor,
              width: borderWidth
            )
          ),
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          elevation: 3.0
        ),
        onPressed: onPressed,
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (icon != null) ...[
                Icon(icon),
              ],
            ],
          ),
        ),
      ),
    );
  }
}