import 'package:flutter/material.dart';
import 'package:hydroponics_app/models/plant_history_model.dart';
import 'package:hydroponics_app/widgets/styled_elevated_button.dart';

class FarmerHistoryExpansionItem extends StatelessWidget {
  final PlantHistoryModel history;
  final double screenWidth;

  const FarmerHistoryExpansionItem({
    super.key, 
    required this.history,
    required this.screenWidth
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
        // 'margin' adalah jarak fisik antar elemen
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        // 'clipBehavior' agar rapi
        clipBehavior: Clip.antiAlias,
        color: const Color.fromARGB(255, 226, 226, 226),
        
        child: ExpansionTile(
          initiallyExpanded: false, // true berarti expand duluan
          backgroundColor: Color.fromARGB(255, 1, 68, 33),
          childrenPadding: EdgeInsets.only(bottom: 15, right: 15, left: 15),
          textColor: Colors.white,
          iconColor: Colors.white,
          title: Text(history.date, style: TextStyle(fontWeight: FontWeight.bold),),
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: screenWidth - 150),
                child: DataTable(
                  border: TableBorder.all(color: Colors.transparent),
                  headingTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,),
                  dataTextStyle: TextStyle(color: Colors.white),
                  columns: [
                    DataColumn(label: Text('Informasi')),
                    DataColumn(label: Text('Jumlah'), headingRowAlignment: MainAxisAlignment.center),
                    DataColumn(label: Text('Menu'), headingRowAlignment: MainAxisAlignment.center),
                  ],
                  rows: [
                    DataRow(cells: [
                      DataCell(Text('Bibit yang ditanam')),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${history.plantQty}', textAlign: TextAlign.center,)
                        ]
                      )),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: history.onPlantEdit, 
                            icon: Icon(Icons.edit, color: Colors.white,)
                          ),
                          SizedBox(width: 10,),
                          IconButton(
                            onPressed: history.onPlantDelete, 
                            icon: Icon(Icons.delete, color: Colors.white,)
                          ),
                      ],)),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('Tanaman yang dipanen')),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${history.harvestQty}', textAlign: TextAlign.center,)
                        ]
                      )),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: history.onHarvestEdit, 
                            icon: Icon(Icons.edit, color: Colors.white,)
                          ),
                          SizedBox(width: 10,),
                          IconButton(
                            onPressed: history.onHarvestDelete, 
                            icon: Icon(Icons.delete, color: Colors.white,)
                          ),
                      ],)),
                    ]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 15,),
            StyledElevatedButton(
              text: 'Hapus Data', 
              onPressed: history.onDeleteAll,
              foregroundColor: Colors.white,
              backgroundColor: Colors.red[500],
            ),
          ],
        ),
      );
  }}