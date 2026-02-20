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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NidPouleApp());
}

class NidPouleApp extends StatelessWidget {
  const NidPouleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nid Poule Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
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
    if (!await Geolocator.isLocationServiceEnabled()) return;

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
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Active le GPS')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _mapController.move(
        LatLng(position.latitude, position.longitude),
        17,
      );
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
        title: const Text(
          'Nids de Poule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('nids')
            .orderBy('date', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(50.8503, 4.3517),
              initialZoom: 12,
              onTap: (tapPosition, point) async {
                final num = await _reserveNextNumber();
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        AddNidDialog(pos: point, autoNum: num),
                  );
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=d123fd3281734f0f977e15eb84dba100',
                userAgentPackageName: 'com.example.nidpoule',
                maxZoom: 22,
              ),
              MarkerLayer(
                markers: docs.map((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;
                  final gp = data['pos'] as GeoPoint;
                  final pos =
                      LatLng(gp.latitude, gp.longitude);

                  return Marker(
                    point: pos,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () =>
                          _onNidSelected(pos, doc.id),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class AddNidDialog extends StatefulWidget {
  final LatLng pos;
  final int autoNum;

  const AddNidDialog({
    super.key,
    required this.pos,
    required this.autoNum,
  });

  @override
  State<AddNidDialog> createState() => _AddNidDialogState();
}

class _AddNidDialogState extends State<AddNidDialog> {
  final _controller = TextEditingController();
  Uint8List? _bytes;
  bool _loading = false;

  bool get _canSubmit =>
      !_loading &&
      _bytes != null &&
      _controller.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result != null &&
        result.files.single.bytes != null) {
      setState(() => _bytes = result.files.single.bytes);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    setState(() => _loading = true);

    final fileName =
        'nids/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref =
        FirebaseStorage.instance.ref().child(fileName);

    await ref.putData(_bytes!);
    final photoUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('nids').add({
      'num': widget.autoNum,
      'nid': _controller.text.trim(),
      'photoUrl': photoUrl,
      'pos': GeoPoint(
          widget.pos.latitude, widget.pos.longitude),
      'date': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nid #${widget.autoNum}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration:
                const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text('Sélectionner une image'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _canSubmit ? _submit : null,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Publier'),
        ),
      ],
    );
  }
}