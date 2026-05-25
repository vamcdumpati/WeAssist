import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ScrollController _logScrollController = ScrollController();
  bool _isConsoleExpanded = true;

  @override
  void initState() {
    super.initState();
    // Connect log updates to state refresh
    FirebaseService.onLogAdded = () {
      if (mounted) {
        setState(() {});
        // Auto scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    };
  }

  @override
  void dispose() {
    FirebaseService.onLogAdded = null;
    _logScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("We Assist"),
        backgroundColor: AppTheme.darkBackground,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            tooltip: "Logout",
            onPressed: () async {
              await authProvider.signOutUser();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Caretaker Details Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.2),
                                  child: const Icon(Icons.account_circle, color: AppTheme.primaryBlue, size: 36),
                                ),
                                const SizedBox(width: 12),
                                 Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.displayName ?? 'Caretaker',
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      Text(
                                        user?.mobile ?? 'No mobile on record',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                if (user?.role != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emeraldGreen.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.emeraldGreen, width: 1),
                                    ),
                                    child: Text(
                                      user!.role!,
                                      style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.borderCol),
                            Text(
                              "Mobile: ${user?.mobile ?? 'N/A'}",
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Engine Mode: ${FirebaseService.isDemoMode ? 'Demo Fallback (Local Database)' : 'Live Connected (Firebase Cloud)'}",
                              style: TextStyle(
                                color: FirebaseService.isDemoMode ? AppTheme.secondaryCyan : AppTheme.emeraldGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Option Header
                    Text(
                      "Transit Operations Menu",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),

                    // Register Option Card
                    _buildOptionCard(
                      context: context,
                      title: "Register New Patient",
                      description: "Enter personal bio-data, snap camera ID and portrait, locate GPS coordinates, and start transit alerts.",
                      icon: Icons.person_add_alt_1_rounded,
                      accentColor: AppTheme.primaryBlue,
                      route: '/intake',
                    ),
                    const SizedBox(height: 16),

                    // Search Option Card
                    _buildOptionCard(
                      context: context,
                      title: "Search Existing Directory",
                      description: "Lookup current patients, check past medical transit logs, and quickly book a new visit for returning patients.",
                      icon: Icons.manage_search_rounded,
                      accentColor: AppTheme.secondaryCyan,
                      route: '/dossier',
                    ),
                  ],
                ),
              ),
            ),

            // Developer Console (Console Logs Drawer at Bottom)
            _buildConsoleLogs(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String route,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, route);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCol, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleLogs() {
    return Column(
      children: [
        // Console control bar
        GestureDetector(
          onTap: () {
            setState(() {
              _isConsoleExpanded = !_isConsoleExpanded;
            });
          },
          child: Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.terminal, color: AppTheme.secondaryCyan, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      "Simulation Log Terminal",
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${FirebaseService.simulationLogs.length}",
                        style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.grey, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          FirebaseService.simulationLogs.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      _isConsoleExpanded ? Icons.expand_more : Icons.expand_less,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Console body
        if (_isConsoleExpanded)
          Container(
            height: 180,
            width: double.infinity,
            color: const Color(0xFF0B0F19),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: FirebaseService.simulationLogs.isEmpty
                ? const Center(
                    child: Text(
                      "Terminal quiet. Waiting for events...",
                      style: TextStyle(fontFamily: 'Courier', color: Colors.grey, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: FirebaseService.simulationLogs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          FirebaseService.simulationLogs[index],
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            color: Colors.greenAccent,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}
