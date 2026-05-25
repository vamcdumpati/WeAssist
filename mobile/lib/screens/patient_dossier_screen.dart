import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../models/hospital_visit.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class PatientDossierScreen extends StatefulWidget {
  const PatientDossierScreen({super.key});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> {
  final _searchController = TextEditingController();
  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  List<HospitalVisit> _allVisits = [];
  bool _isLoading = true;

  // Selected Patient for Dossier Modal
  Patient? _selectedPatient;

  // Quick Trip Booking Fields
  final _quickHospitalName = TextEditingController();
  final _quickHospitalArea = TextEditingController();
  final _quickEmergencyContact = TextEditingController();
  bool _isBookingFormVisible = false;
  bool _fetchingLocation = false;
  double? _caretakerLat;
  double? _caretakerLng;

  // Active Trip Transit Overlay
  bool _transitActive = false;
  HospitalVisit? _activeVisit;
  Patient? _activePatientTransit;

  @override
  void initState() {
    super.initState();
    _fetchDirectoryData();
    _searchController.addListener(_filterDirectory);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickHospitalName.dispose();
    _quickHospitalArea.dispose();
    _quickEmergencyContact.dispose();
    super.dispose();
  }

  Future<void> _fetchDirectoryData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final patients = await FirebaseService.getPatients();
      final visits = await FirebaseService.getAllVisits();
      setState(() {
        _allPatients = patients;
        _filteredPatients = patients;
        _allVisits = visits;
        _isLoading = false;
      });
    } catch (e) {
      FirebaseService.addLog("Error reading directory data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterDirectory() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredPatients = _allPatients;
      } else {
        _filteredPatients = _allPatients.where((p) {
          return p.name.toLowerCase().contains(query) ||
              p.mobile.contains(query) ||
              p.emergencyContact.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchQuickGPS() async {
    setState(() {
      _fetchingLocation = true;
    });
    FirebaseService.addLog("Dossier: Querying caretaker GPS coordinates...");
    
    Position? pos = await LocationService.getCurrentLocation();
    if (pos == null) {
      pos = LocationService.getMockPosition();
      FirebaseService.addLog("Dossier Geolocator fail. Fallback mock GPS loaded.");
    } else {
      FirebaseService.addLog("Dossier GPS lock acquired.");
    }

    setState(() {
      _caretakerLat = pos!.latitude;
      _caretakerLng = pos.longitude;
      _fetchingLocation = false;
    });
  }

  Future<void> _sendLiveLocationSMS(String number, String role, String mapUrl) async {
    final message = "WeAssist Alert: Caretaker has started transit with ${_selectedPatient!.name} to ${_quickHospitalName.text.trim()}. Track live caretaker maps coordinates here: $mapUrl";
    
    FirebaseService.addLog("[SMS SIMULATOR] Dispatching SMS alert notification to $role Mobile [$number]: \"$message\"");

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{
        'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        FirebaseService.addLog("SMS application scheme failed to execute natively.");
      }
    } catch (e) {
      FirebaseService.addLog("SMS launch exception: $e");
    }
  }

  void _submitQuickTransit() async {
    if (_quickHospitalName.text.trim().isEmpty || _quickHospitalArea.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hospital details are required to proceed.")),
      );
      return;
    }

    if (_caretakerLat == null || _caretakerLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("GPS coordinates must be captured before starting transit.")),
      );
      return;
    }

    final emergencyContact = _quickEmergencyContact.text.trim().isEmpty
        ? _selectedPatient!.emergencyContact
        : _quickEmergencyContact.text.trim();

    try {
      FirebaseService.addLog("Dossier: Initiating quick visit schedule...");

      final draftVisit = HospitalVisit(
        id: '',
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        hospitalName: _quickHospitalName.text.trim(),
        hospitalArea: _quickHospitalArea.text.trim(),
        caretakerLat: _caretakerLat!,
        caretakerLng: _caretakerLng!,
        emergencyContact: emergencyContact,
        patientMobile: _selectedPatient!.mobile,
        status: 'transit',
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
      );

      final createdVisit = await FirebaseService.createVisit(draftVisit);

      // Trigger SMS notifications
      final mapUrl = "https://www.google.com/maps?q=$_caretakerLat,$_caretakerLng";
      await _sendLiveLocationSMS(_selectedPatient!.mobile, "Patient", mapUrl);
      await _sendLiveLocationSMS(emergencyContact, "Emergency Contact", mapUrl);

      setState(() {
        _activePatientTransit = _selectedPatient;
        _activeVisit = createdVisit;
        _transitActive = true;
        _selectedPatient = null; // Close dialog
        _isBookingFormVisible = false;
        _caretakerLat = null;
        _caretakerLng = null;
        _quickHospitalName.clear();
        _quickHospitalArea.clear();
        _quickEmergencyContact.clear();
      });

      _fetchDirectoryData(); // Refresh list/history in background

    } catch (e) {
      FirebaseService.addLog("Quick trip booking exception: $e");
    }
  }

  void _completeTransitTrip() async {
    if (_activeVisit == null) return;
    try {
      await FirebaseService.updateVisitStatus(_activeVisit!.id, 'completed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Drop-off confirmed. Transit completed successfully!"),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      setState(() {
        _transitActive = false;
        _activeVisit = null;
        _activePatientTransit = null;
      });
      _fetchDirectoryData();
    } catch (e) {
      FirebaseService.addLog("Dossier transit drop-off exception: $e");
    }
  }

  Widget _buildPatientAvatar(String path) {
    if (path.isEmpty) {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.primaryBlue,
        child: Icon(Icons.person, color: Colors.white),
      );
    }

    final isMock = path.startsWith('mock_');
    if (isMock) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppTheme.secondaryCyan.withOpacity(0.2),
        child: const Icon(Icons.face, color: AppTheme.secondaryCyan),
      );
    }

    try {
      return CircleAvatar(
        radius: 24,
        backgroundImage: FileImage(File(path)),
      );
    } catch (e) {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_transitActive) {
      return _buildActiveTransitUI();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Patients Directory"),
        backgroundColor: AppTheme.darkBackground,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: "Search Patient Profile...",
                  hintText: "Enter name or contact number",
                  prefixIcon: const Icon(Icons.search, color: AppTheme.primaryBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Directory list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredPatients.isEmpty
                        ? const Center(
                            child: Text(
                              "No patient profiles match the query.",
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredPatients.length,
                            itemBuilder: (context, index) {
                              final p = _filteredPatients[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: _buildPatientAvatar(p.photoUrl),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    "${p.gender} • ${p.age} years old\nMob: ${p.mobile}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.assignment_ind_outlined, color: AppTheme.secondaryCyan),
                                  onTap: () {
                                    setState(() {
                                      _selectedPatient = p;
                                      _isBookingFormVisible = false;
                                    });
                                    _showDossierModal();
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDossierModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final patient = _selectedPatient!;
            final patientVisits = _allVisits.where((v) => v.patientId == patient.id).toList();

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle line indicator
                    Center(
                      child: Container(
                        width: 50,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderCol,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      "Patient Dossier & History",
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Profile Summary Row
                    Row(
                      children: [
                        _buildPatientAvatar(patient.photoUrl),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patient.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("DOB: ${patient.dob.toIso8601String().split('T')[0]} (${patient.age}y)",
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppTheme.borderCol),

                    // General metrics
                    Row(
                      children: [
                        Expanded(child: _buildMetricTile("Height", "${patient.height} cm")),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricTile("Weight", "${patient.weight} kg")),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricTile("Gender", patient.gender)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildDetailRow("Mobile Number", patient.mobile),
                    _buildDetailRow("Emergency Contact", patient.emergencyContact),

                    const Divider(height: 24, color: AppTheme.borderCol),

                    // Quick Trip Booker Button / Form Toggle
                    if (!_isBookingFormVisible) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_road),
                        label: const Text("Schedule New Visit"),
                        onPressed: () {
                          setModalState(() {
                            _isBookingFormVisible = true;
                          });
                        },
                      ),
                    ] else ...[
                      // Quick Trip Booking Form
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderCol),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "Schedule Transit Info",
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _quickHospitalName,
                              decoration: const InputDecoration(
                                labelText: "Hospital Name",
                                prefixIcon: Icon(Icons.local_hospital),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _quickHospitalArea,
                              decoration: const InputDecoration(
                                labelText: "Area / Address",
                                prefixIcon: Icon(Icons.place),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _quickEmergencyContact,
                              decoration: InputDecoration(
                                labelText: "Emergency Contact",
                                hintText: patient.emergencyContact,
                                prefixIcon: const Icon(Icons.phone),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Location coordinate picker
                            Row(
                              children: [
                                _fetchingLocation
                                    ? const CircularProgressIndicator()
                                    : IconButton(
                                        icon: const Icon(Icons.gps_fixed, color: AppTheme.secondaryCyan),
                                        onPressed: () async {
                                          await _fetchQuickGPS();
                                          setModalState(() {});
                                        },
                                      ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Caretaker GPS Location", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(
                                        _caretakerLat == null
                                            ? "Coordinates: missing"
                                            : "Lat: ${_caretakerLat!.toStringAsFixed(5)}, Lng: ${_caretakerLng!.toStringAsFixed(5)}",
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_caretakerLat == null)
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _fetchQuickGPS();
                                      setModalState(() {});
                                    },
                                    child: const Text("Capture", style: TextStyle(fontSize: 12)),
                                  )
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setModalState(() {
                                        _isBookingFormVisible = false;
                                      });
                                    },
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _submitQuickTransit();
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                                    child: const Text("Start Transit"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    // History logs
                    const Text(
                      "Hospital Transit History Logs",
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryCyan),
                    ),
                    const SizedBox(height: 8),
                    patientVisits.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "No past transits found for this patient.",
                              style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: patientVisits.length,
                            itemBuilder: (context, idx) {
                              final v = patientVisits[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderCol, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(v.hospitalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(
                                            "Scheduled: ${v.createdAt.toLocal().toString().split(' ')[0]}",
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: v.status == 'completed'
                                            ? AppTheme.emeraldGreen.withOpacity(0.15)
                                            : Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        v.status.toUpperCase(),
                                        style: TextStyle(
                                          color: v.status == 'completed' ? AppTheme.emeraldGreen : Colors.orangeAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      setState(() {
        _selectedPatient = null;
        _isBookingFormVisible = false;
      });
    });
  }

  Widget _buildMetricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderCol, width: 0.5),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildActiveTransitUI() {
    final patient = _activePatientTransit!;
    final visit = _activeVisit!;
    final mapUrl = "https://www.google.com/maps?q=${visit.caretakerLat},${visit.caretakerLng}";

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.15),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange.withOpacity(0.25),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Colors.orangeAccent,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Trip Transit Dispatch Active",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                "Live locations dispatched to contacts.",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppTheme.primaryBlue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Patient: ${patient.name} (${patient.gender}, ${patient.age}y)",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppTheme.borderCol),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.local_hospital, color: AppTheme.secondaryCyan),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visit.hospitalName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  visit.hospitalArea,
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppTheme.borderCol),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.secondaryCyan),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Locked GPS Coordinates", style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                Text("Lat: ${visit.caretakerLat}, Lng: ${visit.caretakerLng}", style: const TextStyle(fontFamily: 'Courier', fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.map_rounded, color: AppTheme.primaryBlue),
                            onPressed: () async {
                              final Uri mapsUri = Uri.parse(mapUrl);
                              if (await canLaunchUrl(mapsUri)) {
                                await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                "Trigger Manual SMS Alerts",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.message, color: Colors.blueAccent, size: 18),
                      label: const Text("SMS Patient", style: TextStyle(fontSize: 13)),
                      onPressed: () => _sendLiveLocationSMS(visit.patientMobile, "Patient", mapUrl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.message, color: AppTheme.errorRed, size: 18),
                      label: const Text("SMS Emergency", style: TextStyle(fontSize: 13)),
                      onPressed: () => _sendLiveLocationSMS(visit.emergencyContact, "Emergency Contact", mapUrl),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _completeTransitTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emeraldGreen,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded),
                    SizedBox(width: 10),
                    Text("Confirm Hospital Drop-off"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
