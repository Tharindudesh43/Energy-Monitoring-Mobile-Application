import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:energy_application/auth-pages/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserSettings extends StatefulWidget {
  const UserSettings({super.key});

  @override
  State<UserSettings> createState() => _UserSettingsState();
}

class _UserSettingsState extends State<UserSettings> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    Future<Map<String, dynamic>?> fetchUserProfile() async {
      try {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) return null;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        return doc.data();
      } catch (e) {
        print(e);
        return null;
      }
    }

    void _showEditDialog(Map<String, dynamic> profile) {
      final dailyController = TextEditingController(
        text: profile['dailylimit']?.toString() ?? '',
      );
      final weeklyController = TextEditingController(
        text: profile['weeklylimit']?.toString() ?? '',
      );
      final monthlyController = TextEditingController(
        text: profile['monthlylimit']?.toString() ?? '',
      );
      final peakRateController = TextEditingController(
        text: profile['PeakRate']?.toString() ?? '',
      );
      final normalRateController = TextEditingController(
        text: profile['NormalRate']?.toString() ?? '',
      );
      final peakWattLimitController = TextEditingController(
        text: profile['PeakWattLimit']?.toString() ?? '',
      );
      final normalWattLimitController = TextEditingController(
        text: profile['NormalWattLimit']?.toString() ?? '',
      );

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Edit Energy Settings"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: dailyController,
                    decoration: const InputDecoration(labelText: "Daily Limit"),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: weeklyController,
                    decoration: const InputDecoration(
                      labelText: "Weekly Limit",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: monthlyController,
                    decoration: const InputDecoration(
                      labelText: "Monthly Limit",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: peakRateController,
                    decoration: const InputDecoration(labelText: "Peak Rate"),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: normalRateController,
                    decoration: const InputDecoration(labelText: "Normal Rate"),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: peakWattLimitController,
                    decoration: const InputDecoration(
                      labelText: "Peak Watt Limit",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: normalWattLimitController,
                    decoration: const InputDecoration(
                      labelText: "Normal Watt Limit",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                        "dailylimit": double.parse(dailyController.text),
                        "weeklylimit": double.parse(weeklyController.text),
                        "monthlylimit": double.parse(monthlyController.text),
                        "PeakRate": double.parse(peakRateController.text),
                        "NormalRate": double.parse(normalRateController.text),
                        "PeakWattLimit": double.parse(
                          peakWattLimitController.text,
                        ),
                        "NormalWattLimit": double.parse(
                          normalWattLimitController.text,
                        ),
                      });

                  Navigator.pop(context);

                  setState(() {});
                },
              ),
            ],
          );
        },
      );
    }

    String formatMinutes(int minutes) {
      final hour = (minutes ~/ 60) % 24;
      final minute = minutes % 60;

      final tod = TimeOfDay(hour: hour, minute: minute);

      final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
      final m = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';

      return "$h:$m $period";
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Text(
                "Could not load profile data",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final profile = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 20),
                buildProfileImage(),
                const SizedBox(height: 25),
                Text(
                  profile['username'] ?? "No Name",
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "@${profile['username']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'user'}",
                  style: const TextStyle(color: Colors.amber, fontSize: 16),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text("EDIT ENERGY SETTINGS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      _showEditDialog(profile);
                    },
                  ),
                ),
                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "ENERGY SETTINGS",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                buildInfoTile(
                  Icons.bolt,
                  "Daily Limit",
                  "${profile['dailylimit'] ?? 0} kWh",
                ),

                buildInfoTile(
                  Icons.calendar_view_week,
                  "Weekly Limit",
                  "${profile['weeklylimit'] ?? 0} kWh",
                ),

                buildInfoTile(
                  Icons.calendar_month,
                  "Monthly Limit",
                  "${profile['monthlylimit'] ?? 0} kWh",
                ),

                buildInfoTile(
                  Icons.flash_on,
                  "Peak Rate",
                  "Rs ${profile['PeakRate'] ?? 0}/kWh",
                ),

                buildInfoTile(
                  Icons.energy_savings_leaf,
                  "Normal Rate",
                  "Rs ${profile['NormalRate'] ?? 0}/kWh",
                ),
                buildInfoTile(
                  Icons.energy_savings_leaf,
                  "Watt Normal Limit Rate",
                  "Watt: ${profile['NormalWattLimit'] ?? 0}/Watt",
                ),
                buildInfoTile(
                  Icons.energy_savings_leaf,
                  "Watt Peak Limit Rate",
                  "Watt: ${profile['PeakWattLimit'] ?? 0}/Watt",
                ),
                buildInfoTile(
                  Icons.access_time,
                  "Peak Time",
                  "${formatMinutes(profile['peakStart'] ?? 0)} - ${formatMinutes(profile['peakEnd'] ?? 0)}",
                ),
                buildInfoTile(
                  Icons.electrical_services,
                  "CEB Account",
                  profile['accountNumber'] ?? "Not Set",
                ),
                buildInfoTile(
                  Icons.phone,
                  "Mobile",
                  profile['mobile'] ?? "Not Set",
                ),
                buildInfoTile(
                  Icons.email,
                  "Email",
                  profile['email'] ?? "Not Set",
                ),

                const SizedBox(height: 20),
                buildLogOutButton(context),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildProfileImage() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.green, width: 4),
        ),
        child: const CircleAvatar(
          radius: 80,
          backgroundColor: Colors.grey,
          backgroundImage: AssetImage('assets/profileIMG.jpg'),
        ),
      ),
    );
  }

  Widget buildLogOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () async {
          setState(() => isLoading = true);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const Signin()),
              (route) => false,
            );
          }
        },
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "LOG OUT",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
