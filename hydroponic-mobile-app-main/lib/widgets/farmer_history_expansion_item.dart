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
    // Cek keberadaan data berdasarkan jumlah dokumen, bukan jumlah bibit
    final bool hasPlantData = history.plantDocCount > 0;
    final bool hasHarvestData = history.harvestDocCount > 0;

    return Card(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        clipBehavior: Clip.antiAlias,
        color: const Color.fromARGB(255, 226, 226, 226),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: const Color.fromARGB(255, 1, 68, 33),
          childrenPadding: const EdgeInsets.only(bottom: 15, right: 15, left: 15),
          textColor: Colors.white,
          iconColor: Colors.white,
          title: Text(history.date, style: const TextStyle(fontWeight: FontWeight.bold),),
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: screenWidth - 150),
                child: DataTable(
                  border: TableBorder.all(color: Colors.transparent),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold,),
                  dataTextStyle: const TextStyle(color: Colors.white),
                  columns: const [
                    DataColumn(label: Text('Informasi')),
                    DataColumn(label: Text('Jumlah'), headingRowAlignment: MainAxisAlignment.center),
                  ],
                  rows: [
                    DataRow(cells: [
                      const DataCell(Text('Bibit yang ditanam')),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${history.plantQty}', textAlign: TextAlign.center,)
                        ],
                      )),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text('Tanaman yang dipanen')),
                      DataCell(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${history.harvestQty}', textAlign: TextAlign.center,)
                        ],
                      )),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15,),
            
            // --- TOMBOL EDIT ---
            if (hasPlantData || hasHarvestData)
              StyledElevatedButton(
                text: 'Edit Data ',
                onPressed: () {
                  // Jika keduanya ada, tanya mau edit yang mana
                  if (hasPlantData && hasHarvestData) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Pilih Data yang Akan Diedit'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.eco),
                              title: const Text('Edit Data Tanam'),
                              subtitle: Text('${history.plantDocCount} data'),
                              onTap: () {
                                Navigator.pop(ctx);
                                history.onPlantEdit();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.agriculture),
                              title: const Text('Edit Data Panen'),
                              subtitle: Text('${history.harvestDocCount} data'),
                              onTap: () {
                                Navigator.pop(ctx);
                                history.onHarvestEdit();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (hasPlantData) {
                    history.onPlantEdit();
                  } else if (hasHarvestData) {
                    history.onHarvestEdit();
                  }
                },
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue[700],
                icon: Icons.edit,
              ),
            
            const SizedBox(height: 10,),
            
            // --- TOMBOL HAPUS ---
            if (hasPlantData || hasHarvestData)
              StyledElevatedButton(
                text: 'Hapus Data', 
                onPressed: () {
                  // Logika percabangan untuk Hapus
                  if (hasPlantData && hasHarvestData) {
                    // Jika ada Tanam DAN Panen -> Tampilkan Dialog Pilihan
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Pilih Data yang Akan Dihapus'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.eco, color: Colors.red),
                              title: const Text('Hapus Data Tanam'),
                              subtitle: Text('${history.plantDocCount} data'),
                              onTap: () {
                                Navigator.pop(ctx);
                                history.onDeletePlant();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.agriculture, color: Colors.red),
                              title: const Text('Hapus Data Panen'),
                              subtitle: Text('${history.harvestDocCount} data'),
                              onTap: () {
                                Navigator.pop(ctx);
                                history.onDeleteHarvest();
                              },
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.delete_forever, color: Colors.red),
                              title: const Text('Hapus Semua'),
                              onTap: () {
                                Navigator.pop(ctx);
                                history.onDeleteAll();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (hasPlantData) {
                    // Hanya ada Data Tanam -> Jalankan logic hapus tanam (bisa single/multi confirm)
                    history.onDeletePlant();
                  } else if (hasHarvestData) {
                    // Hanya ada Data Panen -> Jalankan logic hapus panen
                    history.onDeleteHarvest();
                  }
                },
                foregroundColor: Colors.white,
                backgroundColor: Colors.red[500],
                icon: Icons.delete,
              ),
          ],
        ),
      );
  }
}