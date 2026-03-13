import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/pickup_verification_service.dart';
import '../widgets/future_ui.dart';
import 'my_impact_dashboard.dart';
import 'qr_scanner_screen.dart';

class DonationDetailScreen extends StatefulWidget {
  const DonationDetailScreen({super.key, required this.donationId});

  final String donationId;

  @override
  State<DonationDetailScreen> createState() => _DonationDetailScreenState();
}

class _DonationDetailScreenState extends State<DonationDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _verificationService = PickupVerificationService();
  bool _isVerifying = false;
  bool _isPreparingPickup = false;
  bool _hasShownAcceptedImpact = false;

  @override
  void initState() {
    super.initState();
    _ensurePickupDefaults();
  }

  Future<void> _ensurePickupDefaults() async {
    final docRef = _firestore.collection("food_listings").doc(widget.donationId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? <String, dynamic>{};
    final updates = <String, dynamic>{};

    if ((data["pickup_location"] ?? "").toString().trim().isEmpty) {
      updates["pickup_location"] = (data["location"] ?? "").toString();
    }

    if (data["pickup_time"] == null) {
      final fallbackTs =
          data["ngoActionAt"] as Timestamp? ??
          data["createdAt"] as Timestamp? ??
          Timestamp.fromDate(DateTime.now());
      updates["pickup_time"] = fallbackTs;
    }

    if ((data["pickup_qr_token"] ?? "").toString().trim().isEmpty) {
      updates["pickup_qr_token"] = _generatePickupToken();
    }

    if ((data["donation_id"] ?? "").toString().trim().isEmpty) {
      updates["donation_id"] = widget.donationId;
    }

    if (updates.isEmpty) return;
    setState(() => _isPreparingPickup = true);
    try {
      await docRef.update(updates);
    } finally {
      if (mounted) setState(() => _isPreparingPickup = false);
    }
  }

  Future<void> _scanAndVerify() async {
    if (_isVerifying) return;
    final donorId = _auth.currentUser?.uid;
    if (donorId == null) return;

    final rawPayload = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (!mounted || rawPayload == null) return;

    setState(() => _isVerifying = true);
    try {
      final success = await _verificationService.verifyPickupWithQr(
        donationId: widget.donationId,
        scannedPayload: rawPayload,
        verifiedByDonorId: donorId,
      );

      if (!mounted) return;
      if (success) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Pickup Verified"),
            content: const Text(
              "The NGO has successfully collected the food.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("QR verification failed. Please scan the correct NGO QR."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to verify pickup right now."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _verifyWithCode() async {
    if (_isVerifying) return;
    final donorId = _auth.currentUser?.uid;
    if (donorId == null) return;

    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enter Pickup Code"),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: "Enter code from NGO screen",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Verify"),
          ),
        ],
      ),
    );

    if (!mounted || code == null || code.trim().isEmpty) return;
    setState(() => _isVerifying = true);
    try {
      final success = await _verificationService.verifyPickupWithCode(
        donationId: widget.donationId,
        pickupCode: code,
        verifiedByDonorId: donorId,
      );
      if (!mounted) return;
      if (success) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Pickup Verified"),
            content: const Text(
              "The NGO has successfully collected the food.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Code verification failed. Please check the code."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to verify pickup right now."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docRef = _firestore.collection("food_listings").doc(widget.donationId);
    return Scaffold(
      backgroundColor: appSurface,
      appBar: AppBar(
        title: const Text("Donation Details"),
        backgroundColor: appPrimaryGreen,
        foregroundColor: Colors.white,
      ),
      body: FutureBackground(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isPreparingPickup) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(appPrimaryGreen),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Donation not found."));
          }

          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final status = (data["status"] ?? "pending").toString().toLowerCase();

          _maybeShowAcceptedImpactPopup(data, status);
          final canScan = status == "assigned" ||
              status == "accepted" ||
              status == "ready_for_pickup";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: "Donation Information",
                children: [
                  _buildRow("Food Name", (data["foodName"] ?? "-").toString()),
                  _buildRow("Quantity", (data["quantity"] ?? "-").toString()),
                  _buildRow(
                    "Donation ID",
                    (data["donation_id"] ?? data["donationId"] ?? widget.donationId)
                        .toString(),
                  ),
                  _buildRow("Status", _displayStatus(status)),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: "NGO Information",
                children: [
                  _buildRow(
                    "NGO Name",
                    (data["assignedNgoName"] ?? data["matchedNgoName"] ?? "-")
                        .toString(),
                  ),
                  _buildRow(
                    "Contact Number",
                    (data["ngo_contact_number"] ?? "-").toString(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: "Pickup Details",
                children: [
                  _buildRow(
                    "Pickup Location",
                    (data["pickup_location"] ?? data["location"] ?? "-")
                        .toString(),
                  ),
                  _buildRow(
                    "Pickup Time",
                    _formatDateTime((data["pickup_time"] as Timestamp?)?.toDate()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSection(
                title: "Pickup Verification",
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (canScan && !_isVerifying) ? _scanAndVerify : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appPrimaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.qr_code_scanner),
                      label: Text(_isVerifying ? "Verifying..." : "Scan NGO QR"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (canScan && !_isVerifying) ? _verifyWithCode : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appPrimaryGreen,
                        side: BorderSide(color: appPrimaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.password_rounded),
                      label: const Text("Enter Pickup Code"),
                    ),
                  ),
                  if (!canScan)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        "QR scan is available when status is Accepted or Ready for Pickup.",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ],
          );
          },
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return FutureCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: appTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(
                color: appTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return "-";
    return "${dateTime.year.toString().padLeft(4, '0')}-"
        "${dateTime.month.toString().padLeft(2, '0')}-"
        "${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }

  String _displayStatus(String status) {
    switch (status) {
      case "assigned":
        return "Accepted";
      case "ready_for_pickup":
        return "Ready for Pickup";
      case "picked_up":
        return "Picked Up";
      case "delivered":
        return "Delivered";
      case "completed":
        return "Completed";
      case "accepted":
        return "Accepted";
      default:
        if (status.isEmpty) return "Pending";
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  void _maybeShowAcceptedImpactPopup(
    Map<String, dynamic> data,
    String status,
  ) {
    if (_hasShownAcceptedImpact) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // Only show for the donor who created this listing.
    final donorId = (data["donorId"] ?? "").toString();
    if (donorId.isEmpty || donorId != currentUserId) return;

    // Show once the NGO has accepted or the donation is further along.
    const acceptedStatuses = <String>{
      "assigned",
      "accepted",
      "ready_for_pickup",
      "picked_up",
      "delivered",
      "completed",
    };
    if (!acceptedStatuses.contains(status)) return;

    final impact = (data["impact"] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final peopleFed = _toInt(impact["peopleFed"]);
    final waterLiters = _toInt(impact["waterUsedLiters"]);
    final co2Saved = _toDouble(impact["co2SavedKg"]);
    final educationTip = (impact["educationTip"] ?? "").toString();

    // Avoid meaningless popup if there is no impact information at all.
    if (peopleFed <= 0 && waterLiters <= 0 && co2Saved <= 0) return;

    _hasShownAcceptedImpact = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text("Your donation was accepted 🎉"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Here’s how this pickup helps in the real world:",
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (peopleFed > 0)
                  Text(
                    "• People Fed: $peopleFed",
                    style: const TextStyle(fontSize: 13),
                  ),
                if (waterLiters > 0)
                  Text(
                    "• Water Used to Produce This Food: ${_formatCompactNumber(waterLiters)} L",
                    style: const TextStyle(fontSize: 13),
                  ),
                if (co2Saved > 0)
                  Text(
                    "• CO₂ Emissions Prevented: ${co2Saved.toStringAsFixed(1)} kg",
                    style: const TextStyle(fontSize: 13),
                  ),
                const SizedBox(height: 10),
                Text(
                  educationTip.isNotEmpty
                      ? educationTip
                      : "Producing 1kg of rice can require around 2,500 liters of water. By rescuing surplus food, you protect the resources that went into growing, transporting, and cooking it.",
                  style: const TextStyle(
                    fontSize: 12,
                    color: appTextMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyImpactDashboard(),
                    ),
                  );
                },
                child: const Text("View My Impact"),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  String _formatCompactNumber(int value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toString();
  }

  String _generatePickupToken() {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final random = Random.secure();
    return List.generate(
      6,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
