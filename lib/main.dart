# main.dart COMPLET - Nid Poule Tracker

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const NidPouleApp());
}

class NidPouleApp extends StatelessWidget {
  const NidPouleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nid Poule Tracker',
      theme: ThemeData(primarySwatch: Colors.red, useMaterial3: true),
      home: const NidDashboardScreen(),
    );
  }
}

class NidDashboardScreen extends StatefulWidget {
  const NidDashboardScreen({super.key});

  @override
  State<NidDashboardScreen> createState() => _NidDashboardScreenState();
}

class _NidDashboardScreenState extends State<NidDashboardScreen> {
  final _mapController = MapController();
  final _firestore = FirebaseFirestore.instance;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('âŒ Active le GPS')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('âŒ Permission GPS refusÃ©e')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 17);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur GPS: $e')),
        );
      }
    }
  }

  void _onNidSelected(LatLng pos, String id) {
    setState(() => _selectedId = id);
    _mapController.move(pos, 17.5);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ðŸ›£ï¸ Nids de Poule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('nids').orderBy('date', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          return Row(
            children: [
              Expanded(
                flex: 6,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(50.8503, 4.3517),
                    initialZoom: 12,
                    onTap: (tapPosition, point) async {
                      final num = await _reserveNextNumber();
                      if (mounted) {
                        showDialog(
                          context: context,
                          builder: (_) => AddNidDialog(pos: point, autoNum: num),
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      maxZoom: 19,
                      additionalOptions: const {
                        'user-agent': 'NidPouleApp/1.0',
                      },
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
                          child: GestureDetector(
                            onTap: () => _onNidSelected(pos, doc.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                                  Positioned(
                                    bottom: 4,
                                    child: Text(
                                      '${data['num']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
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
              Expanded(
                flex: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Color(0xFFE0E0E0))),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.green.withOpacity(0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text('Nids dÃ©tectÃ©s', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('${docs.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: docs.isEmpty
                            ? const Center(
                                child: Text('Aucun nid\nTape la carte pour signaler', textAlign: TextAlign.center),
                              )
                            : ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final doc = docs[index];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final gp = data['pos'] as GeoPoint;
                                  final pos = LatLng(gp.latitude, gp.longitude);
                                  final isSelected = _selectedId == doc.id;

                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.green.withOpacity(0.2) : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      leading: _thumbnail(data['photoUrl']),
                                      title: Text('Nid #${data['num']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(
                                        data['nid'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () => _onNidSelected(pos, doc.id),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "gps",
            backgroundColor: Colors.blue,
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "home",
            onPressed: () => _mapController.move(LatLng(50.8503, 4.3517), 12),
            child: const Icon(Icons.home),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(String? url) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url != null
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image))
            : const Icon(Icons.image),
      ),
    );
  }
}

class AddNidDialog extends StatefulWidget {
  final LatLng pos;
  final int autoNum;
  const AddNidDialog({super.key, required this.pos, required this.autoNum});

  @override
  State<AddNidDialog> createState() => _AddNidDialogState();
}

class _AddNidDialogState extends State<AddNidDialog> {
  final _controller = TextEditingController();
  Uint8List? _bytes;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_loading && _bytes != null && _controller.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    try {
      setState(() => _error = null);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.bytes != null) {
        setState(() => _bytes = result.files.single.bytes);
      } else {
        setState(() => _error = 'Aucune image');
      }
    } catch (e) {
      setState(() => _error = 'Erreur photo: $e');
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    
    setState(() => _loading = true);
    try {
      final fileName = 'nids/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putData(_bytes!);
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('nids').add({
        'num': widget.autoNum,
        'nid': _controller.text.trim(),
        'photoUrl': photoUrl,
        'pos': GeoPoint(widget.pos.latitude, widget.pos.longitude),
        'date': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erreur: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ðŸš¨ Nid #${widget.autoNum}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description *',
                errorText: _error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _bytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_bytes!, fit: BoxFit.cover),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Appuie pour photo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_camera),
                label: const Text('ðŸ“¸ SÃ©lectionner'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('âŒ Annuler'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: Text(_loading ? 'â³ Envoi...' : 'âœ… Publier'),
        ),
      ],
    );
  }
}
```

## Installation

1. Copie ce code dans `lib/main.dart`
2. `flutter pub get`
3. `flutter run`
4. Push GitHub â†’ Codemagic build APK

## FonctionnalitÃ©s

âœ… Carte OpenStreetMap colorÃ©e  
âœ… GPS localisation  
âœ… Upload photos Firebase Storage  
âœ… Markers cliquables numÃ©rotÃ©s  
âœ… Liste temps rÃ©el Firestore  
âœ… Auto-incrÃ©ment numÃ©ros  
âœ… Permissions Android 14+  

ðŸš€ **PrÃªt pour production !**