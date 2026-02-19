import 'package:flutter/material.dart';
import 'upload_food_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantDashboard extends StatelessWidget {
  const RestaurantDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SpareBite"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),

      // Floating Add Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadFoodPage()),
              );
            },
        icon: const Icon(Icons.add),
        label: const Text("Add Listing"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Dashboard Title
            const Text(
              "Dashboard",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 5),

            const Text(
              "Manage your surplus food donations",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 20),

            /// Summary Cards
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              children: const [
                SummaryCard(
                  title: "Active",
                  value: "3",
                  color: Colors.green,
                  icon: Icons.inventory,
                ),
                SummaryCard(
                  title: "Pending",
                  value: "2",
                  color: Colors.orange,
                  icon: Icons.access_time,
                ),
                SummaryCard(
                  title: "Delivered",
                  value: "28",
                  color: Colors.blue,
                  icon: Icons.check_circle,
                ),
              ],
            ),

            const SizedBox(height: 25),

            /// Listings Title
            const Text(
              "Your Listings",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("food_listings")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text("No listings yet");
                }

                final listings = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: listings.length,
                  itemBuilder: (context, index) {
                    final data = listings[index];

                    return FoodCard(
                      title: data["foodName"] ?? "",
                      quantity: data["quantity"] ?? "",
                      status: data["status"] ?? "pending",
                      image:
                          "https://images.unsplash.com/photo-1546069901-ba9599a7e63c",
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

//// Summary Card Widget
class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title),
        ],
      ),
    );
  }
}

//// Food Listing Card
class FoodCard extends StatelessWidget {
  final String title;
  final String quantity;
  final String status;
  final String image;

  const FoodCard({
    super.key,
    required this.title,
    required this.quantity,
    required this.status,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              image,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(quantity),

                const SizedBox(height: 8),

                Chip(
                  label: Text(status),
                  backgroundColor: status == "Delivered"
                      ? Colors.green.shade100
                      : status == "AI Matched"
                      ? Colors.blue.shade100
                      : Colors.orange.shade100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
