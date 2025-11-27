import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/user_model.dart';
import 'package:hydroponics_app/theme/app_colors.dart';

class EmployeeListCard extends StatelessWidget{
  final String role;
  final List<UserModel> userData;
  final void Function(UserModel user)? onEdit;
  final void Function(UserModel user)? onDelete;

  const EmployeeListCard({
    super.key, 
    required this.role, 
    required this.userData,
    this.onEdit,
    this.onDelete,
  }
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5)
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsetsGeometry.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold
              ),
            ),
            Divider(),
            Column(
              children: userData.map((user) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis, // Menambahkan tanda ... jika terlalu panjang
                        maxLines: 1, // Membatasi hanya 1 baris
                      ),
                    ),
                    SizedBox(width: 8,),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => onEdit?.call(user), 
                          icon: Icon(Icons.edit, color: Colors.white,)
                        ),
                        IconButton(
                          onPressed: () => onDelete?.call(user), 
                          icon: Icon(Icons.delete, color: Colors.white,)
                        )
                      ],
                    )
                  ],
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }
}