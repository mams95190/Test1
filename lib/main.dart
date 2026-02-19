import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(NidPouleApp());
}

class NidPouleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nid Poule Tracker',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: NidDashboardScreen(),
    );
  }
}

class NidDashboardScreen extends StatefulWidget {
  @override
  _NidDashboardScreenState createState() => _NidDashboardScreenState();
}

class _NidDashboardScreenState extends State<NidDashboardScreen> {
  final _mapController = MapController();
  final _firestore = FirebaseFirestore.instance;
  String? _selectedId;

  Future<int> _reserveNextNumber() async {
    final counterRef = _firestore.collection('meta').doc('counter');
    return await _firestore.runTransaction<int>((tx) async {
      final snap = await tx.get(counterRef);
      final current = (snap.data()?['nidCounter'] as int?) ?? 0;
      final next = current + 1;
      tx.set(counterRef, {'nidCounter': next}, SetOptions(merge: true));
      return next;
    });
  }

  void _onNidSelected(LatLng pos, String id) {
    setState(() => _selectedId = id);
    _mapController.move(pos, 17.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🛠️ Nids de Poule Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('nids').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];

          return Row(
            children: [
              // --- CARTE ---
              Expanded(
                flex: 7,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(50.8503, 4.3517),
                    zoom: 13,
                    onTap: (tapPos, latLng) async {
                      final num = await _reserveNextNumber();
                      showDialog(
                        context: context,
                        builder: (_) => AddNidDialog(pos: latLng, autoNum: num),
                      );
                    },
                  ),
                  nonRotatedChildren: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.nidpoule',
                    ),
                    MarkerLayer(
                      markers: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final gp = data['pos'] as GeoPoint;
                        final pos = LatLng(gp.latitude, gp.longitude);
                        final isSelected = _selectedId == doc.id;
                        final color = isSelected ? Colors.green : Colors.red;

                        return Marker(
                          point: pos,
                          width: 48,
                          height: 48,
                          builder: (ctx) => GestureDetector(
                            onTap: () => _onNidSelected(pos, doc.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.circle, color: Colors.white, size: 20),
                                  Positioned(
                                    bottom: 8,
                                    child: Text(
                                      '${data['num']}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                              color: Colors.black54,
                                              offset: Offset(1, 1),
                                              blurRadius: 2)
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // --- LISTE SIDEBAR ---
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final gp = data['pos'] as GeoPoint;
                      final pos = LatLng(gp.latitude, gp.longitude);
                      final isSelected = _selectedId == doc.id;

                      return Container(
                        color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
                        child: ListTile(
                          selected: isSelected,
                          leading: _thumbnail(data['photoUrl']),
                          title: Text('Nid #${data['num']}', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(data['nid'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _onNidSelected(pos, doc.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumbnail(String? url) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade200),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url != null ? Image.network(url, fit: BoxFit.cover) : Icon(Icons.image),
      ),
    );
  }
}

// --- AddNidDialog corrigé ---
class AddNidDialog extends StatefulWidget {
  final LatLng pos;
  final int autoNum;
  AddNidDialog({required this.pos, required this.autoNum});

  @override
  _AddNidDialogState createState() => _AddNidDialogState();
}

class _AddNidDialogState extends State<AddNidDialog> {
  final _controller = TextEditingController();
  Uint8List? _bytes;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('🚨 Nouveau Nid #${widget.autoNum}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(labelText: 'Remarque / État'),
          ),
          SizedBox(height: 15),
          if (_bytes != null)
            Image.memory(_bytes!, height: 100)
          else
            Text("Aucune image sélectionnée"),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final res = await FilePicker.platform.pickFiles(type: FileType.image);
                if (res != null && res.files.single.bytes != null) {
                  setState(() => _bytes = res.files.single.bytes);
                  print("Bytes length: ${_bytes!.length}");
                } else {
                  print("Aucun fichier ou fichier vide");
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text("Aucun fichier ou fichier vide")));
                }
              } catch (e) {
                print("Erreur file picker: $e");
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text("Erreur file picker: $e")));
              }
            },
            icon: Icon(Icons.camera_alt),
            label: Text('Prendre Photo'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
        ElevatedButton(
          onPressed: _loading
              ? null
              : () async {
                  if (_bytes == null || _controller.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Remplis le texte et choisis une image !")),
                    );
                    return;
                  }

                  setState(() => _loading = true);

                  try {
                    final ref = FirebaseStorage.instance
                        .ref()
                        .child('nids/${DateTime.now().millisecondsSinceEpoch}.jpg');

                    await ref.putData(_bytes!);
                    final url = await ref.getDownloadURL();
                    print("Upload réussi, url: $url");

                    await FirebaseFirestore.instance.collection('nids').add({
                      'num': widget.autoNum,
                      'nid': _controller.text,
                      'photoUrl': url,
                      'pos': GeoPoint(widget.pos.latitude, widget.pos.longitude),
                      'date': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                  } catch (e) {
                    print("Erreur upload: $e");
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Erreur upload: $e")));
                    setState(() => _loading = false);
                  }
                },
          child: Text(_loading ? 'Envoi...' : 'Valider'),
        ),
      ],
    );
  }
}

