import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../services/gemini_match_service.dart';

class FoodMatchingPage extends StatefulWidget {
  const FoodMatchingPage({
    super.key,
    required this.foodName,
    required this.quantity,
    required this.category,
    required this.location,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.expiryTime,
    required this.imageBase64,
  });

  final String foodName;
  final String quantity;
  final String category;
  final String location;
  final double pickupLatitude;
  final double pickupLongitude;
  final DateTime expiryTime;
  final String imageBase64;

  @override
  State<FoodMatchingPage> createState() => _FoodMatchingPageState();
}

class _FoodMatchingPageState extends State<FoodMatchingPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _gemini = GeminiMatchService();

  bool _isMatching = true;
  int _stepIndex = 0;
  Timer? _stepTimer;

  String? _listingId;
  String? _matchedNgoName;
  String? _matchingReason;
  int? _matchConfidence;
  bool _hasMatch = false;

  final List<String> _steps = const [
    "Uploading food listing...",
    "Evaluating NGO capacity...",
    "Calculating true geo distance...",
    "Asking Gemini to rank priorities...",
  ];

  @override
  void initState() {
    super.initState();
    _startStepAnimation();
    _startMatchingFlow();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    super.dispose();
  }

  void _startStepAnimation() {
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!_isMatching || !mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _stepIndex = (_stepIndex + 1) % _steps.length;
      });
    });
  }

  Future<void> _startMatchingFlow() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _matchingReason = "Please login again and retry upload.";
      });
      return;
    }

    try {
      final listingRef = await _firestore.collection("food_listings").add({
        "foodName": widget.foodName,
        "quantity": widget.quantity,
        "category": widget.category,
        "location": widget.location,
        "pickupLatitude": widget.pickupLatitude,
        "pickupLongitude": widget.pickupLongitude,
        "expiryTime": Timestamp.fromDate(widget.expiryTime),
        "createdAt": Timestamp.now(),
        "imageBase64": widget.imageBase64,
        "donorId": user.uid,
        "status": "matching",
        "matchingState": "processing",
        "ngoDecision": "waiting",
      });
      _listingId = listingRef.id;

      await Future<void>.delayed(const Duration(milliseconds: 800));
      final candidates = await _loadNgoCandidates(
        quantityNeeded: _parseQuantity(widget.quantity),
        pickupLat: widget.pickupLatitude,
        pickupLng: widget.pickupLongitude,
      );

      if (candidates.isEmpty) {
        await listingRef.update({
          "status": "pending",
          "matchingState": "no_ngo_available",
          "matchingReason": "No approved NGO found.",
          "ngoDecision": "unassigned",
        });

        if (!mounted) return;
        setState(() {
          _isMatching = false;
          _hasMatch = false;
          _matchingReason = "No approved NGO is available right now.";
        });
        return;
      }

      final suitable = candidates.where((c) => c.isCapacitySuitable).toList();
      final pool = suitable.isNotEmpty ? suitable : candidates;
      pool.sort((a, b) {
        final distanceCompare = a.distanceKm.compareTo(b.distanceKm);
        if (distanceCompare != 0) return distanceCompare;
        return b.remainingCapacity.compareTo(a.remainingCapacity);
      });
      _NgoCandidate best = pool.first;
      String reason =
          "Matched by capacity (${best.remainingCapacity} remaining) and nearest true distance (${best.distanceKm.toStringAsFixed(2)} km).";
      int confidence = _buildConfidence(best);

      final geminiRanking = await _gemini.rankNgoCandidates(
        foodName: widget.foodName,
        category: widget.category,
        quantity: _parseQuantity(widget.quantity),
        foodLat: widget.pickupLatitude,
        foodLng: widget.pickupLongitude,
        candidates: pool
            .map((c) => {
                  "ngoId": c.ngoId,
                  "ngoName": c.ngoName,
                  "distanceKm": c.distanceKm,
                  "capacitySuitable": c.isCapacitySuitable,
                  "remainingCapacity": c.remainingCapacity,
                  "baseLatitude": c.baseLatitude,
                  "baseLongitude": c.baseLongitude,
                })
            .toList(),
      );

      if (geminiRanking != null) {
        final matchedByGemini = pool.where((c) => c.ngoId == geminiRanking.selectedNgoId);
        if (matchedByGemini.isNotEmpty) {
          best = matchedByGemini.first;
          reason = geminiRanking.reason;
          confidence = geminiRanking.confidence;
        }
      }

      await listingRef.update({
        "status": "pending",
        "matchingState": "matched",
        "matchedNgoId": best.ngoId,
        "matchedNgoName": best.ngoName,
        "matchedServiceArea": best.serviceArea,
        "matchedNgoBaseLatitude": best.baseLatitude,
        "matchedNgoBaseLongitude": best.baseLongitude,
        "capacitySuitable": best.isCapacitySuitable,
        "matchDistanceKm": best.distanceKm,
        "matchConfidence": confidence,
        "matchModel": geminiRanking == null
            ? "RuleBased+Haversine v2"
            : "Gemini+Haversine v2",
        "matchingReason": reason,
        "ngoDecision": "waiting",
      });

      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _hasMatch = true;
        _matchedNgoName = best.ngoName;
        _matchConfidence = confidence;
        _matchingReason =
            geminiRanking?.reason ??
            (best.isCapacitySuitable
                ? "Capacity requirement met, then nearest true-distance NGO selected."
                : "No NGO had full capacity. Nearest NGO selected as fallback.");
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMatching = false;
        _hasMatch = false;
        _matchingReason = "Matching failed: $e";
      });
    }
  }

  Future<List<_NgoCandidate>> _loadNgoCandidates({
    required int quantityNeeded,
    required double pickupLat,
    required double pickupLng,
  }) async {
    final ngoSnapshot = await _firestore
        .collection("users")
        .where("ngoStatus", isEqualTo: "approved")
        .get();

    final List<_NgoCandidate> candidates = [];
    for (final doc in ngoSnapshot.docs) {
      final data = doc.data();
      final profile = (data["ngoProfile"] as Map<String, dynamic>?) ?? {};
      final ngoId = doc.id;
      final ngoName = (profile["organizationName"] ?? "NGO Partner").toString();
      final serviceArea = (profile["serviceArea"] ?? "").toString();
      final baseLat = _parseDoubleValue(profile["baseLatitude"]);
      final baseLng = _parseDoubleValue(profile["baseLongitude"]);
      if (baseLat == null || baseLng == null) {
        continue;
      }
      final dailyCapacityRaw = profile["dailyCapacity"];
      final dailyCapacity = _parseIntValue(dailyCapacityRaw);

      final assignedToday = await _assignedMealsToday(ngoId);
      final remaining = dailyCapacity > 0 ? dailyCapacity - assignedToday : -1;
      final suitable = dailyCapacity > 0 && remaining >= quantityNeeded;
      final distanceKm = _haversineKm(
        pickupLat,
        pickupLng,
        baseLat,
        baseLng,
      );

      candidates.add(
        _NgoCandidate(
          ngoId: ngoId,
          ngoName: ngoName,
          serviceArea: serviceArea,
          baseLatitude: baseLat,
          baseLongitude: baseLng,
          remainingCapacity: remaining,
          isCapacitySuitable: suitable,
          distanceKm: distanceKm,
        ),
      );
    }

    return candidates;
  }

  Future<int> _assignedMealsToday(String ngoId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestore
        .collection("food_listings")
        .where("assignedNgoId", isEqualTo: ngoId)
        .where("ngoActionAt", isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    int total = 0;
    for (final doc in snapshot.docs) {
      final qty = (doc.data()["quantity"] ?? "").toString();
      total += _parseQuantity(qty);
    }
    return total;
  }

  int _parseQuantity(String text) {
    final match = RegExp(r"\d+").firstMatch(text);
    if (match == null) return 0;
    return int.tryParse(match.group(0) ?? "0") ?? 0;
  }

  int _parseIntValue(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double? _parseDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  int _buildConfidence(_NgoCandidate candidate) {
    final distanceComponent = (1 / (1 + candidate.distanceKm)).clamp(0.0, 1.0);
    final distancePoints = (distanceComponent * 35).round();
    final capacityPoints = candidate.isCapacitySuitable ? 60 : 30;
    return (capacityPoints + distancePoints).clamp(50, 98);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Center(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _isMatching ? _buildLoadingBody() : _buildResultBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          "AI Matching In Progress",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            _steps[_stepIndex],
            key: ValueKey<int>(_stepIndex),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
        ),
      ],
    );
  }

  Widget _buildResultBody() {
    final title = _hasMatch ? "Match Ready" : "Matching Completed";
    final subtitle = _hasMatch
        ? "Your listing was matched to $_matchedNgoName."
        : "No suitable NGO found for now. Listing remains visible for future matching.";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _hasMatch ? Icons.check_circle_rounded : Icons.info_rounded,
          color: _hasMatch ? appPrimaryGreen : Colors.orange,
          size: 62,
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (_hasMatch && _matchConfidence != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              "Match Confidence: $_matchConfidence%",
              style: TextStyle(
                color: appPrimaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_matchingReason != null) ...[
          const SizedBox(height: 12),
          Text(
            _matchingReason!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, _listingId != null),
            style: ElevatedButton.styleFrom(
              backgroundColor: appPrimaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Back To Dashboard",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _NgoCandidate {
  const _NgoCandidate({
    required this.ngoId,
    required this.ngoName,
    required this.serviceArea,
    required this.baseLatitude,
    required this.baseLongitude,
    required this.remainingCapacity,
    required this.isCapacitySuitable,
    required this.distanceKm,
  });

  final String ngoId;
  final String ngoName;
  final String serviceArea;
  final double baseLatitude;
  final double baseLongitude;
  final int remainingCapacity;
  final bool isCapacitySuitable;
  final double distanceKm;
}
