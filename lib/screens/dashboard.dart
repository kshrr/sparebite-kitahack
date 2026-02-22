import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_listings_page.dart';
import 'upload_food_page.dart';
import 'login.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  String ngoStatus = "loading";

  @override
  void initState() {
    super.initState();
    loadUserStatus();
  }

  // ---------------- GET USER NGO STATUS ----------------
  Future<void> loadUserStatus() async {
    final uid = auth.currentUser!.uid;
    final doc = await firestore.collection("users").doc(uid).get();

    setState(() {
      ngoStatus = doc.data()?["ngoStatus"] ?? "none";
    });
  }

  // ---------------- APPLY AS NGO ----------------
  Future<void> applyAsNGO() async {
    final uid = auth.currentUser!.uid;

    await firestore.collection("users").doc(uid).update({
      "ngoStatus": "pending",
    });

    setState(() => ngoStatus = "pending");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("NGO application submitted")),
    );
  }

  // ---------------- LOGOUT ----------------
  Future<void> logout() async {
    await auth.signOut();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Sparebite",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // HERO SECTION
            buildHeroCard(),

            const SizedBox(height: 30),

            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            buildActionGrid(),

            const SizedBox(height: 30),

            const Text(
              "Your Impact",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            buildImpactSection(),
          ],
        ),
      ),
    );
  }

  // ---------------- HERO CARD ----------------
  Widget buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Welcome back 👋",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Help reduce food waste and feed communities.",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 20),

          buildNGOStatusBadge(),
        ],
      ),
    );
  }

  // ---------------- NGO STATUS BADGE ----------------
  Widget buildNGOStatusBadge() {
    Color color;
    String text;

    switch (ngoStatus) {
      case "approved":
        color = Colors.green;
        text = "Verified NGO";
        break;
      case "pending":
        color = Colors.orange;
        text = "NGO Application Pending";
        break;
      default:
        color = Colors.white;
        text = "Community Member";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ---------------- ACTION GRID ----------------
  Widget buildActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.1,
      children: [

        actionCard(
          icon: Icons.add_circle_outline,
          title: "Donate Food",
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadFoodPage()),
            );
          },
        ),

        actionCard(
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

        actionCard(
          icon: Icons.track_changes,
          title: "Matching Status",
          color: Colors.orange,
          onTap: () {},
        ),

        actionCard(
          icon: Icons.volunteer_activism,
          title: "Apply as NGO",
          color: Colors.purple,
          onTap: ngoStatus == "none" ? applyAsNGO : null,
        ),
      ],
    );
  }

  // ---------------- ACTION CARD ----------------
  Widget actionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
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
              child: Icon(icon, color: color, size: 28),
            ),

            const SizedBox(height: 12),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- IMPACT SECTION ----------------
  Widget buildImpactSection() {
    return Row(
      children: [
        Expanded(child: impactCard("Meals Saved", "24", Icons.restaurant)),
        const SizedBox(width: 15),
        Expanded(child: impactCard("Donations", "5", Icons.favorite)),
      ],
    );
  }

  // ---------------- IMPACT CARD ----------------
  Widget impactCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 6),
          Text(title),
        ],
      ),
    );
  }
}
