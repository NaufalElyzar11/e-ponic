import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/user_model.dart';

class HomeAppBar extends StatelessWidget{
  final UserModel user;

  const HomeAppBar({
    super.key, 
    required this.user 
  });
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: const Color.fromARGB(255, 1, 68, 33),
      foregroundColor: Colors.white,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.username,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(user.role, style: TextStyle(fontSize: 14)),
        ],
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 10.0),
        child: Container(
          margin: const EdgeInsets.all(10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.account_circle,
            color: Colors.white,
            size: 35,
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(
            right: 20.0,
            top: 15.0,
            bottom: 15.0,
          ),
          child: InkWell(
            onTap: user.onNotificationTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.all(0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
              child: const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}