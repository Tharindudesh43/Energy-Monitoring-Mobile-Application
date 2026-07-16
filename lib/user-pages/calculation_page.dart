import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class CalculationPage extends StatefulWidget {
  const CalculationPage({super.key});

  @override
  State<CalculationPage> createState() => _CalculationPageState();
}

class _CalculationPageState extends State<CalculationPage> {
  final TextEditingController _unitsController = TextEditingController();

  final TextEditingController _rateBlock1 = TextEditingController(
    text: "25.0",
  ); // 0-60 Units
  final TextEditingController _rateBlock2 = TextEditingController(
    text: "30.0",
  ); // 61-90 Units
  final TextEditingController _rateBlock3 = TextEditingController(
    text: "50.0",
  ); // 91-180 Units
  final TextEditingController _rateBlock4 = TextEditingController(
    text: "75.0",
  ); // Above 180
  final TextEditingController _fixedChargeController = TextEditingController(
    text: "400.0",
  );

  double _totalBill = 0.0;

  void _calculateDynamicBill() {
    double units = double.tryParse(_unitsController.text) ?? 0.0;
    double r1 = double.tryParse(_rateBlock1.text) ?? 0.0;
    double r2 = double.tryParse(_rateBlock2.text) ?? 0.0;
    double r3 = double.tryParse(_rateBlock3.text) ?? 0.0;
    double r4 = double.tryParse(_rateBlock4.text) ?? 0.0;
    double fixed = double.tryParse(_fixedChargeController.text) ?? 0.0;

    double energyCharge = 0.0;

    if (units <= 60) {
      energyCharge = units * r1;
    } else if (units <= 90) {
      energyCharge = (60 * r1) + ((units - 60) * r2);
    } else if (units <= 180) {
      energyCharge = (60 * r1) + (30 * r2) + ((units - 90) * r3);
    } else {
      energyCharge = (60 * r1) + (30 * r2) + (90 * r3) + ((units - 180) * r4);
    }

    setState(() {
      _totalBill = energyCharge + fixed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Flexible Bill Calculator"),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. Main Input
            _buildInput(
              _unitsController,
              "Total Units Consumed",
              Icons.bolt,
              Colors.yellow,
              true,
            ),
            const SizedBox(height: 25),

            const Row(
              children: [
                Icon(Icons.settings, color: Colors.grey, size: 16),
                SizedBox(width: 8),
                Text(
                  "ADJUST UNIT CHARGES (Rs.)",
                  style: TextStyle(
                    color: Colors.grey,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            Row(
              children: [
                Expanded(child: _buildSmallInput(_rateBlock1, "0-60 Units")),
                const SizedBox(width: 10),
                Expanded(child: _buildSmallInput(_rateBlock2, "61-90 Units")),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildSmallInput(_rateBlock3, "91-180 Units")),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSmallInput(
                    _fixedChargeController,
                    "Fixed Charge",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                children: [
                  const Text(
                    "TOTAL PAYABLE",
                    style: TextStyle(color: Colors.white70, letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Rs. ${_totalBill.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextButton(
                    onPressed: () async {
                      // Future<void> clearAllData() async {
                      //   // Reference the very top of your JSON tree
                      //   DatabaseReference ref = FirebaseDatabase.instance.ref();

                      //   try {
                      //     await ref.remove(); // This deletes EVERYTHING
                      //     print("✅ Database cleared successfully.");
                      //   } catch (e) {
                      //     print("❌ Failed to clear database: $e");
                      //   }
                      // }
                    },
                    child: Text("Clear User Data"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController ctrl,
    String label,
    IconData icon,
    Color color,
    bool isLarge,
  ) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (v) => _calculateDynamicBill(),
      style: TextStyle(color: Colors.white, fontSize: isLarge ? 22 : 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildSmallInput(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      onChanged: (v) => _calculateDynamicBill(),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
