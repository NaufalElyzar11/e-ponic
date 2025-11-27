import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FarmerTotalPlantCard extends StatelessWidget {
  final String header;
  final int plantCount;
  final IconData? plantIcon;

  const FarmerTotalPlantCard({
    super.key,
    required this.header,
    required this.plantCount,
    this.plantIcon,
  });

  /// Format angka dengan pemisah ribuan dan sesuaikan ukuran font
  String _formatNumber(int number) {
    // Format dengan pemisah ribuan (1,000,000)
    return NumberFormat('#,###').format(number);
  }

  /// Tentukan ukuran font berdasarkan panjang angka
  double _getFontSize(int number) {
    final formatted = _formatNumber(number);
    final length = formatted.length;
    
    // Sesuaikan ukuran font berdasarkan panjang angka
    if (length <= 6) return 40;      // 999,999 atau kurang
    if (length <= 8) return 32;      // 9,999,999 atau kurang
    if (length <= 10) return 26;     // 99,999,999 atau kurang
    return 22;                       // Lebih dari 100 juta
  }

  @override
  Widget build(BuildContext context) {
    final formattedNumber = _formatNumber(plantCount);
    final fontSize = _getFontSize(plantCount);
    
    return Card(
      elevation: 7,
      child: Container(
        alignment: Alignment.topLeft,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),  
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header, 
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            formattedNumber, 
                            style: TextStyle(
                              fontSize: fontSize, 
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text('bibit', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                plantIcon ?? Icons.grass, 
                size: 60, 
                color: const Color.fromARGB(255, 1, 68, 33),
              ),
            ],
          ),
        ),
      ),
    );
  }
}