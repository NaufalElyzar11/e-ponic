import 'package:flutter/material.dart';
// import 'package:intl/intl.dart'; // Hapus atau comment baris ini jika tidak dipakai di file ini

class PlantHarvestHistoryExpansion extends StatelessWidget {
  final String date; // Ini menerima String yang SUDAH diformat dari parent
  final int seladaPlantQty;
  final int seladaHarvestQty;
  final int pakcoyPlantQty;
  final int pakcoyHarvestQty;
  final int kangkungPlantQty;
  final int kangkungHarvestQty;
  final double screenWidth;

  const PlantHarvestHistoryExpansion({
    super.key, 
    required this.date,
    required this.seladaPlantQty, 
    required this.seladaHarvestQty, 
    required this.pakcoyPlantQty, 
    required this.pakcoyHarvestQty, 
    required this.kangkungPlantQty, 
    required this.kangkungHarvestQty,
    required this.screenWidth
  });
  
  @override
  Widget build(BuildContext context) {
    // HAPUS BARIS INI:
    // final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      clipBehavior: Clip.antiAlias,
      color: const Color.fromARGB(255, 226, 226, 226),
      
      child: ExpansionTile(
        initiallyExpanded: false,
        backgroundColor: const Color.fromARGB(255, 226, 226, 226),
        childrenPadding: const EdgeInsets.only(bottom: 15, right: 15, left: 15),
        
        // Gunakan 'date' langsung karena sudah berisi string "19 November 2025"
        title: Text(
          date, 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: screenWidth - 150),
              child: DataTable(
                border: TableBorder.all(color: Colors.transparent),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold,),
                columns: const [
                  DataColumn(label: Text('Jenis Tanaman')),
                  DataColumn(label: Text('Jumlah Tanam'), headingRowAlignment: MainAxisAlignment.center),
                  DataColumn(label: Text('Jumlah Panen'), headingRowAlignment: MainAxisAlignment.center),
                ],
                rows: [
                  DataRow(cells: [
                    const DataCell(Text('Selada')),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$seladaPlantQty', textAlign: TextAlign.center,)
                      ]
                    )),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$seladaHarvestQty', textAlign: TextAlign.center,)
                      ]
                    )),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('Pakcoy')),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$pakcoyPlantQty', textAlign: TextAlign.center,)
                      ]
                    )),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$pakcoyHarvestQty', textAlign: TextAlign.center,)
                      ]
                    )),
                  ]),
                  DataRow(cells: [
                    const DataCell(Text('Kangkung')),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$kangkungPlantQty', textAlign: TextAlign.center,)
                      ]
                    )),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$kangkungHarvestQty', textAlign: TextAlign.center,)
                      ]
                    )),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}