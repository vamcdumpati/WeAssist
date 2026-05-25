import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../models/hospital_visit.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class PatientIntakeScreen extends StatefulWidget {
  const PatientIntakeScreen({super.key});

  @override
  State<PatientIntakeScreen> createState() => _PatientIntakeScreenState();
}

class _PatientIntakeScreenState extends State<PatientIntakeScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Fields Controllers
  final _nameController = TextEditingController();
  final _patientMobileController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _hospitalAreaController = TextEditingController();
  final _emergencyController = TextEditingController();

  DateTime? _dob;
  int? _age;
  String _gender = 'Male';
  String? _portraitPath;
  String? _identityPath;

  // Location details
  double? _latitude;
  double? _longitude;
  bool _fetchingLocation = false;

  // Active Trip State
  bool _inTransit = false;
  HospitalVisit? _activeVisit;
  Patient? _activePatient;

  @override
  void dispose() {
    _nameController.dispose();
    _patientMobileController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _hospitalNameController.dispose();
    _hospitalAreaController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 40)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        // Age calculation
        final now = DateTime.now();
        int age = now.year - picked.year;
        if (now.month < picked.month || (now.month == picked.month && now.day < picked.day)) {
          age--;
        }
        _age = age;
      });
      FirebaseService.addLog("Intake Date of Birth selected: ${picked.toIso8601String().split('T')[0]} (Age: $_age)");
    }
  }

  Future<void> _capturePhoto(bool isPortrait) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (file != null) {
        setState(() {
          if (isPortrait) {
            _portraitPath = file.path;
          } else {
            _identityPath = file.path;
          }
        });
        FirebaseService.addLog("Intake: Captured ${isPortrait ? 'portrait' : 'identity'} photo: ${file.path}");
      }
    } catch (e) {
      FirebaseService.addLog("Camera source not available (simulator). Mock image asset generated instead.");
      setState(() {
        if (isPortrait) {
          _portraitPath = 'mock_portrait_pic';
        } else {
          _identityPath = 'mock_identity_pic';
        }
      });
    }
  }

  Future<void> _fetchGPSCoordinates() async {
    setState(() {
      _fetchingLocation = true;
    });
    FirebaseService.addLog("Initiating caretakers GPS geolocation coordinates lock...");
    
    Position? pos = await LocationService.getCurrentLocation();
    
    if (pos == null) {
      // Fallback
      pos = LocationService.getMockPosition();
      FirebaseService.addLog("Geolocator query failed/denied. Fallback mock GPS assigned.");
    } else {
      FirebaseService.addLog("GPS coordinates locked successfully.");
    }

    setState(() {
      _latitude = pos!.latitude;
      _longitude = pos.longitude;
      _fetchingLocation = false;
    });

    FirebaseService.addLog("Location captured: Lat $_latitude, Lng $_longitude");
  }

  Future<void> _sendLiveLocationSMS(String number, String role, String mapUrl) async {
    final message = "WeAssist Alert: Caretaker has started transit with ${_nameController.text.trim()} to ${_hospitalNameController.text.trim()}. Track live caretaker maps coordinates here: $mapUrl";
    
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
        FirebaseService.addLog("Native SMS application unavailable. Checked configuration scheme.");
      }
    } catch (e) {
      FirebaseService.addLog("SMS dispatch failed natively: $e");
    }
  }

  void _startHospitalTransit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Date of Birth is required to calculate patient age.")),
      );
      return;
    }

    if (_portraitPath == null || _identityPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload both Portrait and Identity photos.")),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Caretaker GPS location details must be captured first.")),
      );
      return;
    }

    try {
      FirebaseService.addLog("Intake details valid. Commencing patient registration...");

      // 1. Save Patient
      final draftPatient = Patient(
        id: '',
        name: _nameController.text.trim(),
        dob: _dob!,
        gender: _gender,
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
        photoUrl: _portraitPath!,
        identityProofUrl: _identityPath!,
        mobile: "+91${_patientMobileController.text.trim()}",
        emergencyContact: "+91${_emergencyController.text.trim()}",
        createdAt: DateTime.now(),
      );

      final registeredPatient = await FirebaseService.registerPatient(draftPatient);

      // 2. Create Visit
      final draftVisit = HospitalVisit(
        id: '',
        patientId: registeredPatient.id,
        patientName: registeredPatient.name,
        hospitalName: _hospitalNameController.text.trim(),
        hospitalArea: _hospitalAreaController.text.trim(),
        caretakerLat: _latitude!,
        caretakerLng: _longitude!,
        emergencyContact: registeredPatient.emergencyContact,
        patientMobile: registeredPatient.mobile,
        status: 'transit', // Direct to transit
        createdAt: DateTime.now(),
        startedAt: DateTime.now(),
      );

      final createdVisit = await FirebaseService.createVisit(draftVisit);

      setState(() {
        _activePatient = registeredPatient;
        _activeVisit = createdVisit;
        _inTransit = true;
      });

      // 3. Dispatch Live coordinates SMS triggers
      final mapUrl = "https://www.google.com/maps?q=$_latitude,$_longitude";
      
      // Send to Patient
      await _sendLiveLocationSMS(registeredPatient.mobile, "Patient", mapUrl);
      // Send to Emergency Contact
      await _sendLiveLocationSMS(registeredPatient.emergencyContact, "Emergency", mapUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Transit trip successfully started for ${registeredPatient.name}! SMS alerts dispatched."),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
    } catch (e) {
      FirebaseService.addLog("Registration and trip initialization failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: AppTheme.errorRed),
      );
    }
  }

  void _completeDropOff() async {
    if (_activeVisit == null) return;
    
    FirebaseService.addLog("Terminating transit. Completing patient drop-off at hospital destination...");
    
    try {
      await FirebaseService.updateVisitStatus(_activeVisit!.id, 'completed');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Patient successfully dropped off. Transit completed!"),
          backgroundColor: AppTheme.emeraldGreen,
        ),
      );
      
      Navigator.pop(context); // Return back to dashboard
    } catch (e) {
      FirebaseService.addLog("Drop-off completion transaction failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inTransit) {
      return _buildTransitTrackerUI();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      appBar: AppBar(
        title: const Text("We Assist Intake"),
        backgroundColor: AppTheme.darkBackground,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // STEP 1: Personal Details
                _buildSectionHeader("1. Patient Personal Details"),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _nameController,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Patient Full Name",
                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryBlue),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Name is required";
                    if (val.trim().length < 2) return "Name must be at least 2 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderCol, width: 1),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cake, color: AppTheme.primaryBlue, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                _dob == null
                                    ? "Select DOB"
                                    : _dob!.toIso8601String().split('T')[0],
                                style: TextStyle(
                                  color: _dob == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderCol, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          _age == null ? "Age: -" : "Age: $_age",
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Gender selector
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    prefixIcon: Icon(Icons.people, color: AppTheme.primaryBlue),
                  ),
                  items: ['Male', 'Female', 'Other'].map((g) {
                    return DropdownMenuItem<String>(value: g, child: Text(g));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _gender = val!;
                    });
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _patientMobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Patient Mobile Number",
                    hintText: "10-digit mobile number",
                    prefixText: "+91 ",
                    prefixStyle: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    prefixIcon: Icon(Icons.phone, color: AppTheme.primaryBlue),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Mobile number is required";
                    final cleaned = val.trim();
                    if (cleaned.length != 10) {
                      return "Mobile number must be exactly 10 digits";
                    }
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
                      return "Please enter a valid Indian mobile number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: "Height (cm)",
                          prefixIcon: Icon(Icons.height, color: AppTheme.primaryBlue),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: "Weight (kg)",
                          prefixIcon: Icon(Icons.monitor_weight_outlined, color: AppTheme.primaryBlue),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid";
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // STEP 2: Cameras Upload
                _buildSectionHeader("2. Document Capture & Photos"),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildCameraCaptureBox(
                        title: "Identity Card",
                        icon: Icons.badge_outlined,
                        filePath: _identityPath,
                        onTap: () => _capturePhoto(false),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCameraCaptureBox(
                        title: "Portrait Photo",
                        icon: Icons.camera_alt_outlined,
                        filePath: _portraitPath,
                        onTap: () => _capturePhoto(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // STEP 3: Hospital details
                _buildSectionHeader("3. Hospital & Destination Info"),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _hospitalNameController,
                  decoration: const InputDecoration(
                    labelText: "Hospital Name",
                    prefixIcon: Icon(Icons.local_hospital, color: AppTheme.secondaryCyan),
                  ),
                  validator: (val) => val!.trim().isEmpty ? "Hospital name is required" : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _hospitalAreaController,
                  decoration: const InputDecoration(
                    labelText: "Area / Location Address",
                    prefixIcon: Icon(Icons.place, color: AppTheme.secondaryCyan),
                  ),
                  validator: (val) => val!.trim().isEmpty ? "Hospital area is required" : null,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _emergencyController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Emergency Contact Number",
                    hintText: "10-digit mobile number",
                    prefixText: "+91 ",
                    prefixStyle: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    prefixIcon: Icon(Icons.contact_phone, color: AppTheme.errorRed),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Emergency contact is required";
                    final cleaned = val.trim();
                    if (cleaned.length != 10) {
                      return "Mobile number must be exactly 10 digits";
                    }
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
                      return "Please enter a valid Indian mobile number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // GPS triggers
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderCol),
                  ),
                  child: Row(
                    children: [
                      _fetchingLocation
                          ? const CircularProgressIndicator()
                          : IconButton(
                              icon: const Icon(Icons.gps_fixed, color: AppTheme.secondaryCyan),
                              onPressed: _fetchGPSCoordinates,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Caretaker Live Location",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _latitude == null || _longitude == null
                                  ? "Coordinates: not acquired yet"
                                  : "Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}",
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (_latitude == null || _longitude == null)
                        OutlinedButton(
                          onPressed: _fetchGPSCoordinates,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          child: const Text("Capture", style: TextStyle(fontSize: 12)),
                        )
                      else
                        const Icon(Icons.check_circle, color: AppTheme.emeraldGreen),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // SUBMIT BUTTON
                ElevatedButton(
                  onPressed: _startHospitalTransit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_filled_rounded),
                      SizedBox(width: 10),
                      Text("Start to Hospital (SMS Alerts)"),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.secondaryCyan,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCameraCaptureBox({
    required String title,
    required IconData icon,
    required String? filePath,
    required VoidCallback onTap,
  }) {
    final bool hasImage = filePath != null;
    final bool isMock = hasImage && filePath.startsWith('mock_');

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasImage ? AppTheme.emeraldGreen : AppTheme.borderCol),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: hasImage
              ? isMock
                  ? Container(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo, color: AppTheme.primaryBlue, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            "$title (Mocked)",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 2),
                          const Text("Tap to replace", style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(filePath), fit: BoxFit.cover),
                        Container(color: Colors.black26),
                        const Center(
                          child: Icon(Icons.check_circle, color: AppTheme.emeraldGreen, size: 32),
                        ),
                      ],
                    )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppTheme.textSecondary, size: 36),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("Capture Camera", style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTransitTrackerUI() {
    final patient = _activePatient!;
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
              // Animated pulsing locator circle
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
                "Patient Transit Active",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                "SMS Tracking alerts dispatched to coordinates",
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Trip details card
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
                            tooltip: "View in Google Maps",
                            onPressed: () async {
                              final Uri mapsUri = Uri.parse(mapUrl);
                              if (await canLaunchUrl(mapsUri)) {
                                await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                              } else {
                                FirebaseService.addLog("Could not launch external maps application.");
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

              // Emergency & Patient Action buttons
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

              // Drop-off confirmation
              ElevatedButton(
                onPressed: _completeDropOff,
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
