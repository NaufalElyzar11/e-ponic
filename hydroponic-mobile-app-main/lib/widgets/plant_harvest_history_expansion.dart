import 'package:flutter/material.dart';

class PlantHarvestHistoryExpansion extends StatelessWidget{
  final String date;
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      clipBehavior: Clip.antiAlias,
      color: const Color.fromARGB(255, 226, 226, 226),
      
      child: ExpansionTile(
        initiallyExpanded: false, // true berarti expand duluan
        backgroundColor: Color.fromARGB(255, 226, 226, 226),
        childrenPadding: EdgeInsets.only(bottom: 15, right: 15, left: 15),
        title: Text(date, style: TextStyle(fontWeight: FontWeight.bold),),
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: screenWidth - 150),
              child: DataTable(
                border: TableBorder.all(color: Colors.transparent),
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold,),
                columns: [
                  DataColumn(label: Text('Jenis Tanaman')),
                  DataColumn(label: Text('Jumlah Tanam'), headingRowAlignment: MainAxisAlignment.center),
                  DataColumn(label: Text('Jumlah Panen'), headingRowAlignment: MainAxisAlignment.center),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Text('Selada')),
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
                    DataCell(Text('Pakcoy')),
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
                    DataCell(Text('Kangkung')),
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