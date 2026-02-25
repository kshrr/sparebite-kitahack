import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_colors.dart';

class ImpactPage extends StatelessWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view impact.")),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection("users").doc(user.uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScaffold();
        }

        final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
        final isNgo =
            userData["isNGO"] == true || userData["ngoStatus"] == "approved";

        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection("food_listings");
        query = isNgo
            ? query.where("assignedNgoId", isEqualTo: user.uid)
            : query.where("donorId", isEqualTo: user.uid);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.orderBy("createdAt", descending: true).snapshots(),
          builder: (context, listingSnapshot) {
            if (listingSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScaffold();
            }

            final docs = listingSnapshot.data?.docs ?? [];
            final stats = _ImpactStats.fromDocs(docs);

            return Scaffold(
              backgroundColor: const Color(0xFFF8F4EF),
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: 165,
                    elevation: 0,
                    backgroundColor: appPrimaryGreen,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        isNgo ? "NGO Impact" : "My Impact",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                isNgo
                                    ? "Track accepted pickups and completed food rescues."
                                    : "See your donation growth and community contribution.",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          _SummaryCard(stats: stats, isNgo: isNgo),
                          const SizedBox(height: 14),
                          _MetricGrid(stats: stats, isNgo: isNgo),
                          const SizedBox(height: 18),
                          _SectionTitle(
                            title: "Recent Activity",
                            icon: Icons.history_toggle_off_rounded,
                          ),
                          const SizedBox(height: 10),
                          _ActivityList(docs: docs, isNgo: isNgo),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Scaffold _buildLoadingScaffold() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.isNgo});

  final _ImpactStats stats;
  final bool isNgo;

  @override
  Widget build(BuildContext context) {
    final headline = isNgo ? "Food Accepted" : "Food Posted";
    final headlineValue = isNgo ? stats.assigned : stats.total;
    final subLabel = isNgo ? "Completed pickups" : "Completed donations";
    final subValue = stats.completed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFFA67C52), Color(0xFF8B5E34)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _GradientStat(value: "$headlineValue", label: headline),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _GradientStat(value: "$subValue", label: subLabel),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _GradientStat(
              value: "${stats.successRate}%",
              label: "Success Rate",
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientStat extends StatelessWidget {
  const _GradientStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.stats, required this.isNgo});

  final _ImpactStats stats;
  final bool isNgo;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.38,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _MetricTile(
          label: "Meals Rescued",
          value: "${stats.meals}",
          icon: Icons.ramen_dining_rounded,
        ),
        _MetricTile(
          label: "CO2 Saved (kg)",
          value: stats.co2.toStringAsFixed(1),
          icon: Icons.eco_rounded,
        ),
        _MetricTile(
          label: "This Week",
          value: "${stats.thisWeek}",
          icon: Icons.calendar_view_week_rounded,
        ),
        _MetricTile(
          label: isNgo ? "Rejected Matches" : "Pending Listings",
          value: isNgo ? "${stats.rejected}" : "${stats.pending}",
          icon: isNgo ? Icons.cancel_outlined : Icons.pending_actions_rounded,
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: appPrimaryGreenLightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: appPrimaryGreen, size: 18),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: appPrimaryGreenLightBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: appPrimaryGreen, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3436),
          ),
        ),
      ],
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.docs, required this.isNgo});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isNgo;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          "No activity yet. ${isNgo ? "Accept your first match." : "Upload your first donation."}",
          style: TextStyle(color: Colors.grey.shade700),
        ),
      );
    }

    final latest = docs.take(6).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: latest.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value.data();
          final status = (data["status"] ?? "pending").toString();
          final foodName = (data["foodName"] ?? "Food Item").toString();
          final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
          final timeLabel = createdAt == null ? "-" : _timeAgo(createdAt);

          Color color;
          IconData icon;
          switch (status) {
            case "completed":
              color = Colors.teal;
              icon = Icons.check_circle;
              break;
            case "assigned":
              color = Colors.indigo;
              icon = Icons.handshake_rounded;
              break;
            default:
              color = Colors.orange;
              icon = Icons.schedule;
          }

          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 19),
                ),
                title: Text(
                  foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "${status.toUpperCase()} • $timeLabel",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              if (index != latest.length - 1)
                Divider(height: 1, indent: 68, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
}

class _ImpactStats {
  const _ImpactStats({
    required this.total,
    required this.pending,
    required this.assigned,
    required this.completed,
    required this.meals,
    required this.co2,
    required this.thisWeek,
    required this.rejected,
    required this.successRate,
  });

  final int total;
  final int pending;
  final int assigned;
  final int completed;
  final int meals;
  final double co2;
  final int thisWeek;
  final int rejected;
  final int successRate;

  factory _ImpactStats.fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    int pending = 0;
    int assigned = 0;
    int completed = 0;
    int meals = 0;
    int thisWeek = 0;
    int rejected = 0;

    final weekStart = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );

    for (final doc in docs) {
      final data = doc.data();
      final status = (data["status"] ?? "pending").toString();
      final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
      final quantityRaw = (data["quantity"] ?? "").toString();

      switch (status) {
        case "completed":
          completed++;
          break;
        case "assigned":
          assigned++;
          break;
        default:
          pending++;
      }

      final parsed = RegExp(r"\d+").firstMatch(quantityRaw);
      meals += parsed != null ? int.tryParse(parsed.group(0)!) ?? 0 : 0;

      if (createdAt != null && createdAt.isAfter(weekStart)) {
        thisWeek++;
      }

      final decision = (data["ngoDecision"] ?? "").toString();
      if (decision == "rejected") {
        rejected++;
      }
    }

    final total = docs.length;
    final successful = assigned + completed;
    final successRate = total == 0 ? 0 : ((successful / total) * 100).round();

    return _ImpactStats(
      total: total,
      pending: pending,
      assigned: assigned,
      completed: completed,
      meals: meals,
      co2: meals * 0.25,
      thisWeek: thisWeek,
      rejected: rejected,
      successRate: successRate,
    );
  }
}
