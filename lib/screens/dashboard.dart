import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_colors.dart';
import 'my_listings_page.dart';
import 'upload_food_page.dart';
import 'login.dart';
import 'ngo_application_page.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  String ngoStatus = "loading";
  String userEmail = "";
  Map<String, dynamic> impactStats = {};
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
    loadImpactStats();
  }

  // ---------------- LOAD USER DATA ----------------
  Future<void> loadUserData() async {
    final user = auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email ?? "User";
      });

      final doc = await firestore.collection("users").doc(user.uid).get();
      if (mounted) {
        setState(() {
          ngoStatus = doc.data()?["ngoStatus"] ?? "none";
        });
      }
    }
  }

  // ---------------- LOAD IMPACT STATS ----------------
  Future<void> loadImpactStats() async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final listingsSnapshot = await firestore
          .collection("food_listings")
          .where("donorId", isEqualTo: uid)
          .get();

      int totalDonations = listingsSnapshot.docs.length;
      int completedDonations = 0;
      int pendingDonations = 0;
      int assignedDonations = 0;
      int totalMeals = 0;
      double totalCO2 = 0.0;

      final now = DateTime.now();
      final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
      final thisMonthStart = DateTime(now.year, now.month, 1);

      int thisWeekDonations = 0;
      int thisMonthDonations = 0;

      for (var doc in listingsSnapshot.docs) {
        final data = doc.data();
        final status = data["status"] ?? "pending";
        final createdAt = (data["createdAt"] as Timestamp?)?.toDate();

        switch (status) {
          case "completed":
            completedDonations++;
            // Estimate meals: assume 4 meals per donation on average
            totalMeals += 4;
            // Estimate CO2: ~2.5 kg CO2 per kg of food waste prevented
            totalCO2 += 2.5;
            break;
          case "pending":
            pendingDonations++;
            break;
          case "assigned":
            assignedDonations++;
            break;
        }

        if (createdAt != null) {
          if (createdAt.isAfter(thisWeekStart)) {
            thisWeekDonations++;
          }
          if (createdAt.isAfter(thisMonthStart)) {
            thisMonthDonations++;
          }
        }
      }

      if (mounted) {
        setState(() {
          impactStats = {
            'totalDonations': totalDonations,
            'completedDonations': completedDonations,
            'pendingDonations': pendingDonations,
            'assignedDonations': assignedDonations,
            'totalMeals': totalMeals,
            'totalCO2': totalCO2,
            'thisWeekDonations': thisWeekDonations,
            'thisMonthDonations': thisMonthDonations,
            'successRate': totalDonations > 0
                ? ((completedDonations / totalDonations) * 100).round()
                : 0,
          };
          isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStats = false;
        });
      }
    }
  }

  // ---------------- APPLY AS NGO ----------------
  Future<void> applyAsNGO() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NgoApplicationPage()),
    );
    await loadUserData();
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await auth.signOut();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: RefreshIndicator(
        onRefresh: () async {
          await loadImpactStats();
          await loadUserData();
        },
        color: const Color(0xFFA67C52),
        child: CustomScrollView(
          slivers: [
            // Premium App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFFA67C52),
              flexibleSpace: FlexibleSpaceBar(
                title: const Text(
                  "Sparebite",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                centerTitle: true,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFA67C52),
                        const Color(0xFF8B5E34),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    // TODO: Navigate to notifications
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: logout,
                ),
              ],
            ),

            // Main Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Section with Personalized Greeting
                    _buildHeroCard(),

                    const SizedBox(height: 24),

                    // Urgent Alerts Section
                    _buildUrgentAlerts(),

                    const SizedBox(height: 24),

                    // Impact Metrics Section
                    _buildSectionTitle("Your Impact", Icons.insights),
                    const SizedBox(height: 16),
                    _buildImpactMetrics(),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildSectionTitle("Quick Actions", Icons.flash_on),
                    const SizedBox(height: 16),
                    _buildQuickActions(),

                    const SizedBox(height: 24),

                    // Recent Activity
                    _buildSectionTitle("Recent Activity", Icons.history),
                    const SizedBox(height: 16),
                    _buildRecentActivity(),

                    const SizedBox(height: 24),

                    // Analytics Section
                    _buildSectionTitle("Analytics", Icons.analytics),
                    const SizedBox(height: 16),
                    _buildAnalytics(),

                    const SizedBox(height: 24),

                    // Achievement Badges (Optional)
                    _buildAchievements(),

                    const SizedBox(height: 100), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- HERO CARD ----------------
  Widget _buildHeroCard() {
    final userName = userEmail.split('@').first;
    final greeting = _getGreeting();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA67C52),
            Color(0xFF8B5E34),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: appPrimaryGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$greeting, ${userName.capitalize()}!",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Together, we're making a difference",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              _buildNGOStatusBadge(),
            ],
          ),
          const SizedBox(height: 20),
          if (isLoadingStats)
            const SizedBox(
              height: 40,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    "${impactStats['totalDonations'] ?? 0}",
                    "Total Donations",
                    Colors.white,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.white30),
                Expanded(
                  child: _buildMiniStat(
                    "${impactStats['totalMeals'] ?? 0}",
                    "Meals Saved",
                    Colors.white,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withOpacity(0.8), fontSize: 11),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 17) return "Good afternoon";
    return "Good evening";
  }

  // ---------------- NGO STATUS BADGE ----------------
  Widget _buildNGOStatusBadge() {
    Color color;
    String text;
    IconData icon;

    switch (ngoStatus) {
      case "approved":
        color = appPrimaryGreen;
        text = "Verified NGO";
        icon = Icons.verified;
        break;
      case "pending":
        color = Colors.orange;
        text = "Pending";
        icon = Icons.pending;
        break;
      default:
        color = Colors.white;
        text = "Donor";
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- URGENT ALERTS ----------------
  Widget _buildUrgentAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("food_listings")
          .where("donorId", isEqualTo: auth.currentUser?.uid)
          .where("status", isEqualTo: "pending")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final urgentListings = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final expiryTime = (data["expiryTime"] as Timestamp?)?.toDate();
          if (expiryTime == null) return false;
          final hoursUntilExpiry = expiryTime
              .difference(DateTime.now())
              .inHours;
          return hoursUntilExpiry <= 24 && hoursUntilExpiry > 0;
        }).toList();

        if (urgentListings.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Urgent: Food Expiring Soon",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      "${urgentListings.length} donation${urgentListings.length > 1 ? 's' : ''} need attention",
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.red),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyListingsPage()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------- SECTION TITLE ----------------
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFA67C52).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFA67C52), size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3436),
          ),
        ),
      ],
    );
  }

  // ---------------- IMPACT METRICS ----------------
  Widget _buildImpactMetrics() {
    if (isLoadingStats) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.restaurant,
                value: "${impactStats['totalMeals'] ?? 0}",
                label: "Meals Saved",
                color: appPrimaryGreen,
                subtitle:
                    "This month: ${impactStats['thisMonthDonations'] ?? 0}",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.eco,
                value: "${impactStats['totalCO2']?.toStringAsFixed(1) ?? '0'}",
                label: "CO2 Saved (kg)",
                color: Colors.blue,
                subtitle: "Environmental impact",
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.inventory_2,
                value: "${impactStats['totalDonations'] ?? 0}",
                label: "Total Donations",
                color: Colors.orange,
                subtitle: "All time",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.check_circle,
                value: "${impactStats['successRate'] ?? 0}%",
                label: "Success Rate",
                color: Colors.purple,
                subtitle: "Completed matches",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- QUICK ACTIONS ----------------
  Widget _buildQuickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.2,
      children: [
        _buildActionCard(
          icon: Icons.add_circle_outline,
          title: "Donate Food",
          color: appPrimaryGreen,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadFoodPage()),
            );
          },
        ),
        _buildActionCard(
          icon: Icons.inventory_2_outlined,
          title: "My Donations",
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyListingsPage()),
            );
          },
        ),
        _buildActionCard(
          icon: Icons.search,
          title: "Browse Food",
          color: Colors.orange,
          onTap: () {
            // TODO: Navigate to browse page
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Coming soon!")));
          },
        ),
        _buildActionCard(
          icon: ngoStatus == "none"
              ? Icons.volunteer_activism
              : Icons.verified_user,
          title: ngoStatus == "none" ? "Apply as NGO" : "NGO Status",
          color: appPrimaryGreen,
          onTap: ngoStatus == "none" ? applyAsNGO : null,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 15,
              offset: const Offset(0, 8),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- RECENT ACTIVITY ----------------
  Widget _buildRecentActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection("food_listings")
          .where("donorId", isEqualTo: auth.currentUser?.uid)
          .orderBy("createdAt", descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA67C52)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyActivity();
        }

        final activities = snapshot.data!.docs;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.05)),
            ],
          ),
          child: Column(
            children: activities.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              return _buildActivityItem(data, index < activities.length - 1);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> data, bool showDivider) {
    final foodName = data["foodName"] ?? "Unknown";
    final status = data["status"] ?? "pending";
    final createdAt = (data["createdAt"] as Timestamp?)?.toDate();
    final timeAgo = createdAt != null ? _getTimeAgo(createdAt) : "Recently";

    IconData icon;
    Color color;
    String action;

    switch (status) {
      case "completed":
        icon = Icons.check_circle;
        color = appPrimaryGreen;
        action = "Completed";
        break;
      case "assigned":
        icon = Icons.assignment;
        color = Colors.blue;
        action = "Matched";
        break;
      default:
        icon = Icons.pending;
        color = Colors.orange;
        action = "Posted";
    }

    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            foodName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            "$action • $timeAgo",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 60, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            "No activity yet",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Start donating to see your activity here",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ---------------- ANALYTICS ----------------
  Widget _buildAnalytics() {
    if (isLoadingStats) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(blurRadius: 12, color: Colors.black.withOpacity(0.05)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "This Week",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "${impactStats['thisWeekDonations'] ?? 0} donations",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAnalyticItem(
                "Pending",
                "${impactStats['pendingDonations'] ?? 0}",
                Colors.orange,
              ),
              _buildAnalyticItem(
                "Assigned",
                "${impactStats['assignedDonations'] ?? 0}",
                Colors.blue,
              ),
              _buildAnalyticItem(
                "Completed",
                "${impactStats['completedDonations'] ?? 0}",
                appPrimaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  // ---------------- ACHIEVEMENTS ----------------
  Widget _buildAchievements() {
    if (isLoadingStats) {
      return const SizedBox.shrink();
    }

    final totalDonations = impactStats['totalDonations'] ?? 0;
    final completedDonations = impactStats['completedDonations'] ?? 0;

    List<Map<String, dynamic>> achievements = [];

    if (totalDonations >= 1) {
      achievements.add({
        'icon': Icons.star,
        'title': 'First Donation',
        'color': Colors.amber,
      });
    }
    if (totalDonations >= 5) {
      achievements.add({
        'icon': Icons.emoji_events,
        'title': '5 Donations',
        'color': Colors.orange,
      });
    }
    if (completedDonations >= 10) {
      achievements.add({
        'icon': Icons.workspace_premium,
        'title': '10 Completed',
        'color': Colors.purple,
      });
    }
    if (impactStats['totalMeals'] >= 50) {
      achievements.add({
        'icon': Icons.favorite,
        'title': '50 Meals Saved',
        'color': Colors.red,
      });
    }

    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Achievements", Icons.workspace_premium),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return Container(
                width: 100,
                margin: EdgeInsets.only(
                  right: index < achievements.length - 1 ? 12 : 0,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.05),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      achievement['icon'] as IconData,
                      color: achievement['color'] as Color,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      achievement['title'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}


